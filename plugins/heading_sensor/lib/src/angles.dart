/// Wraps [degrees] into the range `[0, 360)`.
double normalizeDegrees(double degrees) {
  final r = degrees % 360.0;
  // `%` on doubles is already non-negative for a positive divisor; this guards
  // against `-0.0` and against rounding up to exactly 360.
  return (r >= 360.0 || r == 0) ? 0.0 : r;
}

/// The signed angle from [from] to [to], in degrees, in the range
/// `(-180, 180]`. Positive means clockwise.
double signedAngleDifference(double to, double from) {
  final d = normalizeDegrees(to - from);
  return d > 180.0 ? d - 360.0 : d;
}

/// An exponential low-pass filter for compass angles that crosses 359° to 0°
/// the short way.
///
/// Averaging 359° and 1° gives 0°, not 180°.
class AngleLowPassFilter {
  /// Creates a filter. [alpha] is the weight of each new sample, in `(0, 1]`.
  /// Smaller values smooth more; `1` disables smoothing.
  AngleLowPassFilter({required this.alpha}) {
    if (alpha.isNaN || alpha <= 0 || alpha > 1) {
      throw ArgumentError.value(alpha, 'alpha', 'must be in (0, 1]');
    }
  }

  /// The weight of each new sample, in `(0, 1]`.
  final double alpha;

  double? _value;

  /// The current filtered angle in `[0, 360)`, or `null` before the first
  /// sample.
  double? get value => _value;

  /// Adds a sample in degrees and returns the new filtered angle in
  /// `[0, 360)`. The first sample is returned unchanged (normalized).
  double add(double degrees) {
    final current = _value;
    final next = current == null
        ? normalizeDegrees(degrees)
        : normalizeDegrees(
            current + alpha * signedAngleDifference(degrees, current));
    _value = next;
    return next;
  }

  /// Forgets the filter state; the next sample passes through unchanged.
  void reset() => _value = null;
}
