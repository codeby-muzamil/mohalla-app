import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Zyada (More): the tools grid + profile card.
/// [onOpen] receives a tool key: names, duas, hadith, calendar, qibla,
/// location, tracker, zakat, sunnah, mosques, news, settings, profile.
class ZyadaScreen extends StatelessWidget {
  final void Function(String key) onOpen;

  const ZyadaScreen({super.key, required this.onOpen});

  /// Play Store page (the app is not published yet — the link opens
  /// the store page once it is; Share sends the same link).
  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.mohalla.app';

  static Future<void> _shareApp() async {
    await Share.share(
      'Get Mohalla — your mohalla, your mosque. Prayer times, Quran, '
      'Qibla and duas, free for everyone.\n$_storeUrl',
    );
  }

  static Future<void> _rateApp() async {
    await launchUrl(
      Uri.parse(_storeUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tools = [
      _Tool('names', Icons.favorite, '99 Names of Allah', 'Asma-ul-Husna'),
      _Tool('mushaf', Icons.auto_stories, 'Mushaf — 16 Line',
          'Pakistani Mushaf • 548 pages'),
      _Tool('duas', Icons.menu_book, 'Duas & Azkar', 'Verified duas, 9 categories'),
      _Tool('hadith', Icons.book, 'Hadith Library', 'Verified hadiths (Bukhari & Muslim)'),
      _Tool('calendar', Icons.calendar_month, 'Hijri Calendar', 'Calendar & events'),
      _Tool('qibla', Icons.explore, 'Qibla Compass 3D', 'Qibla direction & distance'),
      _Tool('location', Icons.public, 'My Location', 'GPS location & timings'),
      _Tool('tracker', Icons.check_circle, 'Prayer Tracker', 'Daily prayers + Tasbih'),
      _Tool('zakat', Icons.calculate, 'Zakat Calculator', '2.5% calculation'),
      _Tool('sunnah', Icons.lightbulb, 'Sunnah & Shariah', 'Daily guidance'),
      _Tool('mosques', Icons.mosque, 'Nearby Mosques', 'Mosques near you'),
      _Tool('news', Icons.newspaper, 'Islamic News', 'Announcements & guides'),
      _Tool('settings', Icons.settings, 'Settings', 'Dark mode, Azan, voice'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        PressableCard(
          color: isDark ? AppTheme.emeraldLight : AppTheme.emerald,
          padding: EdgeInsets.zero,
          onTap: () => onOpen('profile'),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDark ? AppTheme.goldDark : AppTheme.gold,
              foregroundColor: const Color(0xFF1A2E28),
              child: const Icon(Icons.person),
            ),
            title: Text(
              settings.profileName.isEmpty
                  ? 'Assalamu Alaikum, Guest!'
                  : 'Assalamu Alaikum, ${settings.profileName}!',
              style: const TextStyle(color: Color(0xFFF7F1E3)),
            ),
            subtitle: Text(
              settings.profileEmail.isEmpty
                  ? 'Set up profile'
                  : settings.profileEmail,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: TextButton(
              onPressed: () => onOpen('profile'),
              child: Text(
                'Edit',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.goldDarkLight
                      : AppTheme.goldLight,
                ),
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
            // Demo .tool-cell is compact (icon + label, min-height 84):
            // 1.5 keeps cells ~116px tall on a ~390px phone — room for
            // the icon, a 2-line label and elder-mode (1.3x) scaling.
            childAspectRatio: 1.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: tools.length,
          itemBuilder: (context, i) {
            final t = tools[i];
            return _ToolCell(
              icon: t.icon,
              title: t.title,
              subtitle: t.subtitle,
              onTap: () => onOpen(t.key),
            );
          },
        ),
        const SizedBox(height: 16),
        // Demo v13 More: Share app + Rate app, then the free note.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share app'),
                onPressed: _shareApp,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.star, size: 18),
                label: const Text('Rate app'),
                onPressed: _rateApp,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Mohalla · Free for everyone',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.goldDark : AppTheme.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'No ads, no paywall — Quran, prayer times, duas and learning '
          'are free for every Muslim, in every mohalla.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: muted),
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

/// Demo v13 `.tool-cell`: surface card, radius 20, shadow, icon +
/// 12px semibold label centred, min-height 84. (The shared ToolCard
/// is left-aligned with a 14px title, so the demo cell lives here —
/// common.dart is outside this pass.) Subtitle kept as a small
/// centred muted line so no tool description is lost.
class _ToolCell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return PressableCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 84),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
