/// How often Android delivers sensor samples.
///
/// The four named rates are Android's `SENSOR_DELAY_*` constants. They are
/// hints: the device may deliver faster or slower.
class SensorRate {
  const SensorRate._(this.samplingPeriodUs);

  /// A custom sampling period. Must be longer than 3 microseconds, because
  /// Android reads 0 to 3 as the named delay constants.
  factory SensorRate.custom(Duration period) {
    final us = period.inMicroseconds;
    if (us <= 3) {
      throw ArgumentError.value(period, 'period', 'must be longer than 3 µs');
    }
    return SensorRate._(us);
  }

  /// `SENSOR_DELAY_FASTEST`: as fast as possible. Uses the most battery.
  static const fastest = SensorRate._(0);

  /// `SENSOR_DELAY_GAME`: about 50 Hz.
  static const game = SensorRate._(1);

  /// `SENSOR_DELAY_UI`: about 15 Hz. The default; smooth enough for a needle.
  static const ui = SensorRate._(2);

  /// `SENSOR_DELAY_NORMAL`: about 5 Hz.
  static const normal = SensorRate._(3);

  /// The value passed to `SensorManager.registerListener`: 0 to 3 for the
  /// named constants, otherwise a period in microseconds.
  final int samplingPeriodUs;

  @override
  bool operator ==(Object other) =>
      other is SensorRate && other.samplingPeriodUs == samplingPeriodUs;

  @override
  int get hashCode => samplingPeriodUs.hashCode;
}

/// Where heading smoothing runs.
enum SmoothingLocation {
  /// No smoothing.
  none,

  /// In Kotlin, before the event crosses the platform channel.
  native,

  /// In Dart, on each stream listener separately.
  dart,
}

/// Low-pass smoothing of the heading that handles the 0°/360° wrap.
///
/// Only the heading is smoothed; pitch and roll are passed through.
class HeadingSmoothing {
  const HeadingSmoothing._(this.location, this.alpha);

  /// Smooth in Kotlin. [alpha] is the weight of each new sample, in `(0, 1]`;
  /// smaller values smooth more.
  const HeadingSmoothing.native(double alpha)
      : this._(SmoothingLocation.native, alpha);

  /// Smooth in Dart. [alpha] is the weight of each new sample, in `(0, 1]`;
  /// smaller values smooth more.
  const HeadingSmoothing.dart(double alpha)
      : this._(SmoothingLocation.dart, alpha);

  /// No smoothing.
  static const none = HeadingSmoothing._(SmoothingLocation.none, 1);

  /// Where the smoothing runs.
  final SmoothingLocation location;

  /// Weight of each new sample, in `(0, 1]`.
  final double alpha;

  /// Throws [ArgumentError] if [alpha] is outside `(0, 1]`.
  void validate() {
    if (location != SmoothingLocation.none &&
        (alpha.isNaN || alpha <= 0 || alpha > 1)) {
      throw ArgumentError.value(alpha, 'alpha', 'must be in (0, 1]');
    }
  }
}
