import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Zyada (More): the tools grid + profile card.
/// [onOpen] receives a tool key: names, duas, hadith, calendar, qibla,
/// timezones, tracker, zakat, sunnah, mosques, settings, profile.
class ZyadaScreen extends StatelessWidget {
  final void Function(String key) onOpen;

  const ZyadaScreen({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tools = [
      _Tool('names', Icons.favorite, '99 Names of Allah', 'Asma-ul-Husna'),
      _Tool('mushaf', Icons.auto_stories, 'Mushaf — 16 Line',
          'Pakistani Mushaf • 548 pages'),
      _Tool('duas', Icons.menu_book, 'Duas & Azkar', 'Verified duas, 9 categories'),
      _Tool('hadith', Icons.book, 'Hadith Library', 'Verified hadiths (Bukhari & Muslim)'),
      _Tool('calendar', Icons.calendar_month, 'Hijri Calendar', 'Calendar & events'),
      _Tool('qibla', Icons.explore, 'Qibla Compass 3D', 'Kaaba • 267° Hyderabad'),
      _Tool('timezones', Icons.public, 'Timezones', 'Worldwide timings'),
      _Tool('tracker', Icons.check_circle, 'Prayer Tracker', 'Daily prayers + Tasbih'),
      _Tool('zakat', Icons.calculate, 'Zakat Calculator', '2.5% calculation'),
      _Tool('sunnah', Icons.lightbulb, 'Sunnah & Shariah', 'Daily guidance'),
      _Tool('mosques', Icons.mosque, 'Nearby Mosques', 'Mosques in Hyderabad'),
      _Tool('settings', Icons.settings, 'Settings', 'Dark mode, Azan, voice'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PressableCard(
          color: AppTheme.emerald,
          padding: EdgeInsets.zero,
          onTap: () => onOpen('profile'),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.ink,
              child: Icon(Icons.person),
            ),
            title: Text(
              settings.profileName.isEmpty
                  ? 'Assalamu Alaikum, Guest!'
                  : 'Assalamu Alaikum, ${settings.profileName}!',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              settings.profileEmail.isEmpty
                  ? 'Set up profile'
                  : settings.profileEmail,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: TextButton(
              onPressed: () => onOpen('profile'),
              child: const Text(
                'Edit',
                style: TextStyle(color: AppTheme.goldLight),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            // 1.05 (not 1.35): the old ratio made cells ~129px tall on a
            // ~390px phone while ToolCard content needs ~135px — every
            // box overflowed by ~1.6px at the bottom. Taller cells give
            // ~30px headroom, and ToolCard itself is now tighter, so
            // nothing overflows even at 1.3x elder-mode text scaling.
            childAspectRatio: 1.05,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: tools.length,
          itemBuilder: (context, i) {
            final t = tools[i];
            return ToolCard(
              icon: t.icon,
              title: t.title,
              subtitle: t.subtitle,
              onTap: () => onOpen(t.key),
            );
          },
        ),
      ],
    );
  }
}

class _Tool {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;

  const _Tool(this.key, this.icon, this.title, this.subtitle);
}
