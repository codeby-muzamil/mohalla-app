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
import 'screens/location_screen.dart';
import 'screens/mosques_screen.dart';
import 'screens/mushaf_reader_screen.dart';
import 'screens/names_screen.dart';
import 'screens/news_screen.dart';
import 'screens/onboarding_flow.dart';
import 'screens/profile_edit_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/quran_list_screen.dart';
import 'screens/quran_reader_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sunnah_screen.dart';
import 'screens/tracker_screen.dart';
import 'screens/zakat_screen.dart';
import 'screens/zyada_screen.dart';
import 'services/gemini_service.dart';
import 'services/location_service.dart';
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
  // The user's own Gemini key (if pasted in Settings) is loaded into
  // the AI service — it wins over the --dart-define key, and without
  // any key the bot stays on offline answers.
  GeminiService.setRuntimeKey(settings.geminiApiKey);
  // GPS location: the cached location loads fast; the fresh GPS fix
  // runs in the background (LocationService.init starts the refresh
  // without waiting for it).
  final location = LocationService();
  try {
    await location.init();
  } catch (_) {}
  await NotificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<LocationService>.value(value: location),
      ],
      child: const MohallaApp(),
    ),
  );
}

class MohallaApp extends StatefulWidget {
  const MohallaApp({super.key});

  @override
  State<MohallaApp> createState() => _MohallaAppState();
}

class _MohallaAppState extends State<MohallaApp> {
  /// Splash shows on EVERY cold start, not just the first run: false
  /// until the launch splash finishes, then the real home. In-memory
  /// only — a fresh app start always shows the splash again.
  bool _splashShown = false;

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
      home: !_splashShown
          ? OnboardingFlow(
              onSplashDone: () => setState(() => _splashShown = true),
            )
          : settings.onboarded
              ? const RootScreen()
              : const OnboardingFlow(initialStep: 1),
    );
  }
}

