import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'screens/ai_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/duas_screen.dart';
import 'screens/hadith_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/mosques_screen.dart';
import 'screens/mushaf_reader_screen.dart';
import 'screens/names_screen.dart';
import 'screens/onboarding_flow.dart';
import 'screens/profile_edit_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/quran_list_screen.dart';
import 'screens/quran_reader_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sunnah_screen.dart';
import 'screens/timezones_screen.dart';
import 'screens/tracker_screen.dart';
import 'screens/zakat_screen.dart';
import 'screens/zyada_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/pattern.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Startup must never kill the app before the first frame: if the
  // timezone data or the saved settings fail to load, fall back to
  // defaults instead of crashing on the splash screen.
  try {
    tzdata.initializeTimeZones();
  } catch (_) {}
  final settings = SettingsProvider();
  try {
    await settings.init();
  } catch (_) {}
  await NotificationService.init();
  runApp(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: const MohallaApp(),
    ),
  );
}

class MohallaApp extends StatelessWidget {
  const MohallaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Mohalla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        // Elder / large-font mode: scale all text 1.3x.
        final scaler = settings.elderMode
            ? const TextScaler.linear(1.3)
            : TextScaler.noScaling;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        );
      },
      home: settings.onboarded
          ? const RootScreen()
          : const OnboardingFlow(),
    );
  }
}

