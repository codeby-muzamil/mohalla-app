import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/location_service.dart';
import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../widgets/common.dart';

/// My Location: everything about the phone's GPS location — the
/// detected place, the GPS state, today's prayer times at this
/// location, and the Qibla bearing + distance.
///
/// There is NO city picker and NO timezone list any more: prayer
/// times, Qibla, mosques, Azan and the countdown all come from the
/// phone's GPS location. The last known location is kept on the
/// phone so timings still show when GPS is briefly unavailable.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // Keep the "last updated" time fresh once a minute.
    _clockTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationService>();
    final settings = context.watch<SettingsProvider>();
    final coords = location.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        const SectionTitle(
          title: 'My Location',
          subtitle:
              'Prayer timings from your phone\'s GPS location.',
        ),
        // ---- GPS status card ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (coords == null
                                ? Colors.red
                                : accent)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        coords == null
                            ? Icons.location_off
                            : Icons.location_on,
                        color: coords == null ? Colors.red : accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        coords == null
                            ? 'Location not available'
                            : coords.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (coords != null) ...[
                  const SizedBox(height: 4),
                  Text(coords.coordinatesLabel),
                  Text(
                    'Last updated: '
                    '${DateFormat('h:mm a').format(coords.updatedAt)}'
                    '${coords.fromCache ? ' (last known location)' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                ],
                if (location.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    location.message,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GoldButton(
                      label: 'Refresh location',
                      icon: Icons.refresh,
                      onPressed: () => location.refresh(),
                    ),
                    if (location.status ==
                        LocationStatus.permissionDeniedForever)
                      GoldButton(
                        label: 'Open settings',
                        icon: Icons.settings,
                        onPressed: () => location.openSettings(),
                      ),
                    if (location.status ==
                        LocationStatus.serviceDisabled)
                      GoldButton(
                        label: 'Open location settings',
                        icon: Icons.location_on,
                        onPressed: () => location.openLocationSettings(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (coords != null) ...[
          // ---- Today's prayer times at this location ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY\'S PRAYER TIMES HERE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.1,
                      color: gold,
                    ),
                  ),
                  Text(
                    '${settings.calculationMethodLabel} method, '
                    '${settings.madhabLabel} Asr'
                    '${settings.masjidTimings.isNotEmpty ? ' • My mosque timings' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final times =
                          PrayerService.effectiveTimesFor(
                        coords.latitude,
                        coords.longitude,
                        DateTime(now.year, now.month, now.day),
                        method: settings.calculationMethod,
                        madhab: settings.madhab,
                        custom: settings.masjidTimings,
                      );
                      return Column(
                        children: [
                          for (final key in [
                            'fajr',
                            'dhuhr',
                            'asr',
                            'maghrib',
                            'isha',
                          ]) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      PrayerService
                                          .prayerNamesEnglish[key]!,
                                    ),
                                  ),
                                  Text(
                                    PrayerService.formatTime(times[key]!),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (key != 'isha') const Divider(height: 1),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ---- Qibla from here ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QIBLA FROM HERE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.1,
                      color: gold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bearing: ${PrayerService.qiblaBearing(coords.latitude, coords.longitude).toStringAsFixed(0)}° • '
                    'Distance to Makkah: ${PrayerService.distanceToMakkahKm(coords.latitude, coords.longitude).toStringAsFixed(0)} km',
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const SampleNote(
          text:
              'Prayer times are calculated on your phone from your GPS '
              'location — no city is stored, and your location is never '
              'sent anywhere.',
        ),
      ],
    );
  }
}
