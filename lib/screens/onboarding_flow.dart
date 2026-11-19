import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/languages.dart';
import '../services/notification_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern.dart';

/// Nusuk-style first-launch flow (shown only until the profile is set),
/// laid out exactly like the approved demo v13:
///   1. Splash — 3D mark, MOHALLA wordmark, "Your mohalla, your mosque",
///      Bismillah, loader (no orbit — the orbit is on Permissions).
///   2. Permissions — the 8 orbiting Arabic words circle the mark;
///      Location / Notifications / Storage rows with Allow / Skip.
///   3. Login — time greeting + "Welcome to Mohalla", Google button,
///      OR, Email + Password, Continue, "English · 124 languages"
///      chip, Skip for now (profile stays local-only; real Google
///      sign-in needs Firebase — see BUILD_NOTES.md).
class OnboardingFlow extends StatefulWidget {
  /// First page to show (0 = splash). The every-launch splash reuses
  /// this flow, then the full onboarding continues at step 1.
  final int initialStep;

  /// When set, the splash (2.6s timer or tap) ends the flow through
  /// this callback instead of advancing to permissions. Used for the
  /// every-launch splash.
  final VoidCallback? onSplashDone;

  const OnboardingFlow({
    super.key,
    this.initialStep = 0,
    this.onSplashDone,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _pageCtrl;
  late int _step;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    _pageCtrl = PageController(initialPage: widget.initialStep);
    if (widget.initialStep == 0) {
      _splashTimer =
          Timer(const Duration(milliseconds: 2600), _advanceFromSplash);
    }
  }

  /// Leave the splash: either finish the every-launch splash through
  /// the callback, or advance to permissions in the full onboarding.
  void _advanceFromSplash() {
    if (!mounted) return;
    if (widget.onSplashDone != null) {
      widget.onSplashDone!();
    } else {
      _goTo(1);
    }
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
          _SplashPage(onTap: _advanceFromSplash),
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

/// App icon mark (5A 3D artwork, gold on emerald).
/// 5A is the in-app mark everywhere (splash, login, header,
/// permissions). 5B (refined-flat) is the LAUNCHER icon only — it lives
/// in the mipmap folders, not in the app's screens.
/// Shown in a ROUNDED SQUARE — never clipped to a circle. The circle
/// clip cut off the minarets/dome (the artwork nearly fills the square
/// source), so the icon looked cut on the splash, login and header.
/// The old version drew a text 'M' in a gold circle, which is why the
/// app showed a bare letter everywhere the mark is used.
class GoldMark extends StatelessWidget {
  final double size;

  /// Icon artwork to show. Defaults to the 5A 3D artwork.
  final String asset;

  const GoldMark({
    super.key,
    this.size = 120,
    this.asset = 'assets/images/mohalla_splash_icon.png',
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
          // The artwork itself is a solid square: without this inner
          // clip its sharp 90-degree corners show inside the rounded
          // frame. Slight rounding on all 4 sides (12%).
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.12),
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
  // Demo v13 splash: NO orbit here — the orbiting words live on the
  // Permissions hero in the demo. The splash is the 3D mark +
  // wordmark + tagline + Bismillah + loader.

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 56),
              // Demo v13 splash: the 3D mark on top, then the wordmark.
              // (The demo's hero badge is small; the mark stays 120 so
              // the 3D mosque reads clearly on a real phone.)
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  return Transform.scale(
                    // Gentle pulse only: the icon must not look zoomed —
                    // the full logo has to stay visible.
                    scale: 1 + 0.02 * _c.value,
                    child: child,
                  );
                },
                child: const GoldMark(
                  size: 120,
                  asset: 'assets/images/mohalla_splash_icon.png',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'MOHALLA',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  // Demo .app-name: letterspaced, pale gold (#FDF6DA).
                  color: Color(0xFFFDF6DA),
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your mohalla, your mosque',
                style: TextStyle(color: Color(0xFFE8DCB2), fontSize: 14),
              ),
              const SizedBox(height: 28),
              const Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20,
                  color: AppTheme.goldLight,
                ),
              ),
              const Spacer(),
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
              const SizedBox(height: 32),
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

/// Demo v13 Permissions: the orbiting-words hero on top, "A few
/// permissions", three rows (Location / Notifications / Storage) with
/// Allow / Skip on each, then Continue + "Skip for now".
class _PermissionsPageState extends State<_PermissionsPage>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;

  /// Per-permission state: 0 = not asked, 1 = allowed, 2 = skipped.
  /// Demo v13 shows Allow / Skip on every row and a "Skipped" label.
  int _loc = 0;
  int _notif = 0;
  int _storage = 0;

