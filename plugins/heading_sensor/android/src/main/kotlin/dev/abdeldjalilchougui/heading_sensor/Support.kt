package dev.abdeldjalilchougui.heading_sensor

/** Maps `SensorManager.SENSOR_STATUS_*` to the Dart `HeadingAccuracy` names. */
object Accuracy {
    fun fromStatus(status: Int): String = when (status) {
        1 -> "low" // SENSOR_STATUS_ACCURACY_LOW
        2 -> "medium" // SENSOR_STATUS_ACCURACY_MEDIUM
        3 -> "high" // SENSOR_STATUS_ACCURACY_HIGH
        else -> "unreliable" // UNRELIABLE (0), NO_CONTACT (-1) or unknown
    }
}

/** `SensorEvent.timestamp` is in the elapsed-realtime clock; Dart wants wall-clock time. */
object Timestamps {
    fun toEpochMillis(eventNanos: Long, nowElapsedNanos: Long, nowEpochMillis: Long): Long =
        nowEpochMillis - (nowElapsedNanos - eventNanos) / 1_000_000L
}

/**
 * Sensors must be registered only while Dart listens and the app is visible.
 * Starts in the foreground so engines without an Activity still work.
 */
class SensorGate {
    var hasListener = false
    var inForeground = true
    val shouldBeRegistered: Boolean get() = hasListener && inForeground
}
