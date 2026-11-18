package dev.abdeldjalilchougui.heading_sensor

import kotlin.math.asin
import kotlin.math.atan2

/** Azimuth, pitch and roll in degrees. Azimuth is in [0, 360). */
data class Orientation(val azimuth: Double, val pitch: Double, val roll: Double)

/**
 * The same maths as `SensorManager.getOrientation`, in degrees, as a pure
 * function so it can be unit tested on the JVM.
 */
object OrientationMath {
    private const val RAD_TO_DEG = 180.0 / Math.PI

    /** [r] is a row-major 3x3 (9 values) or 4x4 (16 values) rotation matrix. */
    fun orientation(r: FloatArray): Orientation {
        val (r1, r4, r6, r7, r8) = when (r.size) {
            9 -> listOf(r[1], r[4], r[6], r[7], r[8])
            16 -> listOf(r[1], r[5], r[8], r[9], r[10])
            else -> throw IllegalArgumentException("rotation matrix must have 9 or 16 values, got ${r.size}")
        }
        val azimuth = atan2(r1.toDouble(), r4.toDouble()) * RAD_TO_DEG
        val pitch = asin((-r7).toDouble().coerceIn(-1.0, 1.0)) * RAD_TO_DEG
        val roll = atan2((-r6).toDouble(), r8.toDouble()) * RAD_TO_DEG
        return Orientation(AngleLowPass.normalize(azimuth), pitch, roll)
    }
}
