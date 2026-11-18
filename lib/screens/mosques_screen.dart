import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'location_screen.dart';

/// Nearby mosques: "Find mosques near me" opens Google Maps at the
/// phone's GPS coordinates, plus the user's own mosque card.
/// There is NO embedded map (that would need a Google Maps API key —
/// see BUILD_NOTES.md) and NO hardcoded mosque list any more: the
/// old 4 Hyderabad listings (unverified) are gone. The list itself
/// works from GPS; without a location the screen says so and offers
/// to enable it.
class MosquesScreen extends StatelessWidget {
  const MosquesScreen({super.key});

  Future<void> _openNearbyMosques(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=mosques+near+$lat%2C$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMasjidOnMaps(
    String masjidName,
    String place,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$masjidName $place')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationService>();
    final settings = context.watch<SettingsProvider>();
    final coords = location.current;
    // Demo tokens, both modes (visual only — Maps logic untouched).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        const SectionTitle(
          title: 'Nearby Mosques',
          subtitle:
              'Mosques near your GPS location — open in Google Maps.',
        ),
        if (coords == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off,
                    size: 44,
                    color: accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Location is needed to find mosques near you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    location.message.isNotEmpty
                        ? location.message
                        : 'Allow location permission so the app can find mosques around you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GoldButton(
                        label: 'Enable location',
                        icon: Icons.my_location,
                        onPressed: () => location.refresh(),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: const Text('My Location'),
                                ),
                                body: const LocationScreen(),
                              ),
                            ),
                          );
                        },
                        child: const Text('My Location'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        color: accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You are in ${coords.displayName}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GoldButton(
                      label: 'Find mosques near me',
                      icon: Icons.map,
                      onPressed: () => _openNearbyMosques(
                        coords.latitude,
                        coords.longitude,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Opens Google Maps with mosques around your current location.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ---- The user's own mosque ----
          if (settings.masjidName.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My mosque',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.masjidName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ink,
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
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        PrayerService
                                            .prayerNamesEnglish[key]!,
                                        style: TextStyle(color: ink),
                                      ),
                                    ),
                                    Text(
                                      PrayerService.formatTime(
                                        times[key]!,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                    if (settings.masjidTimings[key] !=
                                        null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 6),
                                        child: Text(
                                          'My mosque',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: gold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View on Maps'),
                      onPressed: () => _openMasjidOnMaps(
                        settings.masjidName,
                        coords.displayName,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        const SampleNote(
          text:
              'Mosque timings shown are your own mosque\'s settings — '
              'confirm the actual congregation times from the mosque notice board.',
        ),
      ],
    );
  }
}
