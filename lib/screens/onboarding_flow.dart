import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/languages.dart';
import '../services/notification_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern.dart';

/// Nusuk-style first-launch flow (shown only until the profile is set):
///   1. Splash — Islamic pattern + gold M mark in the centre.
///   2. Permissions — explains Azan notifications + GPS location
///      (prayer timings and Qibla come from the phone's location),
///      requests notification permission.
///   3. Login — app icon top-right, Arabic calligraphy words orbiting
///      in slow circles, Gmail login + Skip (profile stays local-only;
///      real Google sign-in needs Firebase — see BUILD_NOTES.md).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageCtrl = PageController();
  int _step = 0;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) _goTo(1);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    if (!mounted) return;
    setState(() => _step = step);
    // animateToPage can throw if the controller is disposed mid-animation;
    // a navigation failure must never kill the app on the splash screen.
    try {
      if (_pageCtrl.hasClients) {
        _pageCtrl.animateToPage(
          step,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      }
    } catch (_) {}
  }

  void _finish({bool skip = false, String name = '', String email = ''}) {
    context.read<SettingsProvider>().setProfile(
          skip ? '' : name.trim(),
          skip ? '' : email.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _SplashPage(onTap: () => _goTo(1)),
          _PermissionsPage(
            onNext: () => _goTo(2),
          ),
          _LoginPage(
            onFinish: (name, email) =>
                _finish(name: name, email: email),
            onSkip: () => _finish(skip: true),
          ),
        ],
      ),
    );
  }
}

/// App icon mark (5B refined-flat mosque, gold on emerald).
/// Uses the launcher-icon artwork (assets/images/mohalla_icon.png)
/// in a ROUNDED SQUARE — never clipped to a circle. The circle clip cut
/// off the minarets/dome (the artwork nearly fills the square source), so
/// the icon looked cut on the splash, login and header. The old version
/// drew a text 'M' in a gold circle, which is why the app showed a bare
/// letter everywhere the mark is used.
/// The Splash screen passes the 5A 3D artwork instead
/// (assets/images/mohalla_splash_icon.png) via [asset]; everywhere else
/// shows the 5B mark (header, login, permissions).
class GoldMark extends StatelessWidget {
  final double size;

  /// Icon artwork to show. Defaults to the 5B launcher mark.
  final String asset;

