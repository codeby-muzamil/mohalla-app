import 'angles.dart';
import 'capabilities.dart';
import 'heading_event.dart';

T _byName<T extends Enum?>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v?.name == name) return v;
  }
  return fallback;
}

double _toDouble(Object? v) => (v as num?)?.toDouble() ?? 0.0;

/// Decodes one event map sent by the Kotlin side.
HeadingEvent decodeHeadingEvent(Map<Object?, Object?> map) {
  final headingAccuracy = (map['headingAccuracy'] as num?)?.toDouble();
  return HeadingEvent(
    magneticHeading: normalizeDegrees(_toDouble(map['heading'])),
    pitch: _toDouble(map['pitch']),
    roll: _toDouble(map['roll']),
    accuracy: _byName(
        HeadingAccuracy.values, map['accuracy'], HeadingAccuracy.unreliable),
    source: _byName(
        HeadingSource.values, map['source'], HeadingSource.rotationVector),
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (map['timestampMs'] as num?)?.toInt() ?? 0,
      isUtc: true,
    ),
    headingAccuracyDegrees: (headingAccuracy == null || headingAccuracy < 0)
        ? null
        : headingAccuracy,
  );
}

/// Decodes the capability map sent by the Kotlin side.
HeadingCapabilities decodeCapabilities(Map<Object?, Object?>? map) {
  if (map == null) return HeadingCapabilities.none;
  final best = map['bestSource'];
  return HeadingCapabilities(
    hasRotationVector: map['rotationVector'] == true,
    hasGeomagneticRotationVector: map['geomagneticRotationVector'] == true,
    hasAccelerometer: map['accelerometer'] == true,
    hasMagnetometer: map['magnetometer'] == true,
    bestSource: best == null
        ? null
        : _byName<HeadingSource?>(HeadingSource.values, best, null),
  );
}
