package dev.abdeldjalilchougui.heading_sensor

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.SystemClock
import android.view.Display
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Streams compass heading from the rotation-vector sensors.
 *
 * Sensors are registered only while Dart listens and the Activity is started;
 * they are unregistered when the app goes to the background.
 */
class HeadingSensorPlugin :
    FlutterPlugin,
    ActivityAware,
    EventChannel.StreamHandler,
    MethodChannel.MethodCallHandler,
    SensorEventListener,
    DefaultLifecycleObserver {

    private lateinit var context: Context
    private var sensorManager: SensorManager? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    private var activity: Activity? = null
    private var lifecycle: Lifecycle? = null

    private val gate = SensorGate()
    private var registered = false

    // Current stream configuration.
    private var source: HeadingSource? = null
    private var samplingPeriodUs = SensorManager.SENSOR_DELAY_UI
    private var filter: AngleLowPass? = null

    // Working buffers.
    private val rotation = FloatArray(9)
    private val remapped = FloatArray(9)
    private val rotationVector = FloatArray(4)
    private var gravity: FloatArray? = null
    private var geomagnetic: FloatArray? = null
    private var accuracyStatus = SensorManager.SENSOR_STATUS_UNRELIABLE

    // ---- FlutterPlugin -------------------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
        methodChannel = MethodChannel(binding.binaryMessenger, "$CHANNEL/methods").also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, "$CHANNEL/events").also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        gate.hasListener = false
        applyGate()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        sink = null
    }

    // ---- ActivityAware + lifecycle -------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        // Same unwrapping as flutter_plugin_android_lifecycle's FlutterLifecycleAdapter,
        // without the extra dependency.
        lifecycle = (binding.lifecycle as? HiddenLifecycleReference)?.lifecycle
        lifecycle?.addObserver(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachLifecycle()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachLifecycle()
        // The Activity is gone for good: nothing is on screen, so stop sensing.
        gate.inForeground = false
        applyGate()
    }

    private fun detachLifecycle() {
        lifecycle?.removeObserver(this)
        lifecycle = null
        activity = null
    }

    override fun onStart(owner: LifecycleOwner) {
        gate.inForeground = true
        applyGate()
    }

    override fun onStop(owner: LifecycleOwner) {
        gate.inForeground = false
        applyGate()
    }

    // ---- MethodChannel -------------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> {
                val a = availability()
                result.success(
                    mapOf(
                        "rotationVector" to a.rotationVector,
                        "geomagneticRotationVector" to a.geomagneticRotationVector,
                        "accelerometer" to a.accelerometer,
                        "magnetometer" to a.magnetometer,
                        "bestSource" to SourceSelector.select(a)?.wireName,
                    ),
                )
            }
            else -> result.notImplemented()
        }
    }

    // ---- EventChannel --------------------------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val args = arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        val selected = SourceSelector.select(
            availability(),
            HeadingSource.fromWireName(args["preferredSource"] as? String),
        )
        if (selected == null) {
            events.error("NO_SENSOR", "This device has no magnetometer-based heading sensor.", null)
            return
        }

        // A new listener replaces any previous configuration.
        unregister()
        source = selected
        samplingPeriodUs = (args["samplingPeriodUs"] as? Number)?.toInt() ?: SensorManager.SENSOR_DELAY_UI
        filter = (args["smoothingAlpha"] as? Number)?.toDouble()?.let { AngleLowPass(it) }
        sink = events
        gate.hasListener = true
        applyGate()
    }

    override fun onCancel(arguments: Any?) {
        gate.hasListener = false
        applyGate()
        sink = null
    }

    // ---- Sensor registration -------------------------------------------------------------------

    private fun availability(): SensorAvailability {
        val sm = sensorManager
        fun has(type: Int) = sm?.getDefaultSensor(type) != null
        return SensorAvailability(
            rotationVector = has(Sensor.TYPE_ROTATION_VECTOR),
            geomagneticRotationVector = has(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR),
            accelerometer = has(Sensor.TYPE_ACCELEROMETER),
            magnetometer = has(Sensor.TYPE_MAGNETIC_FIELD),
        )
    }

    private fun applyGate() {
        if (gate.shouldBeRegistered) register() else unregister()
    }

    private fun register() {
        if (registered) return
        val sm = sensorManager ?: return
        val types = when (source) {
            HeadingSource.ROTATION_VECTOR -> listOf(Sensor.TYPE_ROTATION_VECTOR)
            HeadingSource.GEOMAGNETIC_ROTATION_VECTOR -> listOf(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            HeadingSource.ACCELEROMETER_MAGNETOMETER ->
                listOf(Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_MAGNETIC_FIELD)
            null -> return
        }
        gravity = null
        geomagnetic = null
        filter?.reset()
        accuracyStatus = SensorManager.SENSOR_STATUS_UNRELIABLE
        for (type in types) {
            sm.getDefaultSensor(type)?.let { sm.registerListener(this, it, samplingPeriodUs) }
        }
        registered = true
    }

    private fun unregister() {
        if (!registered) return
        sensorManager?.unregisterListener(this)
        registered = false
    }

    // ---- SensorEventListener -------------------------------------------------------------------

    private fun primaryType(): Int = when (source) {
        HeadingSource.GEOMAGNETIC_ROTATION_VECTOR -> Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR
        HeadingSource.ACCELEROMETER_MAGNETOMETER -> Sensor.TYPE_MAGNETIC_FIELD
        else -> Sensor.TYPE_ROTATION_VECTOR
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        if (sensor.type == primaryType()) accuracyStatus = accuracy
    }

    override fun onSensorChanged(event: SensorEvent) {
        val out = sink ?: return
        var headingAccuracy: Double? = null
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR, Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR -> {
                // Some devices send 5 values, which getRotationMatrixFromVector rejects on
                // older Android versions; the 5th is the heading accuracy in radians.
                val n = minOf(event.values.size, 4)
                rotationVector.fill(0f)
                System.arraycopy(event.values, 0, rotationVector, 0, n)
                SensorManager.getRotationMatrixFromVector(rotation, if (n == 4) rotationVector else rotationVector.copyOf(n))
                if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR && event.values.size >= 5) {
                    val rad = event.values[4]
                    if (rad >= 0f) headingAccuracy = Math.toDegrees(rad.toDouble())
                }
                accuracyStatus = event.accuracy
            }
            Sensor.TYPE_ACCELEROMETER -> {
                gravity = event.values.copyOf(3)
                return // Emit on magnetometer samples only, to avoid doubling the rate.
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                geomagnetic = event.values.copyOf(3)
                accuracyStatus = event.accuracy
                val g = gravity ?: return
                // False in free fall or when the field is parallel to gravity.
                if (!SensorManager.getRotationMatrix(rotation, null, g, geomagnetic)) return
            }
            else -> return
        }

        val displayRotation = currentDisplayRotation()
        val matrix = if (DisplayRemap.needsRemap(displayRotation)) {
            val axes = DisplayRemap.axesFor(displayRotation)
            SensorManager.remapCoordinateSystem(rotation, axes.x, axes.y, remapped)
            remapped
        } else {
            rotation
        }

        val o = OrientationMath.orientation(matrix)
        val heading = filter?.add(o.azimuth) ?: o.azimuth
        out.success(
            mapOf(
                "heading" to heading,
                "pitch" to o.pitch,
                "roll" to o.roll,
                "accuracy" to Accuracy.fromStatus(accuracyStatus),
                "source" to source?.wireName,
                "timestampMs" to Timestamps.toEpochMillis(
                    event.timestamp,
                    SystemClock.elapsedRealtimeNanos(),
                    System.currentTimeMillis(),
                ),
                "headingAccuracy" to headingAccuracy,
            ),
        )
    }

    private fun currentDisplayRotation(): Int {
        val display: Display? = activity?.let { a ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                a.display
            } else {
                @Suppress("DEPRECATION")
                a.windowManager.defaultDisplay
            }
        } ?: (context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager?)
            ?.getDisplay(Display.DEFAULT_DISPLAY)
        return display?.rotation ?: 0
    }

    private companion object {
        const val CHANNEL = "dev.abdeldjalilchougui.heading_sensor"
    }
}
