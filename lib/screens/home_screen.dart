import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../services/data_service.dart';
import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/pattern.dart';
import '../widgets/timings_editor.dart';

/// Home: live next-prayer countdown, Hijri date, editable masjid photo,
/// editable masjid timings (camera photo of the timings board as a
/// reference), Jamia Masjid Khizra card, timezone chip, rotating
/// Ayat / Hadith / Dua of the day.
///
/// HOME-BLANK ROOT CAUSE (Run 7, traced for real this time): the old
/// code ran ALL prayer maths — `PrayerService.nowIn`,
/// `effectiveTimesFor`, `nextPrayerWith` — inside `build()`, on every
/// 1-second timer tick. In release mode a throw anywhere in a widget's
/// build (or in a child build the parent's try/catch cannot see)
/// replaces that whole subtree with an empty box — and the old
/// try/catch only wrapped the SYNCHRONOUS construction of the widget
/// tree, so a throw in a later child build, or in the catch-block's
/// own fallback (`PrayerService.nowIn(city)` again when `_lastNow`
/// was still null), left the tab blank with no error card ever
/// appearing. The fix is structural, not another try/catch: ALL prayer
/// maths now runs in `_refreshTimes()` (initState + settings listener
/// + once a minute), and `build()` ONLY renders already-computed
/// state. `build()` can no longer throw from prayer maths, the first
/// frame already has data (computed synchronously in initState), and
/// when there is genuinely no data the screen shows a VISIBLE loading
/// card or a VISIBLE error card with retry — never a blank tab.
class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenTimezones;
  final VoidCallback onOpenQibla;
  final void Function(int surah, int ayah) onOpenAyah;

  /// Open a Zyada tool ('mushaf', 'tracker', ...).
  final void Function(String key) onOpenTool;

  /// Switch to a bottom tab (0 Home, 1 Quran, ...).
  final void Function(int index) onOpenTab;

  const HomeScreen({
    super.key,
    required this.onOpenTimezones,
    required this.onOpenQibla,
    required this.onOpenAyah,
    required this.onOpenTool,
    required this.onOpenTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  String _hijriToday = '';
  String _gregorianToday = '';

  // Prayer data, computed OUTSIDE build() (see class doc). build()
  // only reads these fields, so it can never throw from prayer maths.
  // Last-good values stay on screen when a recompute fails.
  tz.TZDateTime? _now;
  Map<String, tz.TZDateTime>? _times;
  MapEntry<String, tz.TZDateTime>? _next;
  int? _lastMinute;
  String? _timesError;

  static const _hijriMonths = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    'Shaban',
    'Ramadan',
    'Shawwal',
    'Dhul Qadah',
    'Dhul Hijjah',
  ];

  @override
  void initState() {
    super.initState();
    _updateHijri();
    // First frame already has prayer data: computed synchronously
    // here, before build() ever runs.
    _refreshTimes(notify: false);
    // Recompute when the city / masjid timings / toggles change.
    context.read<SettingsProvider>().addListener(_onSettingsChanged);
    // Tick the countdown clock every second; prayer data itself is
    // only recomputed when the minute changes (cheap) or missing.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _onSettingsChanged() => _refreshTimes();

  void _tick() {
    if (!mounted) return;
    try {
      final now =
          PrayerService.nowIn(context.read<SettingsProvider>().city);
      if (_times == null || now.minute != _lastMinute) {
        _refreshTimes(now: now);
      } else {
        // Only the countdown digits changed — rebuild for the clock.
        setState(() => _now = now);
      }
    } catch (_) {
      // nowIn cannot throw (Karachi fallback), but the 1s tick must
      // never take Home down: keep last-good data on screen.
    }
  }

  /// Compute prayer data into state. Never throws out of here: a
  /// failure keeps the last-good values and records the error, so the
  /// screen shows stale data + a warning strip instead of blank.
  void _refreshTimes({tz.TZDateTime? now, bool notify = true}) {
    final settings = context.read<SettingsProvider>();
    final city = settings.city;
    try {
      final n = now ?? PrayerService.nowIn(city);
      final t = PrayerService.effectiveTimesFor(
        city,
        DateTime(n.year, n.month, n.day),
        settings.masjidTimings,
      );
      final nx = PrayerService.nextPrayerWith(
        city,
        n,
        settings.masjidTimings,
      );
      _now = n;
      _times = t;
      _next = nx;
      _lastMinute = n.minute;
      _timesError = null;
    } catch (e) {
      _timesError = e.toString();
    }
    if (notify && mounted) setState(() {});
  }

  void _updateHijri() {
    try {
      final h = HijriCalendar.now();
      _hijriToday =
          '${h.hDay} ${_hijriMonths[h.hMonth - 1]} ${h.hYear} AH';
    } catch (_) {
      _hijriToday = '';
    }
    try {
      _gregorianToday =
          DateFormat('EEEE, d MMMM y').format(DateTime.now());
    } catch (_) {
      _gregorianToday = '';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    context.read<SettingsProvider>().removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _pickMasjidPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
    );
    if (file == null || !mounted) return;
    context.read<SettingsProvider>().setMasjidPhoto(file.path);
  }

  void _showPhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose a photo from the gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickMasjidPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo with the camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickMasjidPhoto(ImageSource.camera);
              },
            ),
            if (context.read<SettingsProvider>().masjidPhotoPath != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<SettingsProvider>().setMasjidPhoto(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Belt and braces: a throw anywhere in Home must NEVER produce a
    // blank tab. Show a visible error card with retry instead.
    // (After the Run 7 restructure, build() only renders state, so
    // this should never trigger — it stays as a safety net.)
    try {
      return _buildHome(context);
    } catch (e) {
      return _buildErrorView(context, e.toString());
    }
  }

  /// Visible error state (never a blank screen) with a retry button.
  Widget _buildErrorView(BuildContext context, String message) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 44,
                  color: AppTheme.emerald,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Home could not load',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                  onPressed: () {
                    _times = null;
                    _next = null;
                    _now = null;
                    _timesError = null;
                    _refreshTimes();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Visible loading state (never a blank screen) while prayer data
  /// is being computed for the very first time.
  Widget _buildLoadingView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Loading prayer timings...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHome(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final city = settings.city;
    // No data yet: show a visible state, never a blank tab. (The
    // first frame normally already has data — see initState.)
    if (_times == null || _next == null || _now == null) {
      if (_timesError != null) {
        return _buildErrorView(context, _timesError!);
      }
      return _buildLoadingView();
    }
    final times = _times!;
    final next = _next!;
    final now = _now!;
    // The user's own masjid times (if set in Settings / here) override
    // the calculated times — countdown, table and Azan all follow them.
    final remaining = next.value.difference(now);
    final isFriday = now.weekday == DateTime.friday;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Shown when the prayer maths failed but last-good data is
        // on screen — the user sees WHY instead of a silent blank.
        if (_timesError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber),
            ),
            child: const Text(
              'Prayer timings could not be recalculated — showing old '
              'timings. Check the city or mosque timings in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        // ---- Masjid photo header (editable) ----
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 190,
                width: double.infinity,
                color: AppTheme.emeraldDark,
                child: settings.masjidPhotoPath != null
                    ? Image.file(
                        File(settings.masjidPhotoPath!),
                        fit: BoxFit.cover,
                        // A moved/deleted photo file must fall back to
                        // the placeholder, never break the header.
                        errorBuilder: (context, error, stackTrace) =>
                            const _MasjidPlaceholder(),
                      )
                    : const _MasjidPlaceholder(),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: FloatingActionButton.small(
                heroTag: 'masjid_photo',
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.ink,
                onPressed: _showPhotoSheet,
                child: const Icon(Icons.camera_alt),
              ),
            ),
            if (settings.masjidName.isNotEmpty)
              Positioned(
                left: 14,
                bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  settings.masjidName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---- Hijri date, prominent ----
        PressableCard(
          gradientBorder: true,
          onTap: widget.onOpenTimezones,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hijriToday.isEmpty ? 'Hijri date' : _hijriToday,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _gregorianToday,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- Timezone chip (full width) ----
        InkWell(
          onTap: widget.onOpenTimezones,
          child: Chip(
            avatar: const Icon(Icons.public, size: 16),
            label: Text(
              '${city.name} • ${city.timeZone}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- Next prayer countdown (3D glass card, pattern + gold) ----
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.goldLight, AppTheme.gold, AppTheme.emerald],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PatternBackground(
              base: AppTheme.emerald,
              patternColor: Colors.white,
              patternOpacity: 0.30,
              scrimAlpha: 0.35,
              glowColor: AppTheme.gold,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      isFriday && next.key == 'dhuhr'
                          ? 'Next prayer: Jumu\'ah'
                          // ?? '' guard: a missing name must show blank,
                          // never the literal word "null".
                          : 'Next prayer: ${PrayerService.prayerNamesEnglish[next.key] ?? ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // FittedBox: the countdown can never overflow its card,
                    // even at 1.3x elder-mode text scaling.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        PrayerService.formatCountdown(remaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Time: ${PrayerService.formatTime(next.value)}'
                      '${settings.masjidTimings.isNotEmpty ? ' • My mosque timings' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.goldLight),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- Quick-access shortcuts (existing features only) ----
        Row(
          children: [
            _Shortcut(
              icon: Icons.menu_book,
              label: 'Quran',
              onTap: () => widget.onOpenTab(1),
            ),
            const SizedBox(width: 8),
            _Shortcut(
              icon: Icons.auto_stories,
              label: 'Mushaf',
              onTap: () => widget.onOpenTool('mushaf'),
            ),
            const SizedBox(width: 8),
            _Shortcut(
              icon: Icons.fingerprint,
              label: 'Tasbih',
              onTap: () => widget.onOpenTool('tracker'),
            ),
            const SizedBox(width: 8),
            _Shortcut(
              icon: Icons.explore,
              label: 'Qibla',
              onTap: widget.onOpenQibla,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---- Prayer times table ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's prayer times",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Edit timings',
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => showMasjidTimingsEditor(context),
                        ),
                        IconButton(
                          tooltip: 'Azan notification',
                          icon: Icon(
                            Icons.notifications_active,
                            size: 20,
                            color: settings.notify['fajr'] == true
                                ? AppTheme.emerald
                                : Colors.grey,
                          ),
                          onPressed: () {
                            final on = settings.notify['fajr'] == true;
                            for (final k in settings.notify.keys) {
                              settings.setNotify(k, !on);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const Text(
                  'Calculated on-device (Karachi method, Hanafi Asr). '
                  'If you edit your mosque\'s congregation timings, those are shown.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                for (final key in [
                  'fajr',
                  'sunrise',
                  'dhuhr',
                  'asr',
                  'maghrib',
                  'isha',
                ])
                  _timeRow(
                    key,
                    times[key],
                    settings.masjidTimings[key],
                    key == next.key,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- Jamia Masjid Khizra (real listing, unverified) ----
        // Shown only after the user sets their own mosque name.
        if (settings.masjidName.isNotEmpty)
          Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jamia Masjid Khizra — Hyderabad',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Azan times from the jamaat360.com listing (NOT the mosque\'s '
                  'verified congregation times — "Awaiting Verification").',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _khizraRow('Fajr', '05:21 AM'),
                _khizraRow('Dhuhr', '12:11 PM'),
                _khizraRow('Asr', '04:04 PM'),
                _khizraRow('Maghrib', '05:40 PM'),
                _khizraRow('Isha', '06:59 PM'),
                _khizraRow('Qibla', '267° (West)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View on Maps'),
                      onPressed: () async {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=Jamia+Masjid+Khizra+Hyderabad+Sindh',
                        );
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.explore, size: 16),
                      label: const Text('View Qibla'),
                      onPressed: widget.onOpenQibla,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- Daily rotation cards ----
        const SectionTitle(title: "Today's Deen"),
        _DailyCards(onOpenAyah: widget.onOpenAyah),
      ],
    );
  }

  Widget _timeRow(
    String key,
    dynamic time,
    String? manual,
    bool isNext,
  ) {
    // [time] already includes the user's own masjid time when set
    // (effectiveTimesFor) — [manual] only decides the "Jamaat" badge.
    // A missing time can never crash the row (Run 7: no `!` here).
    final display =
        time == null ? '--:--' : PrayerService.formatTime(time as dynamic);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      decoration: isNext
          ? BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${PrayerService.prayerNamesEnglish[key]}'
              '${isNext ? '  •  next' : ''}',
              style: TextStyle(
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            display,
            style: TextStyle(
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (manual != null)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text(
                'Congregation',
                style: TextStyle(fontSize: 10, color: AppTheme.gold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _khizraRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// One quick-access shortcut tile on Home (existing features only).
class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.emerald, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Masjid header placeholder (no photo yet, or the saved photo file
/// is gone). Used by the header and by Image.file's errorBuilder.
class _MasjidPlaceholder extends StatelessWidget {
  const _MasjidPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mosque, size: 56, color: AppTheme.goldLight),
        SizedBox(height: 8),
        Text(
          'Add your mosque\'s photo',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Tap the photo button below',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Rotating daily cards: Ayat, Hadith, Dua — chosen by day-of-year so
/// they change every day. The data future is loaded ONCE (not on every
/// Home rebuild — the countdown ticks every second).
class _DailyCards extends StatefulWidget {
  final void Function(int surah, int ayah) onOpenAyah;

  const _DailyCards({required this.onOpenAyah});

  @override
  State<_DailyCards> createState() => _DailyCardsState();
}

class _DailyCardsState extends State<_DailyCards> {
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // Re-created on retry so a failed load is not cached forever.
    _future = Future.wait([
      DataService.duas(),
      DataService.hadiths(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snap) {
        // An error used to look exactly like "still loading" forever
        // (snap.hasData was false in both cases) — the bottom of Home
        // could sit empty with no explanation. Show the error + retry.
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Deen could not load",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Could not open the Dua and Hadith data.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Try again'),
                    onPressed: () => setState(_load),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          // VISIBLE loading state (spinner + text), never a silent gap.
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text("Loading today's Deen..."),
                ],
              ),
            ),
          );
        }
        final duas = snap.data![0] as List<dynamic>;
        final hadiths = snap.data![1] as List<dynamic>;
        final dua = duas.isEmpty ? null : duas[day % duas.length];
        final hadith =
            hadiths.isEmpty ? null : hadiths[day % hadiths.length];
        return Column(
          children: [
            PressableCard(
              gradientBorder: true,
              onTap: () => widget.onOpenAyah(2, 255),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      color: AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Verse",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ayat-ul-Kursi — Surah Al-Baqarah 2:255. '
                          'It is virtuous to recite it after prayer.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (dua != null)
              PressableCard(
                onTap: () {},
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Dua",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dua.title} — ${dua.reference}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (dua != null) const SizedBox(height: 8),
            if (hadith != null)
              PressableCard(
                onTap: () {},
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.book,
                        color: AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Hadith",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${hadith.book} ${hadith.number} — ${hadith.topic}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
