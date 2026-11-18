package dev.abdeldjalilchougui.heading_sensor

/** Where a heading comes from. [wireName] matches the Dart `HeadingSource` enum. */
enum class HeadingSource(val wireName: String) {
    ROTATION_VECTOR("rotationVector"),
    GEOMAGNETIC_ROTATION_VECTOR("geomagneticRotationVector"),
    ACCELEROMETER_MAGNETOMETER("accelerometerMagnetometer");

    companion object {
        fun fromWireName(name: String?): HeadingSource? = entries.firstOrNull { it.wireName == name }
    }
}

/** Which relevant sensors the device reports via `getDefaultSensor`. */
data class SensorAvailability(
    val rotationVector: Boolean,
    val geomagneticRotationVector: Boolean,
    val accelerometer: Boolean,
    val magnetometer: Boolean,
) {
    fun has(source: HeadingSource): Boolean = when (source) {
        HeadingSource.ROTATION_VECTOR -> rotationVector
        HeadingSource.GEOMAGNETIC_ROTATION_VECTOR -> geomagneticRotationVector
        HeadingSource.ACCELEROMETER_MAGNETOMETER -> accelerometer
    } && magnetometer
}

/**
 * Picks the sensor to use: rotation vector, then geomagnetic rotation vector, then
 * accelerometer + magnetometer. Every source needs a magnetometer, since without one
 * there is no magnetic reference. An available [preferred] source wins.
 */
object SourceSelector {
    private val order = listOf(
        HeadingSource.ROTATION_VECTOR,
        HeadingSource.GEOMAGNETIC_ROTATION_VECTOR,
        HeadingSource.ACCELEROMETER_MAGNETOMETER,
    )

    fun select(available: SensorAvailability, preferred: HeadingSource? = null): HeadingSource? {
        if (preferred != null && available.has(preferred)) return preferred
        return order.firstOrNull { available.has(it) }
    }
}
