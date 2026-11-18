import 'dart:async';

import 'package:flutter/services.dart';

import 'angles.dart';
import 'capabilities.dart';
import 'channels.dart';
import 'codec.dart';
import 'heading_event.dart';
import 'options.dart';

/// Returns the magnetic declination in degrees (positive east) at [timestamp],
/// or `null` if unknown. Plug in a World Magnetic Model here, for example
/// `qibla_math`'s `WorldMagneticModel.wmm2025`.
///
/// It is called once per event, so keep it cheap: cache the value and
/// recompute it only when the location changes.
typedef DeclinationProvider = double? Function(DateTime timestamp);

/// An error reported by the native side, such as `NO_SENSOR`.
class HeadingSensorException implements Exception {
  /// Creates an exception with a machine-readable [code].
  const HeadingSensorException(this.code, [this.message]);

  /// `NO_SENSOR` when the device cannot compute a heading, `NO_ACTIVITY` or
  /// another platform code otherwise.
  final String code;

  /// Human-readable detail, if any.
  final String? message;

  @override
  String toString() =>
      'HeadingSensorException($code${message == null ? '' : ', $message'})';
}

/// Compass heading from the Android rotation-vector sensors.
///
/// Android only. The native sensors are registered only while a stream has a
/// listener and the app is in the foreground.
abstract final class HeadingSensor {
  /// Counts native subscriptions. The newest one owns the native stream:
  /// subscribing again replaces it on the platform side.
  static int _generation = 0;

  /// A stream of heading readings.
  ///
  /// - [rate]: how often Android samples the sensor.
  /// - [smoothing]: optional low-pass filter on the heading, in Kotlin or in
  ///   Dart. It handles the 0°/360° wrap.
  /// - [declinationProvider]: magnetic declination for true north. When given,
  ///   every event has [HeadingEvent.trueHeading].
  /// - [useTrueNorth]: make [HeadingEvent.heading] the true heading. Requires
  ///   [declinationProvider].
  /// - [preferredSource]: use this sensor if the device has it, for example
  ///   [HeadingSource.geomagneticRotationVector] to save power. Otherwise the
  ///   best available source is used.
  ///
  /// The stream errors with [HeadingSensorException] (code `NO_SENSOR`) when
  /// the device has no usable sensor.
  ///
  /// Only one native configuration is active at a time: listening to a
  /// second stream with different options replaces the first. To share one
  /// reading between widgets, listen to the same stream.
  static Stream<HeadingEvent> events({
    SensorRate rate = SensorRate.ui,
    HeadingSmoothing smoothing = HeadingSmoothing.none,
    bool useTrueNorth = false,
    DeclinationProvider? declinationProvider,
    HeadingSource? preferredSource,
  }) {
    smoothing.validate();
    if (useTrueNorth && declinationProvider == null) {
      throw ArgumentError.value(
        useTrueNorth,
        'useTrueNorth',
        'requires a declinationProvider',
      );
    }

    final native = headingEventChannel.receiveBroadcastStream(<String, Object?>{
      'samplingPeriodUs': rate.samplingPeriodUs,
      'smoothingAlpha': smoothing.location == SmoothingLocation.native
          ? smoothing.alpha
          : null,
      'preferredSource': preferredSource?.name,
    });

    return Stream<HeadingEvent>.multi((controller) {
      final generation = ++_generation;
      final filter = smoothing.location == SmoothingLocation.dart
          ? AngleLowPassFilter(alpha: smoothing.alpha)
          : null;

      final sub = native.listen(
        (raw) {
          var event = decodeHeadingEvent(raw as Map<Object?, Object?>);
          if (filter != null) {
            event =
                event.withMagneticHeading(filter.add(event.magneticHeading));
          }
          if (declinationProvider != null) {
            final d = declinationProvider(event.timestamp);
            if (d != null) {
              event = event.withDeclination(d, useTrueNorth: useTrueNorth);
            }
          }
          controller.addSync(event);
        },
        onError: (Object error, StackTrace stack) {
          controller.addErrorSync(
            error is PlatformException
                ? HeadingSensorException(error.code, error.message)
                : error,
            stack,
          );
        },
        onDone: controller.closeSync,
      );
      controller
        ..onPause = sub.pause
        ..onResume = sub.resume
        // Once a newer events() stream has subscribed, this subscription no
        // longer owns the native stream (the platform channel has a single
        // handler). Cancelling it would send "cancel" and stop the newer
        // stream, so a superseded subscription is dropped without that.
        ..onCancel = () => generation == _generation ? sub.cancel() : null;
    });
  }

  /// Which heading sensors the device has, and the source [events] would use.
  static Future<HeadingCapabilities> capabilities() async {
    final map = await headingMethodChannel
        .invokeMapMethod<Object?, Object?>('capabilities');
    return decodeCapabilities(map);
  }

  /// Whether the device can compute a heading (it has a magnetometer and at
  /// least one usable source).
  static Future<bool> isAvailable() async => (await capabilities()).isAvailable;
}
