import 'heading_event.dart';

/// Which heading-related sensors the device has.
class HeadingCapabilities {
  /// Creates a capability report.
  const HeadingCapabilities({
    required this.hasRotationVector,
    required this.hasGeomagneticRotationVector,
    required this.hasAccelerometer,
    required this.hasMagnetometer,
    required this.bestSource,
  });

  /// A report with nothing available.
  static const none = HeadingCapabilities(
    hasRotationVector: false,
    hasGeomagneticRotationVector: false,
    hasAccelerometer: false,
    hasMagnetometer: false,
    bestSource: null,
  );

  /// The device has `TYPE_ROTATION_VECTOR`.
  final bool hasRotationVector;

  /// The device has `TYPE_GEOMAGNETIC_ROTATION_VECTOR`.
  final bool hasGeomagneticRotationVector;

  /// The device has `TYPE_ACCELEROMETER`.
  final bool hasAccelerometer;

  /// The device has `TYPE_MAGNETIC_FIELD`. Without it there is no compass.
  final bool hasMagnetometer;

  /// The source `HeadingSensor.events` uses by default, or `null` when no
  /// heading can be computed.
  final HeadingSource? bestSource;

  /// Whether a heading can be computed on this device.
  bool get isAvailable => bestSource != null;

  @override
  String toString() =>
      'HeadingCapabilities(rotationVector: $hasRotationVector, '
      'geomagneticRotationVector: $hasGeomagneticRotationVector, '
      'accelerometer: $hasAccelerometer, magnetometer: $hasMagnetometer, '
      'bestSource: ${bestSource?.name})';
}
