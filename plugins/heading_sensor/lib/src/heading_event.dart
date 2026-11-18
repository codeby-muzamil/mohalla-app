import 'angles.dart';

/// The Android sensor a heading was computed from.
enum HeadingSource {
  /// `TYPE_ROTATION_VECTOR`: accelerometer, magnetometer and gyroscope fused
  /// by the device. The best choice when present.
  rotationVector,

  /// `TYPE_GEOMAGNETIC_ROTATION_VECTOR`: accelerometer and magnetometer only,
  /// no gyroscope. Uses less power but is noisier.
  geomagneticRotationVector,

  /// Raw accelerometer and magnetic field sensors combined by
  /// `SensorManager.getRotationMatrix`. Used when neither rotation vector
  /// exists.
  accelerometerMagnetometer,
}

/// Sensor accuracy as reported by Android's `onAccuracyChanged`.
enum HeadingAccuracy {
  /// `SENSOR_STATUS_UNRELIABLE` (or no contact). Calibrate before trusting
  /// the heading.
  unreliable,

  /// `SENSOR_STATUS_ACCURACY_LOW`. Calibration is recommended.
  low,

  /// `SENSOR_STATUS_ACCURACY_MEDIUM`.
  medium,

  /// `SENSOR_STATUS_ACCURACY_HIGH`.
  high;

  /// Whether the user should be asked to calibrate (the figure-8 motion).
  /// True for [unreliable] and [low].
  bool get needsCalibration => index <= low.index;
}

/// One compass reading.
///
/// All angles are in degrees. The heading is clockwise from north in
/// `[0, 360)`. Pitch and roll follow Android's `SensorManager.getOrientation`
/// after the display-rotation remap.
class HeadingEvent {
  /// Creates an event. Normally you receive these from
  /// `HeadingSensor.events` rather than creating them.
  const HeadingEvent({
    required this.magneticHeading,
    required this.pitch,
    required this.roll,
    required this.accuracy,
    required this.source,
    required this.timestamp,
    this.headingAccuracyDegrees,
    this.declination,
    this.trueHeading,
    this.isTrueNorth = false,
  });

  /// Heading relative to magnetic north, in `[0, 360)`.
  final double magneticHeading;

  /// Heading relative to true (geographic) north, in `[0, 360)`, or `null`
  /// when no declination was available.
  final double? trueHeading;

  /// The magnetic declination used for [trueHeading], positive east, or
  /// `null`.
  final double? declination;

  /// Whether [heading] is [trueHeading]. False when true north was not asked
  /// for, or when the declination provider returned `null`.
  final bool isTrueNorth;

  /// Rotation around the device's x axis, in `[-90, 90]`.
  final double pitch;

  /// Rotation around the device's y axis, in `[-180, 180]`.
  final double roll;

  /// Latest accuracy reported by the sensor.
  final HeadingAccuracy accuracy;

  /// The sensor this reading came from.
  final HeadingSource source;

  /// When the sensor sampled this reading (UTC).
  final DateTime timestamp;

  /// The device's own estimate of the heading error in degrees, when the
  /// rotation vector sensor provides one (Android 4.3+ with some hardware);
  /// otherwise `null`.
  final double? headingAccuracyDegrees;

  /// The heading to display: [trueHeading] when [isTrueNorth], otherwise
  /// [magneticHeading].
  double get heading => isTrueNorth ? trueHeading! : magneticHeading;

  /// Shortcut for [HeadingAccuracy.needsCalibration] on [accuracy].
  bool get needsCalibration => accuracy.needsCalibration;

  /// A copy with [magneticHeading] replaced (used for smoothing).
  HeadingEvent withMagneticHeading(double value) => HeadingEvent(
        magneticHeading: normalizeDegrees(value),
        pitch: pitch,
        roll: roll,
        accuracy: accuracy,
        source: source,
        timestamp: timestamp,
        headingAccuracyDegrees: headingAccuracyDegrees,
        declination: declination,
        trueHeading:
            declination == null ? null : normalizeDegrees(value + declination!),
        isTrueNorth: isTrueNorth,
      );

  /// A copy with [declination] (degrees, positive east) applied. When
  /// [useTrueNorth] is true, [heading] becomes the true heading.
  HeadingEvent withDeclination(double declination,
          {bool useTrueNorth = false}) =>
      HeadingEvent(
        magneticHeading: magneticHeading,
        pitch: pitch,
        roll: roll,
        accuracy: accuracy,
        source: source,
        timestamp: timestamp,
        headingAccuracyDegrees: headingAccuracyDegrees,
        declination: declination,
        trueHeading: normalizeDegrees(magneticHeading + declination),
        isTrueNorth: useTrueNorth,
      );

  @override
  String toString() => 'HeadingEvent(heading: ${heading.toStringAsFixed(1)}, '
      'magnetic: ${magneticHeading.toStringAsFixed(1)}, '
      'pitch: ${pitch.toStringAsFixed(1)}, roll: ${roll.toStringAsFixed(1)}, '
      'accuracy: ${accuracy.name}, source: ${source.name})';
}
