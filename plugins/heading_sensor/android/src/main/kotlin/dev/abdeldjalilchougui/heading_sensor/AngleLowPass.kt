package dev.abdeldjalilchougui.heading_sensor

/**
 * Exponential low-pass filter for angles in degrees that crosses 359 -> 0 the short way.
 * [alpha] is the weight of each new sample, in (0, 1]; 1 disables smoothing.
 */
class AngleLowPass(val alpha: Double) {
    init {
        require(!alpha.isNaN() && alpha > 0.0 && alpha <= 1.0) { "alpha must be in (0, 1], got $alpha" }
    }

    var value: Double? = null
        private set

    fun add(degrees: Double): Double {
        val current = value
        val next = if (current == null) {
            normalize(degrees)
        } else {
            normalize(current + alpha * signedDifference(degrees, current))
        }
        value = next
        return next
    }

    fun reset() {
        value = null
    }

    companion object {
        /** Wraps into [0, 360). */
        fun normalize(degrees: Double): Double {
            val r = ((degrees % 360.0) + 360.0) % 360.0
            return if (r >= 360.0) 0.0 else r
        }

        /** Signed angle from [from] to [to] in (-180, 180]. */
        fun signedDifference(to: Double, from: Double): Double {
            val d = normalize(to - from)
            return if (d > 180.0) d - 360.0 else d
        }
    }
}