  /// The 8 demo orbit words circling the mark (demo v13 perm-hero).
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
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 46),
    )..repeat();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  /// Notifications Allow: actually request the system permission.
  /// Location / Storage Allow only records the choice — GPS permission
  /// is requested when the location is first used, and Quran downloads
  /// ask when they start.
  Future<void> _allowNotif() async {
    setState(() => _notif = 1);
    await NotificationService.requestPermissions();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Orbit hero (demo v13 perm-hero): 8 Arabic words circle
              // the 3D mark on the 46s spin.
              Center(
                child: SizedBox(
                  height: 230,
                  child: AnimatedBuilder(
                    animation: _orbit,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.gold.withValues(alpha: 0.22),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.55),
                                width: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                          ),
                          const GoldMark(size: 84),
                          ..._orbitWordsOnCircle(
                            100,
                            _orbit.value * 2 * math.pi,
                            16,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A few permissions',
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
                'Mohalla works better with these — you can change them '
                'anytime in Settings.',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 16),
              _permRow(
                Icons.my_location,
                'Location',
                'Find prayer times and mosques near you',
                _loc,
                () => setState(() => _loc = 1),
                () => setState(() => _loc = 2),
              ),
              const SizedBox(height: 10),
              _permRow(
                Icons.notifications_active,
                'Notifications',
                'Gentle reminders for prayer and Azan',
                _notif,
                _allowNotif,
                () => setState(() => _notif = 2),
              ),
              const SizedBox(height: 10),
              _permRow(
                Icons.download,
                'Storage',
                'Download the full Quran for offline reading',
                _storage,
                () => setState(() => _storage = 1),
                () => setState(() => _storage = 2),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onNext,
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
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onNext,
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One permission row: icon + title + subtitle, with Allow / Skip
  /// on the right. After a choice the row shows Allowed / Skipped.
  Widget _permRow(
    IconData icon,
    String title,
    String body,
    int state,
    VoidCallback onAllow,
    VoidCallback onSkip,
  ) {
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: ink),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(fontSize: 13, color: muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (state == 0)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniAction('Allow', true, onAllow),
                const SizedBox(height: 4),
                _miniAction('Skip', false, onSkip),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                state == 1 ? 'Allowed' : 'Skipped',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: state == 1 ? accent : muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniAction(String label, bool primary, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary
                ? gold
                : (isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: primary ? const Color(0xFF1A2E28) : muted,
          ),
        ),
      ),
    );
  }

  /// Words placed on a circle of [radius], moving with [angle].
  /// Only the POSITION moves — each word itself stays upright.
  List<Widget> _orbitWordsOnCircle(
    double radius,
    double angle,
    double fontSize,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordColor =
        isDark ? const Color(0xFFF0D488) : const Color(0xFF8A6D1B);
    final out = <Widget>[];
    for (var i = 0; i < _orbitWords.length; i++) {
      final a = angle + i * 2 * math.pi / _orbitWords.length;
      final dx = radius * math.cos(a);
      final dy = radius * math.sin(a);
      out.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: Text(
            _orbitWords[i],
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

/// Login page (demo v13): time greeting + Arabic greeting,
/// "Welcome to Mohalla", Google + email/password card, the
/// "English · 124 languages" chip, Skip for now. The password is
/// never stored or sent — the app is local-only with no backend;
/// the field exists for visual parity with the approved demo.
/// The profile name is derived from the email; it can be edited
/// later in Settings > Edit Profile.
class _LoginPage extends StatefulWidget {
  final void Function(String name, String email) onFinish;
  final VoidCallback onSkip;

  const _LoginPage({required this.onFinish, required this.onSkip});

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // Default language is English (user's choice) — the chip below
  // still opens the full Translate list (124 languages).
  String _language = 'English';

  /// "Good morning / afternoon / evening" for the demo greeting line.
  String get _dayPart {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  /// Profile name from the email (e.g. muzzamilmughal26@… ->
  /// "Muzzamilmughal"). Editable later in Settings > Edit Profile.
  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    final cleaned = local.replaceAll(RegExp(r'[^A-Za-z ]'), ' ').trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _finish() {
    widget.onFinish(_nameFromEmail(_emailCtrl.text), _emailCtrl.text);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    return PatternBackground(
      base: isDark ? AppTheme.nightBg : AppTheme.sand,
      patternColor: isDark ? AppTheme.goldDark : AppTheme.emerald,
      patternOpacity: 0.18,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              // The icon "travels" from the splash to the login
              // (demo controls) — the 3D mark sits on top here.
              const GoldMark(size: 64),
              const SizedBox(height: 16),
              Text(
                'Assalamu Alaikum · $_dayPart',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 4),
              Text(
                'السَّلَامُ عَلَيْكُمْ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to Mohalla',
                style: TextStyle(
                  fontSize: 26,
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
              const SizedBox(height: 8),
              Text(
                'Connect with your mosque — prayer times, azan and '
                'mohalla news, all in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 20),
              // Demo login card: radius 20, card surface, 1px
              // card-line border, demo shadow — Google button, OR,
              // Email + Password, Continue.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.nightCard : AppTheme.cardLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight,
                  ),
                  boxShadow: [AppTheme.cardShadow(isDark)],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finish,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1F1F1F),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'G',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Continue with Google',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'OR',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.chipDark
                            : AppTheme.chipLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: gold, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: '••••••••',
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.chipDark
                            : AppTheme.chipLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: gold, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finish,
                        style: ElevatedButton.styleFrom(
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
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.language, size: 18),
                label: Text('$_language · 124 languages'),
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
              const SizedBox(height: 10),
              Text(
                'This profile is saved only on this phone. Real Google '
                'sign-in will come after Firebase is added.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onSkip,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the full worldwide language list (searchable bottom sheet).
  /// Picking one sets the `_language` state the chip label shows.
  void _openTranslateSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppTheme.nightCard : AppTheme.cardLight,
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
