import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/data_service.dart';
import '../services/location_service.dart';
import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/pattern.dart';
import '../widgets/timings_editor.dart';

/// Home: live next-prayer countdown, Hijri date, editable masjid photo,
/// editable masjid timings (camera photo of the timings board as a
/// reference), the user's own mosque card, location chip, rotating
/// Ayat / Hadith / Dua of the day.
///
/// HOME-BLANK ROOT CAUSE (Run 7, traced for real this time): the old
/// code ran ALL prayer maths — `DateTime.now`,
/// `effectiveTimesFor`, `nextPrayerWith` — inside `build()`, on every
/// 1-second timer tick. In release mode a throw anywhere in a widget's
/// build (or in a child build the parent's try/catch cannot see)
/// replaces that whole subtree with an empty box — and the old
/// try/catch only wrapped the SYNCHRONOUS construction of the widget
/// tree, so a throw in a later child build, or in the catch-block's
/// own fallback (`DateTime.now()` again when `_lastNow`
/// was still null), left the tab blank with no error card ever
/// appearing. The fix is structural, not another try/catch: ALL prayer
/// maths now runs in `_refreshTimes()` (initState + settings/location
/// listener + once a minute), and `build()` ONLY renders already-computed
/// state. `build()` can no longer throw from prayer maths, the first
/// frame already has data (computed synchronously in initState), and
/// when there is genuinely no data the screen shows a VISIBLE loading
/// card, a VISIBLE error card, or a VISIBLE location-required card
/// with a button — never a blank tab.
class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenLocation;
  final VoidCallback onOpenQibla;
  final void Function(int surah, int ayah) onOpenAyah;

  /// Open a Zyada tool ('mushaf', 'tracker', ...).
  final void Function(String key) onOpenTool;

  /// Switch to a bottom tab (0 Home, 1 Quran, ...).
  final void Function(int index) onOpenTab;

  const HomeScreen({
    super.key,
    required this.onOpenLocation,
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
  DateTime? _now;
  Map<String, DateTime>? _times;
  MapEntry<String, DateTime>? _next;
  int? _lastMinute;
  String? _timesError;

  /// True when there is no GPS location yet — Home shows the
  /// location-required card instead of prayer data.
  bool _noLocation = false;

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
    // Recompute when the location / method / masjid timings change.
    context.read<SettingsProvider>().addListener(_onSettingsChanged);
    context.read<LocationService>().addListener(_onLocationChanged);
    // Tick the countdown clock every second; prayer data itself is
    // only recomputed when the minute changes (cheap) or missing.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _onSettingsChanged() {
    // A Hijri adjustment change must refresh the header date too.
    _updateHijri();
    _refreshTimes();
  }

  void _onLocationChanged() => _refreshTimes();

  void _tick() {
    if (!mounted) return;
    // No GPS yet — nothing on screen ticks; the location listener
    // refreshes the moment a fix arrives.
    if (_noLocation) return;
    try {
      final now = DateTime.now();
      // Past midnight with the app still open: the Hijri and
      // Gregorian header dates must roll over too (they are only
      // computed in _updateHijri, not in _refreshTimes).
      if (_now != null &&
          (now.day != _now!.day ||
              now.month != _now!.month ||
              now.year != _now!.year)) {
        _updateHijri();
      }
      if (_times == null || now.minute != _lastMinute) {
        _refreshTimes(now: now);
      } else {
        // Only the countdown digits changed — rebuild for the clock.
        setState(() => _now = now);
      }
    } catch (_) {
      // The 1s tick must never take Home down: keep last-good data
      // on screen.
    }
  }

  /// Compute prayer data into state. Never throws out of here: a
  /// failure keeps the last-good values and records the error, so the
  /// screen shows stale data + a warning strip instead of blank.
  /// With no GPS location yet, clears the prayer data so the
  /// location-required card shows instead.
  void _refreshTimes({DateTime? now, bool notify = true}) {
    final settings = context.read<SettingsProvider>();
    final coords = context.read<LocationService>().current;
    if (coords == null) {
      _now = null;
      _times = null;
      _next = null;
      _timesError = null;
      _noLocation = true;
      if (notify && mounted) setState(() {});
      return;
    }
    try {
      final n = now ?? DateTime.now();
      final t = PrayerService.effectiveTimesFor(
        coords.latitude,
        coords.longitude,
        DateTime(n.year, n.month, n.day),
        method: settings.calculationMethod,
        madhab: settings.madhab,
        custom: settings.masjidTimings,
      );
      final nx = PrayerService.nextPrayerWith(
        coords.latitude,
        coords.longitude,
        n,
        method: settings.calculationMethod,
        madhab: settings.madhab,
        custom: settings.masjidTimings,
      );
      _now = n;
      _times = t;
      _next = nx;
      _lastMinute = n.minute;
      _timesError = null;
      _noLocation = false;
    } catch (e) {
      _timesError = e.toString();
    }
    if (notify && mounted) setState(() {});
  }

  void _updateHijri() {
    try {
      // The Hijri date is shifted by the user's Settings adjustment
      // (-1 / 0 / +1 day): the shift is applied to the Gregorian date
      // before conversion, so the Hijri date moves by the same days.
      final shift = context.read<SettingsProvider>().hijriAdjustment;
      final h = HijriCalendar.fromDate(
        DateTime.now().add(Duration(days: shift)),
      );
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
    context.read<LocationService>().removeListener(_onLocationChanged);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 44,
                  color: isDark ? AppTheme.goldDark : AppTheme.emerald,
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
                  style: TextStyle(fontSize: 12, color: muted),
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
                    _noLocation = false;
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
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

  /// Visible location-required state (never a blank screen) when
  /// there is no GPS location yet.
  Widget _buildLocationView(BuildContext context) {
    final location = context.read<LocationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Icon(
                  Icons.location_off,
                  size: 44,
                  color: isDark ? AppTheme.goldDark : AppTheme.emerald,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Location is needed for prayer times',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  location.message.isNotEmpty
                      ? location.message
                      : 'Allow location permission so the app can work out prayer times, Qibla and nearby mosques from where you are.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Denied forever: asking again shows nothing —
                    // the only fix is the phone's Settings page.
                    if (location.status ==
                        LocationStatus.permissionDeniedForever)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Open Settings'),
                        onPressed: () => location.openSettings(),
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Enable location'),
                        onPressed: () => location.refresh(),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: widget.onOpenLocation,
                      child: const Text('My Location'),
                    ),
                  ],
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
    final location = context.watch<LocationService>();
    // No GPS location yet: show a visible state, never a blank tab.
    if (_noLocation) {
      return _buildLocationView(context);
    }
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
    final coords = location.current;
    // The user's own masjid times (if set in Settings / here) override
    // the calculated times — countdown, table and Azan all follow them.
    final remaining = next.value.difference(now);
    final isFriday = now.weekday == DateTime.friday;
    // Demo v13 tokens: every colour below has a light AND a dark value.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        // Demo home-head: greeting 13px at .85 opacity, name 16px
        // bold. Home shows ONLY "Assalamu Alaikum," — NO time-of-day
        // greeting here (time greeting is Login-only).
        Text(
          'Assalamu Alaikum,',
          style: TextStyle(
            fontSize: 13,
            color: muted.withValues(alpha: 0.85),
          ),
        ),
        if (settings.profileName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              settings.profileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
          ),
        const SizedBox(height: 12),
        // Shown when the prayer maths failed but last-good data is
        // on screen — the user sees WHY instead of a silent blank.
        if (_timesError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF3A2F10)
                  : Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gold.withValues(alpha: 0.6)),
            ),
            child: Text(
              'Prayer timings could not be recalculated — showing old '
              'timings. Check the mosque timings in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ink),
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
                backgroundColor: isDark ? AppTheme.goldDark : AppTheme.gold,
                foregroundColor: const Color(0xFF1A2E28),
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
          onTap: widget.onOpenLocation,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: accent,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _gregorianToday,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- Location chip (full width, demo pill: radius 999,
        // 1.5px card-line border, chip surface) ----
        InkWell(
          onTap: widget.onOpenLocation,
          borderRadius: BorderRadius.circular(999),
          child: Chip(
            avatar: Icon(Icons.my_location, size: 16, color: accent),
            label: Text(
              coords == null
                  ? 'Locating...'
                  : coords.fromCache
                      ? '${coords.displayName} • last known location'
                      : coords.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            backgroundColor:
                isDark ? AppTheme.chipDark : AppTheme.chipLight,
            side: BorderSide(
              color: isDark
                  ? AppTheme.cardLineDark
                  : AppTheme.cardLineLight,
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
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
            boxShadow: [AppTheme.cardShadow(isDark)],
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
                    // Demo .sec-title: 13px bold, uppercase, gold,
                    // letter-spacing 1.1.
                    Text(
                      "Today's prayer times".toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.1,
                        color: gold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Edit timings',
                          icon: Icon(Icons.edit, size: 20, color: muted),
                          onPressed: () => showMasjidTimingsEditor(context),
                        ),
                        IconButton(
                          tooltip: 'Azan notification',
                          icon: Icon(
                            Icons.notifications_active,
                            size: 20,
                            color: settings.notify['fajr'] == true
                                ? accent
                                : muted,
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
                Text(
                  'Calculated on-device (${settings.calculationMethodLabel} method, '
                  '${settings.madhabLabel} Asr). '
                  'If you edit your mosque\'s congregation timings, those are shown.',
                  style: TextStyle(fontSize: 11, color: muted),
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

        // ---- The user's own mosque ----
        // Shown only after the user sets their own mosque name.
        // Times below are the effective times (own mosque timings
        // when set, otherwise the calculated times) + Qibla from GPS.
        if (settings.masjidName.isNotEmpty)
          Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.masjidName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  settings.masjidTimings.isNotEmpty
                      ? 'Your mosque timings (set by you in Settings).'
                      : 'Calculated timings for your location — set your mosque\'s congregation timings in Settings to show them here.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 8),
                _masjidRow('Fajr', PrayerService.formatTime(times['fajr']!)),
                _masjidRow('Dhuhr', PrayerService.formatTime(times['dhuhr']!)),
                _masjidRow('Asr', PrayerService.formatTime(times['asr']!)),
                _masjidRow('Maghrib', PrayerService.formatTime(times['maghrib']!)),
                _masjidRow('Isha', PrayerService.formatTime(times['isha']!)),
                _masjidRow(
                  'Qibla',
                  coords == null
                      ? '—'
                      : '${PrayerService.qiblaBearing(coords.latitude, coords.longitude).toStringAsFixed(0)}°',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View on Maps'),
                      onPressed: () async {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${settings.masjidName} ${coords?.displayName ?? ''}')}',
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
        const _HomeSectionTitle(title: "Today's Deen"),
        _DailyCards(
          onOpenAyah: widget.onOpenAyah,
          onOpenTool: widget.onOpenTool,
        ),
      ],
    );
  }

  Widget _timeRow(
    String key,
    DateTime? time,
    String? manual,
    bool isNext,
  ) {
    // [time] already includes the user's own masjid time when set
    // (effectiveTimesFor) — [manual] only decides the "Jamaat" badge.
    // A missing time can never crash the row (Run 7: no `!` here).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display =
        time == null ? '--:--' : PrayerService.formatTime(time);
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
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                'Congregation',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.goldDark : AppTheme.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _masjidRow(String label, String value) {
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

/// Demo `.sec-title`: 13px bold, uppercase, gold, letter-spacing 1.1,
/// 16px top / 8px bottom margin. (common.dart's SectionTitle is the
/// 20px screen-title style — not this one.)
class _HomeSectionTitle extends StatelessWidget {
  final String title;

  const _HomeSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: isDark ? AppTheme.goldDark : AppTheme.gold,
        ),
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
    // Demo v13: emerald icon tile by day, gold icon tile after dark
    // (dark emerald is unreadable on the dark card).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    return Expanded(
      child: PressableCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
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
  final void Function(String key) onOpenTool;

  const _DailyCards({required this.onOpenAyah, required this.onOpenTool});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
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
                  Text(
                    'Could not open the Dua and Hadith data.',
                    style: TextStyle(fontSize: 12, color: muted),
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
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                          style: TextStyle(fontSize: 12, color: muted),
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
                onTap: () => widget.onOpenTool('duas'),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: accent,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
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
                onTap: () => widget.onOpenTool('hadith'),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.book,
                        color: accent,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
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
