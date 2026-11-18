# heading_sensor

Compass heading for Android from the rotation-vector sensors, with pitch,
roll, display-rotation handling, calibration accuracy, 0°/360°-safe smoothing
and optional true north. It is a maintained replacement for `flutter_compass`
and `flutter_compass_v2`.

[![pub package](https://img.shields.io/pub/v/heading_sensor.svg)](https://pub.dev/packages/heading_sensor)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Android only; iOS not supported (use CLLocationManager heading).**

## Features

- **Best sensor first.** Uses `TYPE_ROTATION_VECTOR`. If that is missing it
  uses `TYPE_GEOMAGNETIC_ROTATION_VECTOR`, which draws less power. If neither
  exists it combines the accelerometer and magnetic field with
  `SensorManager.getRotationMatrix`. You can ask for the lower-power sensor
  with `preferredSource`.
- **Heading, pitch and roll.** They follow the top of the screen: the
  rotation matrix is remapped with `remapCoordinateSystem` for the current
  `Display.getRotation()` (0°, 90°, 180°, 270°).
- **Accuracy.** Reports `unreliable`, `low`, `medium` or `high` from
  `onAccuracyChanged`, and gives a `needsCalibration` flag. Where the device
  reports its own heading error estimate, you get that too, in degrees.
- **Rate and smoothing.** Choose the sensor rate (`fastest`, `game`, `ui`,
  `normal` or a custom period). Add a low-pass filter that goes from 359° to
  1° through 0°, not through 180°. It runs in Kotlin or in Dart.
- **True north.** Pass a `declinationProvider`, for example the WMM2025
  model from [`qibla_math`](#true-north-and-qibla-with-qibla_math).
- **Battery friendly.** Sensors are registered only while a stream has a
  listener. They are unregistered when the app goes to the background
  (Activity `onStop`), and registered again when it comes back.
- **Capabilities.** `HeadingSensor.capabilities()` tells you which sensors
  exist, for example that the device has no magnetometer.

## Install

```sh
flutter pub add heading_sensor
```

No permissions are needed. `minSdk` is 21.

## Usage

```dart
import 'package:heading_sensor/heading_sensor.dart';

Future<void> startCompass() async {
  if (!await HeadingSensor.isAvailable()) {
    print('No compass on this device');
    return;
  }

  final subscription = HeadingSensor.events(
    rate: SensorRate.ui,
    smoothing: const HeadingSmoothing.native(0.15),
  ).listen((event) {
    print('${event.heading.toStringAsFixed(0)}° '
        'pitch ${event.pitch.toStringAsFixed(0)}° '
        'roll ${event.roll.toStringAsFixed(0)}° '
        '${event.accuracy.name} via ${event.source.name}');
    if (event.needsCalibration) {
      print('Move the phone in a figure-8 to calibrate');
    }
  }, onError: (Object error) {
    // HeadingSensorException('NO_SENSOR') when there is no usable sensor.
    print(error);
  });

  // Cancel when done: this unregisters the Android sensors.
  await Future<void>.delayed(const Duration(seconds: 10));
  await subscription.cancel();
}
```

### Capabilities

```dart
final caps = await HeadingSensor.capabilities();
if (!caps.hasMagnetometer) {
  // No compass hardware at all.
}
print(caps.bestSource); // HeadingSource.rotationVector, or null
```

### Smoothing in Dart

`HeadingSmoothing.native(alpha)` filters in Kotlin, before events cross the
platform channel. `HeadingSmoothing.dart(alpha)` filters in Dart, and each
listener gets its own filter. `alpha` is the weight of each new sample, from
just above 0 (very smooth, slow) to 1 (no smoothing). You can also use
`AngleLowPassFilter` yourself:

```dart
final filter = AngleLowPassFilter(alpha: 0.5);
filter.add(359);
filter.add(1); // 0.0, not 180
```

### True north and qibla with qibla_math

A magnetometer measures **magnetic** north. For true north, add the magnetic
declination at the user's position. The sibling package `qibla_math` has the
NOAA World Magnetic Model (WMM2025), as well as tilt compensation and the
qibla bearing. This plugin already does tilt compensation natively, so from
`qibla_math` you only need the declination and the qibla maths:

```dart
import 'package:heading_sensor/heading_sensor.dart';
// Both packages export normalizeDegrees and signedAngleDifference.
import 'package:qibla_math/qibla_math.dart'
    hide normalizeDegrees, signedAngleDifference;

Stream<double> qiblaNeedle(double latitude, double longitude) {
  // The provider runs once per event, so compute the declination once.
  final declination = WorldMagneticModel.wmm2025
      .calculate(
        latitude: latitude,
        longitude: longitude,
        decimalYear: decimalYear(DateTime.now()),
      )
      .declination;
  final qibla = qiblaBearing(latitude, longitude);

  return HeadingSensor.events(
    smoothing: const HeadingSmoothing.native(0.15),
    useTrueNorth: true,
    declinationProvider: (_) => declination,
  ).map((e) => qiblaNeedleAngle(trueHeading: e.heading, qiblaBearing: qibla));
}
```

If the provider returns `null`, `isTrueNorth` is false and `heading` is the
magnetic heading. Smoothing is applied to the magnetic heading before the
declination is added.

## Calibration tip

When `needsCalibration` is true, ask the user to hold the phone and draw a
**figure-8** in the air a few times, rotating the phone in all directions.
They should do this away from metal, magnets, laptops and magnetic phone
cases. Android updates the accuracy, and you get a new value on the next
event.

## Migrating from flutter_compass

| flutter_compass | heading_sensor |
| --- | --- |
| `FlutterCompass.events` (nullable) | `HeadingSensor.events()`. Check `HeadingSensor.isAvailable()` first. |
| `CompassEvent.heading` | `HeadingEvent.heading` (magnetic unless `useTrueNorth`) |
| `CompassEvent.accuracy` (degrees, iOS) | `HeadingEvent.accuracy` enum, plus `headingAccuracyDegrees` when the device provides it |
| `CompassEvent.headingForCameraMode` | Use `pitch` and `roll` |
| `null` heading when no sensor | Stream error `HeadingSensorException('NO_SENSOR')` |

`flutter_qiblah` users can call `qibla_math` for the qibla bearing and
declination, as shown above.

## Limitations

- **Android only.** iOS is not supported (use CLLocationManager heading).
- Not yet tested on a physical phone. The pure maths (azimuth, remap table,
  smoothing, sensor selection) has JVM unit tests, and the Dart API has
  tests against a mocked channel. An emulator integration test
  (`example/integration_test/`, run with
  `dart run tool/run_on_device.dart <applicationId>` from `example/`) sets the
  emulator's virtual accelerometer and magnetometer through the adb console
  and checks the heading, pitch, sensor registration and background pausing.
- On the emulator the rotation-vector sources deliver events, but the adb
  console cannot set them directly, so only the accelerometer + magnetometer
  heading was checked against known fields.
- Only one native configuration is active at a time. If you listen to a
  second `HeadingSensor.events(...)` stream with other options, it replaces
  the first; cancelling the replaced subscription later leaves the newer
  one running. To use one reading in several widgets, listen to the same
  stream.
- Only the heading is smoothed. Pitch and roll are passed through.
- In the accelerometer + magnetometer fallback, heading is emitted on
  magnetometer samples and uses the raw accelerometer as gravity. It is
  noisier during motion than the rotation-vector sensors.
- Timestamps are converted from `SensorEvent.timestamp`, assuming it uses
  the elapsed-realtime clock, as Android documents. A few old devices used
  a different clock.
- When the Activity is stopped, sensors are paused. Engines with no Activity
  (background isolates) keep sensing while there is a listener.
- The compass reads the local magnetic field. Steel, magnets and electronics
  nearby will bend it, and no sensor or model can correct that.

**Tested on:** Android Emulator, Pixel 10 system image (`sdk_gphone16k_x86_64`),
API 37.

## License

MIT. See [LICENSE](LICENSE).

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
