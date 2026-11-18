import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Nearby mosques: a list of real Hyderabad mosques (from the public
/// jamaat360 listings used in the web prototype) with Google Maps links.
/// There is NO embedded map — that would need a Google Maps API key
/// (see BUILD_NOTES.md). The list itself works offline.
class MosquesScreen extends StatelessWidget {
  const MosquesScreen({super.key});

  static const _mosques = [
    {
      'name': 'Jamia Masjid Khizra',
      'area': 'Hyderabad',
      'note': 'Qibla 267° • Azan: Fajr 05:21, Dhuhr 12:11, Asr 04:04, Maghrib 05:40, Isha 06:59 (listing, unverified)',
    },
    {
      'name': 'Jamia Masjid Faizan-e-Meraj un Nabi',
      'area': 'Qasimabad, Hyderabad',
      'note': 'Qibla 267° • Azan: Fajr 05:22, Dhuhr 12:12, Asr 04:04, Maghrib 05:41, Isha 06:59 (listing, unverified)',
    },
    {
      'name': 'Jamia Masjid Ahlehadees Diplai Memon',
      'area': 'Diplai Memon Society, Hyderabad',
      'note': 'Verified mosque • Qibla 267° • Fajr Congregation 05:34 (listing)',
    },
    {
      'name': 'Masjid E Fasih Jung',
      'area': 'Hyderabad',
      'note': 'Congregation: Fajr 5:55 AM, Dhuhr 1:30 PM, Asr 4:30 PM, Maghrib 5:47 PM, Isha 7:30 PM (calculated, unverified)',
    },
  ];

  Future<void> _openMaps(String name) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name Hyderabad Sindh')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(
          title: 'Nearby Mosques',
          subtitle:
              'Mosques in Hyderabad, Sindh — open in Google Maps.',
        ),
        for (final m in _mosques)
          Card(
            child: ListTile(
              leading: const Icon(Icons.mosque, color: AppTheme.emerald),
              title: Text(m['name']!),
              subtitle: Text('${m['area']}\n${m['note']}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.map),
                tooltip: 'View on Maps',
                onPressed: () => _openMaps(m['name']!),
              ),
            ),
          ),
        const SampleNote(
          text:
              'Mosque timings are from listings and are "Awaiting Verification" '
              '— confirm the actual congregation times from the mosque notice board.',
        ),
      ],
    );
  }
}