  const GoldMark({
    super.key,
    this.size = 120,
    this.asset = 'assets/images/mohalla_icon.png',
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.24;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        // Artwork sits back from the frame on all 4 sides (8% inset),
        // so the full logo shows with a margin — never edge to edge.
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            // If the asset ever fails to bundle, show a mosque mark instead
            // of an empty box — the splash must never die on a missing image.
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppTheme.emerald,
              child: Icon(
                Icons.mosque,
                color: AppTheme.gold,
                size: size * 0.55,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashPage extends StatefulWidget {
  final VoidCallback onTap;

  const _SplashPage({required this.onTap});

  @override
  State<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<_SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  // Demo v13 orbit: the Arabic words circle the mark on a slow 46s spin.
  late final AnimationController _orbit;

  /// Words on the splash orbit (demo v13: 8 words).
  static const _orbitWords = [
    'الله',
    'محمد',
    'قرآن',
    'سلام',
    'نور',
    'إيمان',
    'ذكر',
    'صبر',
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 46),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    _orbit.dispose();
    super.dispose();
  }

  /// Words placed on a circle of radius 118 around the mark, moving
  /// with [angle]. Only the POSITION moves — each word stays upright.
  List<Widget> _splashOrbitWords(double angle) {
    final out = <Widget>[];
    for (var i = 0; i < _orbitWords.length; i++) {
      final a = angle + i * 2 * math.pi / _orbitWords.length;
      final dx = 118 * math.cos(a);
      final dy = 118 * math.sin(a);
      out.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: Text(
            _orbitWords[i],
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              // Splash background is always dark emerald: demo orbit
              // gold #F0D488.
              color: Color(0xFFF0D488),
            ),
          ),
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: PatternBackground(
        base: AppTheme.emeraldDark,
        patternColor: AppTheme.gold,
        patternOpacity: 0.30,
        glowColor: AppTheme.gold,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, fade, child) => Opacity(
            opacity: fade,
            child: child,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20,
                  color: AppTheme.goldLight,
                ),
              ),
              const SizedBox(height: 28),
              // Gold ring + glow around the M mark. Rounded-square (NOT
              // a circle): GoldMark itself is a rounded square, and the
              // old circular ring cut across its corners — that was the
              // "logo cut" on the splash. Radius 44 = 12 padding +
              // the mark's own 24% corner radius. The 8 demo orbit
              // words circle the ring (radius 118) on the 46s spin.
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(44),
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.30),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, child) {
                          return Transform.scale(
                            // Gentle pulse only (was 1.04): the icon must not
                            // look zoomed — the full logo has to stay visible.
                            scale: 1 + 0.02 * _c.value,
                            child: child,
                          );
                        },
                        // Splash shows the 5A 3D artwork; everywhere else
                        // uses the 5B mark (GoldMark default).
                        child: const GoldMark(
                          size: 132,
                          asset: 'assets/images/mohalla_splash_icon.png',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: AnimatedBuilder(
                        animation: _orbit,
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: _splashOrbitWords(
                              _orbit.value * 2 * math.pi,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Mohalla',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.goldLight, AppTheme.gold],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your mosque, your neighbourhood — for the whole world.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppTheme.gold,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Loading...',
                style: TextStyle(color: AppTheme.goldLight, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionsPage extends StatefulWidget {
  final VoidCallback onNext;

  const _PermissionsPage({required this.onNext});

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage> {
  bool _asked = false;

  Future<void> _request() async {
    setState(() => _asked = true);
    await NotificationService.requestPermissions();
    if (mounted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return PatternBackground(
      base: isDark ? AppTheme.nightBg : AppTheme.sand,
      patternColor: isDark ? AppTheme.goldDark : AppTheme.emerald,
      patternOpacity: 0.18,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GoldMark(size: 64),
              const SizedBox(height: 20),
              Text(
                'Permission needed',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 3,
                width: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.goldLight, AppTheme.gold],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohalla needs these two things so Azan and prayer '
                'timings work correctly.',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 20),
              _permTile(
                Icons.notifications_active,
                'Azan notifications',
                'When prayer time comes, you will get an Azan notification '
                    'and sound. You can turn it off for each prayer in Settings.',
              ),
              const SizedBox(height: 12),
              _permTile(
                Icons.my_location,
                'Location (GPS)',
                'Prayer timings and Qibla are calculated from your phone\'s '
                    'location. Your location stays on your phone — it is '
                    'never sent anywhere.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _asked ? null : _request,
                  style: ElevatedButton.styleFrom(
                    // Demo gold button: gold bg, #1A2E28 text, radius 14.
                    backgroundColor:
                        isDark ? AppTheme.goldDark : AppTheme.gold,
                    foregroundColor: const Color(0xFF1A2E28),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 8,
                    shadowColor: AppTheme.gold.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _asked ? 'Requesting permission...' : 'Allow',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onNext,
                  child: const Text('Not now — continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permTile(IconData icon, String title, String body) {
    // Demo v13 perm-card: radius 18, card surface (#FBF7EA light /
    // #0F2A22 dark), 1px card-line border, demo shadow. The old
    // version used a hard white card inside a gold gradient border.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.nightCard : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight,
        ),
        boxShadow: [AppTheme.cardShadow(isDark)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Login page: gold M mark top-right, Arabic calligraphy words slowly
/// orbiting in circles around the centre, Gmail login + Skip.
class _LoginPage extends StatefulWidget {
  final void Function(String name, String email) onFinish;
  final VoidCallback onSkip;

  const _LoginPage({required this.onFinish, required this.onSkip});

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  // Default language is English (user's choice) — the picker below
  // still offers all 8 quick languages + the full Translate list.
  String _language = 'English';

  static const _languages = [
    'English',
    'Urdu',
    'العربية',
    'Bahasa Indonesia',
    'Türkçe',
    'Français',
    'বাংলা',
    'हिन्दी',
  ];

  /// Words on the orbiting rings (inner ring, outer ring).
  static const _innerWords = ['الله', 'محمد', 'بسم الله'];
  static const _outerWords = [
    'سبحان الله',
    'الحمد لله',
    'الله أكبر',
    'لا إله إلا الله',
  ];

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
    // Slow glow pulse on the centre mark.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return PatternBackground(
      base: isDark ? AppTheme.nightBg : AppTheme.sand,
      patternColor: isDark ? AppTheme.goldDark : AppTheme.emerald,
      patternOpacity: 0.18,
      child: SafeArea(
        child: Stack(
          children: [
            // App icon, top-right (Nusuk-style).
            const Positioned(
              top: 12,
              right: 16,
              child: GoldMark(size: 52),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
              child: Column(
                children: [
                  // Orbiting calligraphy.
                  SizedBox(
                    height: 230,
                    child: AnimatedBuilder(
                      animation: _orbit,
                      builder: (context, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft gold glow behind the rings.
                            Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppTheme.gold
                                        .withValues(alpha: 0.22),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Orbit rings (gold, glowing).
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.gold
                                      .withValues(alpha: 0.55),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.gold
                                        .withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.gold
                                      .withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.gold
                                        .withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1 + 0.04 * _pulse.value,
                                  child: child,
                                );
                              },
                              child: const GoldMark(size: 84),
                            ),
                            ..._orbitWords(
                              _innerWords,
                              75,
                              _orbit.value * 2 * math.pi,
                              20,
                            ),
                            ..._orbitWords(
                              _outerWords,
                              110,
                              -_orbit.value * 2 * math.pi + 0.6,
                              16,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assalamu Alaikum',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.goldLight, AppTheme.gold],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create your profile or skip.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _languages.map((l) {
                      return ChoiceChip(
                        label: Text(l),
                        selected: _language == l,
                        onSelected: (_) =>
                            setState(() => _language = l),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Translate: full worldwide language list (searchable).
                  // Sets the language through the same `_language` state
                  // the 8 quick chips above use.
                  OutlinedButton.icon(
                    icon: const Icon(Icons.translate, size: 18),
                    label: Text(
                      _languages.contains(_language)
                          ? 'Translate'
                          : 'Translate: $_language',
                    ),
                    onPressed: () => _openTranslateSheet(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Demo login card: radius 20, card surface, 1px
                  // card-line border, demo shadow — holds the profile
                  // fields, the note and the sign-in actions.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.nightCard
                          : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.cardLineDark
                            : AppTheme.cardLineLight,
                      ),
                      boxShadow: [AppTheme.cardShadow(isDark)],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Your name',
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.chipDark
                                : AppTheme.chipLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppTheme.goldDark
                                    : AppTheme.gold,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Gmail address',
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.chipDark
                                : AppTheme.chipLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppTheme.goldDark
                                    : AppTheme.gold,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This profile is saved only on this phone. Real Google '
                          'sign-in will come after Firebase is added.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.mail, size: 18),
                            label: const Text(
                              'Sign in with Gmail',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => widget.onFinish(
                              _nameCtrl.text,
                              _emailCtrl.text,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDark ? AppTheme.goldDark : AppTheme.gold,
                              foregroundColor: const Color(0xFF1A2E28),
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              elevation: 8,
                              shadowColor:
                                  AppTheme.gold.withValues(alpha: 0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: widget.onSkip,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the full worldwide language list (searchable bottom sheet).
  /// Picking one sets the language through the same `_language` state
  /// the 8 quick chips use.
  void _openTranslateSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          isDark ? AppTheme.nightCard : AppTheme.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TranslateSheet(
        current: _language,
        onPick: (label) {
          Navigator.pop(ctx);
          setState(() => _language = label);
        },
      ),
    );
  }

  /// Words placed on a circle of [radius], moving with [angle].
  /// Only the POSITION moves — each word itself stays upright.
  List<Widget> _orbitWords(
    List<String> words,
    double radius,
    double angle,
    double fontSize,
  ) {
    // Demo orbit words: Amiri serif, gold — #8A6D1B on the light
    // sand, #F0D488 after dark.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordColor =
        isDark ? const Color(0xFFF0D488) : const Color(0xFF8A6D1B);
    final out = <Widget>[];
    for (var i = 0; i < words.length; i++) {
      final a = angle + i * 2 * math.pi / words.length;
      final dx = radius * math.cos(a);
      final dy = radius * math.sin(a);
      out.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: Text(
            words[i],
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: wordColor,
            ),
          ),
        ),
      );
    }
    return out;
  }
}

/// Searchable bottom sheet with the full worldwide language list
/// (120 languages from lib/models/languages.dart). Each row shows the
/// native name, the English name and the language code. Tapping a row
/// applies it via [onPick] (same `_language` state as the quick chips).
class _TranslateSheet extends StatefulWidget {
  final String current;
  final void Function(String label) onPick;

  const _TranslateSheet({required this.current, required this.onPick});

  @override
  State<_TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends State<_TranslateSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? allLanguages
        : allLanguages.where((l) {
            return l.code.toLowerCase().contains(q) ||
                l.english.toLowerCase().contains(q) ||
                l.native.toLowerCase().contains(q);
          }).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.cardLineDark
                  : AppTheme.cardLineLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Icon(Icons.translate, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Translate — saari zubanein',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ),
                Text(
                  '${matches.length} / ${allLanguages.length}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search language...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor:
                    isDark ? AppTheme.chipDark : AppTheme.chipLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? const Center(child: Text('No language found.'))
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, i) {
                      final lang = matches[i];
                      final label = loginLabel(lang);
                      final selected = widget.current == label;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.12),
                          child: Text(
                            lang.code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                        title: Text(
                          lang.native,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                        subtitle: Text(
                          lang.english,
                          style: TextStyle(color: muted),
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle,
                                color: accent,
                              )
                            : null,
                        onTap: () => widget.onPick(label),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
