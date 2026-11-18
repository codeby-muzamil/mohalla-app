package dev.abdeldjalilchougui.heading_sensor

/** The `SensorManager.AXIS_*` constants, duplicated so the table is testable on the JVM. */
object Axis {
    const val X = 1
    const val Y = 2
    const val Z = 3
    const val MINUS_X = 0x81
    const val MINUS_Y = 0x82
    const val MINUS_Z = 0x83
}

/** Arguments for `SensorManager.remapCoordinateSystem(inR, x, y, outR)`. */
data class RemapAxes(val x: Int, val y: Int)

/**
 * Maps `Display.getRotation()` (`Surface.ROTATION_0` .. `ROTATION_270`, i.e. 0..3) to the
 * axes that make the heading follow the top of the *screen* rather than the top of the
 * device's natural orientation.
 */
object DisplayRemap {
    fun axesFor(displayRotation: Int): RemapAxes = when (displayRotation) {
        1 -> RemapAxes(Axis.Y, Axis.MINUS_X) // ROTATION_90
        2 -> RemapAxes(Axis.MINUS_X, Axis.MINUS_Y) // ROTATION_180
        3 -> RemapAxes(Axis.MINUS_Y, Axis.X) // ROTATION_270
        else -> RemapAxes(Axis.X, Axis.Y) // ROTATION_0 or unknown
    }

    fun needsRemap(displayRotation: Int): Boolean = displayRotation in 1..3
}
