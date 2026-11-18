import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:heading_sensor/heading_sensor.dart';
import 'package:qibla_math/qibla_math.dart'
    hide normalizeDegrees, signedAngleDifference;

import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';

/// Qibla Compass (3D look): a perspective-tilted compass dial that
/// rotates with the phone's rotation-vector sensor (heading_sensor —
/// Android's TYPE_ROTATION_VECTOR, the same sensor Android's own
/// compass uses), a 3D-style Kaaba in the centre, and the Kaaba
/// turning GREEN within ~5 degrees of the Qibla bearing. Sensor-only
/// (no manual mode). Bearing + distance are computed from the selected
/// city's coordinates (great-circle) — never hardcoded. The heading
/// is true north: magnetic declination comes from qibla_math
/// (WMM2025) for the selected city.
/// HONEST CAVEAT: heading_sensor 0.1.0 has not yet been tested on a
/// physical phone (emulator + unit tests only, per its author), so the
/// live status line and the red no-sensor card stay on screen — if
/// the sensor does not report on a real phone, the user sees that
/// instead of a frozen dial. The phone test is the proof.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  // Heading shown on the dial. heading_sensor reports true north
  // (declination-corrected, see _startCompass), so it compares
  // directly with the true-north Qibla bearing.
  final ValueNotifier<double> _headingNotifier = ValueNotifier(0);
  StreamSubscription<HeadingEvent>? _headingSub;
  Timer? _watchdogTimer;
  DateTime _openedAt = DateTime.now();
  DateTime? _lastEvent;

  // Last reported event details, shown in the live status line.
  // Updated WITHOUT setState: the status line rebuilds from
  // _headingNotifier, which fires on every event, so it always
  // shows the latest values without rebuilding the whole screen
  // on every sensor tick.
  String _accuracyName = '—';
  String _sourceName = '—';
  bool _needsCalibration = false;
  bool _sensorUnavailable = false;
  bool _noSensorData = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _startCompass();
    // Watchdog: no heading event at all 5s after opening → a visible
    // "no sensor data" card. A dead sensor must never look like a
    // frozen dial.
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lastEvent == null &&
          !_noSensorData &&
          DateTime.now().difference(_openedAt).inSeconds >= 5) {
        setState(() => _noSensorData = true);
      }
    });
  }

  /// Start the heading stream. Magnetic declination (WMM2025,
  /// qibla_math) is computed ONCE per city and handed to
  /// heading_sensor, so the heading it reports is true north,
  /// matching the true-north Qibla bearing. If the model cannot
  /// run (date outside the WMM2025 validity period 2025-2030),
  /// the provider returns null and the heading stays magnetic.
  Future<void> _startCompass() async {
    final city = context.read<SettingsProvider>().city;
    double? declination;
    try {
      declination = WorldMagneticModel.wmm2025
          .calculate(
            latitude: city.latitude,
            longitude: city.longitude,
            decimalYear: decimalYear(DateTime.now()),
          )
          .declination;
    } catch (_) {
      declination = null;
    }
    bool available = false;
    try {
      available = await HeadingSensor.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    if (!available) {
      setState(() => _sensorUnavailable = true);
      return;
    }
    _headingSub = HeadingSensor.events(
      rate: SensorRate.ui,
      smoothing: const HeadingSmoothing.native(0.15),
      useTrueNorth: true,
      declinationProvider: (_) => declination,
    ).listen((event) {
      _lastEvent = DateTime.now();
      if (_noSensorData && mounted) {
        setState(() => _noSensorData = false);
      }
      _accuracyName = event.accuracy.name;
      _sourceName = _prettySourceName(event.source.name);
      if (event.needsCalibration != _needsCalibration && mounted) {
        setState(() => _needsCalibration = event.needsCalibration);
      }
      _headingNotifier.value = event.heading;
    }, onError: (Object _) {
      // NO_SENSOR (or any stream failure): show the red card instead
      // of leaving a frozen dial.
      if (mounted) setState(() => _sensorUnavailable = true);
    });
  }

  /// 'rotationVector' → 'Rotation vector', 'fusion' → 'Fusion'.
  static String _prettySourceName(String name) {
    final spaced = name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => ' ${m.group(0)!.toLowerCase()}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Shortest signed arc from [from] to [to] in degrees (-180..180).
  static double _shortestArc(double from, double to) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  @override
  void dispose() {
    _headingSub?.cancel();
    _watchdogTimer?.cancel();
    _headingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final city = settings.city;
    final bearing = PrayerService.qiblaBearing(city);
    final distance = PrayerService.distanceToMakkahKm(city);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Qibla from ${city.name}: ${bearing.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Distance to Makkah: ${distance.toStringAsFixed(0)} km',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rotate the phone — when the Kaaba turns green, you are '
                  'facing the Qibla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 340,
          // Only the dial rebuilds when the heading changes.
          child: ValueListenableBuilder<double>(
            valueListenable: _headingNotifier,
            builder: (context, heading, _) {
              // Offset between where the phone points and Qibla.
              final diff = _shortestArc(heading, bearing);
              return _CompassDial(
                heading: heading,
                bearing: bearing,
                aligned: diff.abs() <= 5,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Live sensor status — always visible, so the user can SEE
        // whether the compass sensor is reporting (and what heading,
        // accuracy and source it reports), instead of guessing from
        // a frozen dial.
        ValueListenableBuilder<double>(
          valueListenable: _headingNotifier,
          builder: (context, heading, _) {
            return Text(
              'Heading: ${heading.round()}°  •  '
              'Accuracy: $_accuracyName  •  '
              '$_sourceName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            );
          },
        ),
        const SizedBox(height: 8),
        if (_sensorUnavailable || _noSensorData)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Text(
              'No reading from the compass sensor — this phone has no '
              'magnetometer or the sensor is off.\n'
              'Tip: move the phone in a figure-8 motion 2-3 times to '
              'calibrate the compass.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (_needsCalibration && !_sensorUnavailable && !_noSensorData)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber),
            ),
            child: const Text(
              'Compass needs calibration — move the phone in a figure-8 '
              'motion 2-3 times, away from metal and magnets.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Note: the emulator has no compass sensor. On a real phone it '
          'runs on the rotation-vector sensor; the status line above shows whether the '
          'sensor is reporting.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

/// The compass dial with a 3D perspective tilt and a Kaaba in the middle
/// that turns green when aligned with Qibla.
class _CompassDial extends StatelessWidget {
  final double heading; // where the phone points (0-360)
  final double bearing; // Qibla bearing (0-360)
  final bool aligned;

  const _CompassDial({
    required this.heading,
    required this.bearing,
    required this.aligned,
  });

  @override
  Widget build(BuildContext context) {
    // Dial rotates so that "up" is always North relative to the phone.
    final dialRotation = -heading * math.pi / 180;
    return Center(
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(0.28),
        alignment: Alignment.center,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFDF8E7), Color(0xFFEADFC2)],
            ),
            border: Border.all(color: AppTheme.gold, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: dialRotation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Degree ticks.
                    for (var d = 0; d < 360; d += 15)
                      Transform.rotate(
                        angle: d * math.pi / 180,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: d % 90 == 0 ? 3 : 1.5,
                            height: d % 90 == 0 ? 16 : 9,
                            color: d % 90 == 0
                                ? AppTheme.emerald
                                : Colors.brown.shade300,
                          ),
                        ),
                      ),
                    // Qibla marker on the dial (rotates with the dial).
                    Transform.rotate(
                      angle: bearing * math.pi / 180,
                      child: const Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 26),
                          child: Icon(
                            Icons.navigation,
                            color: AppTheme.emerald,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cardinal letters (fixed to the dial frame, not the phone).
              const _CardinalLabels(),
              // The Kaaba in the middle.
              _KaabaBox(aligned: aligned),
              if (aligned)
                const Positioned(
                  bottom: 18,
                  left: 40,
                  right: 40,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Qibla found ✓',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardinalLabels extends StatelessWidget {
  const _CardinalLabels();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: AppTheme.emerald,
    );
    return const Stack(
      children: [
        Positioned(top: 34, left: 0, right: 0, child: Center(child: Text('N', style: style))),
        Positioned(bottom: 34, left: 0, right: 0, child: Center(child: Text('S', style: style))),
        Positioned(left: 34, top: 0, bottom: 0, child: Center(child: Text('W', style: style))),
        Positioned(right: 34, top: 0, bottom: 0, child: Center(child: Text('E', style: style))),
      ],
    );
  }
}

/// A 3D-style Kaaba: black cube with gold band + gold door.
/// Turns green (with glow) when the phone points at Qibla.
class _KaabaBox extends StatelessWidget {
  final bool aligned;

  const _KaabaBox({required this.aligned});

  @override
  Widget build(BuildContext context) {
    final mainColor = aligned ? Colors.green.shade600 : Colors.black87;
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            mainColor,
            mainColor.withValues(alpha: 0.75),
          ],
        ),
        border: Border.all(
          color: aligned ? Colors.greenAccent : AppTheme.gold,
          width: 2,
        ),
        boxShadow: aligned
            ? [
                const BoxShadow(
                  color: Colors.greenAccent,
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ]
            : const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          // Gold band.
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 12,
            color: AppTheme.gold,
          ),
          const Spacer(),
          // Gold door.
          Container(
            width: 22,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