/// Main shell: 5 bottom tabs (Community was removed 2026-11-17).
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  Timer? _azanWatcher;
  String? _azanBanner;
  late final SettingsProvider _settings;

  static const _titles = [
    'Mohalla',
    'Quran',
    'Learn',
    'AI Dost',
    'More',
  ];

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    final settings = _settings;
    // Schedule today's Azan notifications (masjid times when set).
    NotificationService.rescheduleAll(
      city: settings.city,
      notify: settings.notify,
      reminderMinutes: settings.reminderMinutes,
      voiceId: settings.muezzinVoice,
      customTimings: settings.masjidTimings,
    );
    // Re-schedule whenever the city / toggles / voice / masjid times change.
    settings.addListener(_onSettingsChanged);
    // In-app Azan while the app is open.
    _azanWatcher = NotificationService.startInAppWatcher(
      getCity: () => _settings.city,
      getNotify: () => _settings.notify,
      getCustomTimings: () => _settings.masjidTimings,
      onAzan: (prayerKey) {
        NotificationService.playAzan(_settings.muezzinVoice);
        if (mounted) {
          setState(() => _azanBanner = prayerKey);
        }
      },
    );
  }

  void _onSettingsChanged() {
    NotificationService.rescheduleAll(
      city: _settings.city,
      notify: _settings.notify,
      reminderMinutes: _settings.reminderMinutes,
      voiceId: _settings.muezzinVoice,
      customTimings: _settings.masjidTimings,
    );
  }

  @override
  void dispose() {
    _azanWatcher?.cancel();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _openTool(String key) {
    Widget? page;
    switch (key) {
      case 'names':
        page = const NamesScreen();
        break;
      case 'mushaf':
        page = const MushafReaderScreen();
        break;
      case 'duas':
        page = const DuasScreen();
        break;
      case 'hadith':
        page = const HadithScreen();
        break;
      case 'calendar':
        page = const HijriCalendarScreen();
        break;
      case 'qibla':
        page = const QiblaScreen();
        break;
      case 'timezones':
        page = const TimezonesScreen();
        break;
      case 'tracker':
        page = const TrackerScreen();
        break;
      case 'zakat':
        page = const ZakatScreen();
        break;
      case 'sunnah':
        page = const SunnahScreen();
        break;
      case 'mosques':
        page = const MosquesScreen();
        break;
      case 'settings':
        page = const SettingsScreen();
        break;
      case 'profile':
        // The Edit Profile screen has its own Scaffold + AppBar,
        // so it is pushed directly instead of via _ToolPage.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
        );
        return;
    }
    if (page != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ToolPage(title: key, child: page!)),
      );
    }
  }

  void _openAyah(int surah, int ayah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(
          surahNumber: surah,
          initialAyah: ayah,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      HomeScreen(
        onOpenTimezones: () => _openTool('timezones'),
        onOpenQibla: () => _openTool('qibla'),
        onOpenAyah: _openAyah,
        onOpenTool: _openTool,
        onOpenTab: (i) => setState(() => _index = i),
      ),
      const QuranListScreen(),
      const LearnScreen(),
      const AiScreen(),
      ZyadaScreen(onOpen: _openTool),
    ];

    return Scaffold(
      appBar: _MohallaHeader(
        title: _titles[_index],
        subtitle:
            '${_settings.city.name} • ${_settings.city.timeZone}',
      ),
      // App-wide Islamic pattern behind every tab (gold-on-sand in
      // light mode, faint white-on-night in dark mode) — the old plain
      // scaffold background is what made the app look plain white.
      body: PatternBackground(
        base: isDark ? AppTheme.nightBg : AppTheme.sand,
        patternColor: isDark ? Colors.white : AppTheme.emerald,
        patternOpacity: isDark ? 0.10 : 0.20,
        child: Column(
          children: [
            if (_azanBanner != null)
              Container(
                width: double.infinity,
                color: AppTheme.emerald,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mosque, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Time for ${_azanBanner![0].toUpperCase()}${_azanBanner!.substring(1)} prayer — Azan',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        NotificationService.stopAzan();
                        setState(() => _azanBanner = null);
                      },
                      child: const Text(
                        'Stop',
                        style: TextStyle(color: AppTheme.goldLight),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      ),
      bottomNavigationBar: _MohallaFooter(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// 3D header: emerald gradient + Islamic pattern + gold glow, gold M
/// medallion, title + city subtitle. Replaces the flat AppBar.
class _MohallaHeader extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final String subtitle;

  const _MohallaHeader({required this.title, required this.subtitle});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: PatternBackground(
        base: AppTheme.emerald,
        patternColor: Colors.white,
        patternOpacity: 0.24,
        glowColor: AppTheme.gold,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const GoldMark(size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.goldLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3D footer: raised gold pill for the active tab (with glow), press
/// scale on every tab, gold top border. Replaces the flat
/// BottomNavigationBar.
class _MohallaFooter extends StatelessWidget {
  final int index;
  final void Function(int) onTap;

  const _MohallaFooter({required this.index, required this.onTap});

  static const _items = [
    (Icons.home, 'Home'),
    (Icons.menu_book, 'Quran'),
    (Icons.school, 'Learn'),
    (Icons.chat, 'AI Dost'),
    (Icons.more_horiz, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Rich 3D footer: gradient body (never a plain white bar), a
    // thick solid gold top border, a faint Islamic pattern layer, and
    // a raised glowing gold pill for the active tab. The old footer
    // was a flat white container with a 1.5px half-transparent gold
    // line — on a real phone it read as a plain white bar.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0E3A2B), Color(0xFF082A1F)]
              : const [Color(0xFFFFFBF0), Color(0xFFF1E7C8)],
        ),
        border: const Border(
          top: BorderSide(color: AppTheme.gold, width: 2.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.12 : 0.18,
              child: CustomPaint(
                painter: IslamicPatternPainter(
                  color: isDark ? Colors.white : AppTheme.emerald,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _FooterItem(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        active: i == index,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FooterItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_FooterItem> createState() => _FooterItemState();
}

class _FooterItemState extends State<_FooterItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? Colors.white70 : Colors.grey.shade600;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(
            0,
            widget.active ? -6 : 0,
            0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: widget.active
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.goldLight,
                      AppTheme.gold,
                      Color(0xFF9A7B1A),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.65),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 24,
                color: widget.active ? AppTheme.ink : inactiveColor,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      widget.active ? FontWeight.bold : FontWeight.normal,
                  color: widget.active ? AppTheme.ink : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple wrapper page for tools opened from the Zyada tab.
class _ToolPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _ToolPage({required this.title, required this.child});

  static const _titles = {
    'names': '99 Names of Allah',
    'mushaf': 'Mushaf — 16 Line',
    'duas': 'Duas & Azkar',
    'hadith': 'Hadith Library',
    'calendar': 'Hijri Calendar',
    'qibla': 'Qibla Compass 3D',
    'timezones': 'Timezones',
    'tracker': 'Prayer Tracker + Tasbih',
    'zakat': 'Zakat Calculator',
    'sunnah': 'Sunnah & Shariah',
    'mosques': 'Nearby Mosques',
    'settings': 'Settings',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(_titles[title] ?? title)),
      // Same app-wide pattern as the tab pages.
      body: PatternBackground(
        base: isDark ? AppTheme.nightBg : AppTheme.sand,
        patternColor: isDark ? Colors.white : AppTheme.emerald,
        patternOpacity: isDark ? 0.10 : 0.20,
        child: child,
      ),
    );
  }
}