/// Main shell: 5 bottom tabs (Community was removed 2026-11-17).
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  Timer? _azanWatcher;
  String? _azanBanner;
  late final SettingsProvider _settings;
  late final LocationService _location;

  /// Notification permission state (null = unknown / not checked yet).
  /// When false and any Azan toggle is on, a banner explains that
  /// Azan cannot sound while the app is closed (problem #13 — it
  /// used to be silently off). [ _notifPromptDismissed ] stops the
  /// nagging: once dismissed, the banner stays hidden until the
  /// permission state changes (e.g. allowed in Settings, then denied
  /// again later).
  bool? _notificationsEnabled;
  bool _notifPromptDismissed = false;

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
    WidgetsBinding.instance.addObserver(this);
    _settings = context.read<SettingsProvider>();
    _location = context.read<LocationService>();
    final settings = _settings;
    // Notification permission: check once at startup so a denied
    // permission shows the honest banner instead of silent no-Azan.
    _checkNotificationPermission();
    // Schedule today's Azan notifications from the GPS location
    // (masjid times when set). Nothing is scheduled until a
    // location is known.
    _rescheduleAzan();
    // Re-schedule whenever the location, the method/madhab, the
    // toggles, the voice or the masjid times change.
    settings.addListener(_onSettingsChanged);
    _location.addListener(_onLocationChanged);
    // In-app Azan while the app is open.
    _azanWatcher = NotificationService.startInAppWatcher(
      getCoords: () {
        final c = _location.current;
        if (c == null) return null;
        return (latitude: c.latitude, longitude: c.longitude);
      },
      getMethod: () => _settings.calculationMethod,
      getMadhab: () => _settings.madhab,
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

  void _onSettingsChanged() => _rescheduleAzan();

  void _onLocationChanged() => _rescheduleAzan();

  /// Re-check the notification permission (also when the app comes
  /// back from Settings, via didChangeAppLifecycleState). If the
  /// permission was granted, the dismissal is cleared so the prompt
  /// can appear again if it is denied again later.
  Future<void> _checkNotificationPermission() async {
    final enabled = await NotificationService.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      if (enabled == true) _notifPromptDismissed = false;
      _notificationsEnabled = enabled;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have changed the permission in the phone's
    // Settings while the app was in the background — re-check.
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  void _rescheduleAzan() {
    final coords = _location.current;
    if (coords == null) return;
    NotificationService.rescheduleAll(
      latitude: coords.latitude,
      longitude: coords.longitude,
      method: _settings.calculationMethod,
      madhab: _settings.madhab,
      notify: _settings.notify,
      reminderMinutes: _settings.reminderMinutes,
      voiceId: _settings.muezzinVoice,
      customTimings: _settings.masjidTimings,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _azanWatcher?.cancel();
    _settings.removeListener(_onSettingsChanged);
    _location.removeListener(_onLocationChanged);
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
      case 'location':
        page = const LocationScreen();
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
      case 'news':
        page = const NewsScreen();
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
    final location = context.watch<LocationService>();
    // Watched so the notification banner reacts when the user turns
    // all Azan toggles off in Settings (then Azan is off by choice
    // and the banner must disappear).
    final settings = context.watch<SettingsProvider>();
    final pages = [
      HomeScreen(
        onOpenLocation: () => _openTool('location'),
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
        subtitle: location.headerSubtitle,
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
            // Azan notifications are off because the permission was
            // denied — say so plainly, with a way to fix it. Shown
            // only while any Azan toggle is on (off by choice needs
            // no banner), and never again after dismiss until the
            // permission state changes.
            if (_notificationsEnabled == false &&
                !_notifPromptDismissed &&
                settings.notify.values.any((v) => v))
              _NotificationDeniedBanner(
                onAllow: () async {
                  await NotificationService.requestPermissions();
                  await _checkNotificationPermission();
                },
                onOpenSettings: () => _location.openSettings(),
                onDismiss: () =>
                    setState(() => _notifPromptDismissed = true),
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
/// medallion, title + location subtitle. Replaces the flat AppBar.
class _MohallaHeader extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final String subtitle;

  const _MohallaHeader({required this.title, required this.subtitle});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    // Demo v13: the header is emerald in both modes; the gold accent
    // is the bright dark-mode gold (#D9A441) at night, #C9A227 by day.
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        // Gold pattern on emerald (like the splash): the old white
        // pattern at 0.24 under the 0.5 scrim wash was ~0.12
        // effective — the girih lines merged into the emerald
        // background. Gold at 0.32 + scrim 0.30 keeps the pattern
        // clearly visible on the header.
        patternColor: isDark ? AppTheme.goldDark : AppTheme.gold,
        patternOpacity: 0.32,
        scrimAlpha: 0.30,
        glowColor: isDark ? AppTheme.goldDark : AppTheme.gold,
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
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.goldDark
                              : AppTheme.goldLight,
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
          // Demo v13 footer: sand card → chip tint by day,
          // night card → night alt after dark.
          colors: isDark
              ? const [AppTheme.nightCard, AppTheme.nightAlt]
              : const [AppTheme.cardLight, AppTheme.chipLight],
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.goldDark : AppTheme.gold,
            width: 2.5,
          ),
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
          // Pattern layer: the old 0.12 / 0.18 opacity made the
          // girih lines merge into the footer gradient — invisible
          // on a real phone. 0.30 / 0.35 keeps it clearly visible.
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.30 : 0.35,
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
    // Demo v13: active tab is a gold pill with dark text (#1A2E28);
    // inactive tabs use the muted ink of the current mode.
    final inactiveColor =
        isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    const activeText = Color(0xFF1A2E28);
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            AppTheme.goldDarkLight,
                            AppTheme.goldDark,
                            AppTheme.gold,
                          ]
                        : const [
                            AppTheme.goldLight,
                            AppTheme.gold,
                            Color(0xFF8A6D1B),
                          ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppTheme.goldDark : AppTheme.gold)
                          .withValues(alpha: 0.65),
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
                color: widget.active ? activeText : inactiveColor,
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
                  color: widget.active ? activeText : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amber banner shown when notification permission is denied while
/// Azan is switched on. Honest about the consequence (no Azan sound
/// when the app is closed; in-app Azan still works while open) and
/// offers two fixes: ask the system again, or open the app's
/// Settings page (Geolocator.openAppSettings via LocationService).
class _NotificationDeniedBanner extends StatelessWidget {
  final Future<void> Function() onAllow;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  const _NotificationDeniedBanner({
    required this.onAllow,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Demo v13 toast: #FDF6DA background, #17352A text.
      color: AppTheme.toastBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.notifications_off, color: AppTheme.emerald),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Azan notifications are off',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Notification permission is denied, so Azan cannot '
                  'sound when the app is closed. In-app Azan still '
                  'works while the app is open.',
                  style: TextStyle(fontSize: 12, color: AppTheme.ink),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        onAllow();
                      },
                      child: const Text('Allow notifications'),
                    ),
                    TextButton(
                      onPressed: onOpenSettings,
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
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
    'location': 'My Location',
    'tracker': 'Prayer Tracker + Tasbih',
    'zakat': 'Zakat Calculator',
    'sunnah': 'Sunnah & Shariah',
    'mosques': 'Nearby Mosques',
    'news': 'Islamic News',
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

