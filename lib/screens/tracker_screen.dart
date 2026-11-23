import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Prayer Tracker + Tasbih.
/// Tracker: mark each of the 5 prayers done (Jamaat / alone / missed),
/// saved per-day on the phone. Tasbih: tap counter with presets
/// (33 / 99 / 100 / 500 / 1000) and a reset.
class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  Map<String, String> _today = {}; // prayer -> jamaat | alone | missed
  int _tasbihCount = 0;
  int _tasbihTarget = 33;
  String _tasbihDhikr = 'SubhanAllah';
  // Demo v13 Tasbih: today's counts per dhikr (for the daily goal
  // and the history list), saved per-day on the phone.
  Map<String, int> _tasbihToday = {};

  static const _tasbihDhikrs = [
    'SubhanAllah',
    'Alhamdulillah',
    'Allahu Akbar',
    'La ilaha illallah',
    'Astaghfirullah',
  ];

  /// Today's total Tasbih counts across all dhikrs (daily goal: 300).
  int get _tasbihTodayTotal =>
      _tasbihToday.values.fold(0, (sum, c) => sum + c);

  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _prayerNames = {
    'fajr': 'Fajr',
    'dhuhr': 'Dhuhr',
    'asr': 'Asr',
    'maghrib': 'Maghrib',
    'isha': 'Isha',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _todayKey {
    final n = DateTime.now();
    return 'tracker_${n.year}-${n.month}-${n.day}';
  }

  String get _tasbihKey {
    final n = DateTime.now();
    return 'tasbih_${n.year}-${n.month}-${n.day}';
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final k in _prayers) {
      final v = p.getString('$_todayKey-$k');
      if (v != null) map[k] = v;
    }
    final tasbih = <String, int>{};
    for (final d in _tasbihDhikrs) {
      tasbih[d] = p.getInt('$_tasbihKey-$d') ?? 0;
    }
    if (mounted) {
      setState(() {
        _today = map;
        _tasbihToday = tasbih;
      });
    }
  }

  /// One tap: the session count AND today's saved count for this dhikr.
  Future<void> _tapTasbih() async {
    final p = await SharedPreferences.getInstance();
    final next = (_tasbihToday[_tasbihDhikr] ?? 0) + 1;
    await p.setInt('$_tasbihKey-$_tasbihDhikr', next);
    setState(() {
      _tasbihCount++;
      _tasbihToday[_tasbihDhikr] = next;
    });
  }

  /// Demo "Next dhikr ›": cycle to the next dhikr and restart the count.
  void _nextDhikr() {
    final i = _tasbihDhikrs.indexOf(_tasbihDhikr);
    setState(() {
      _tasbihDhikr = _tasbihDhikrs[(i + 1) % _tasbihDhikrs.length];
      _tasbihCount = 0;
    });
  }

  Future<void> _set(String prayer, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('$_todayKey-$prayer', value);
    setState(() => _today[prayer] = value);
  }

  @override
  Widget build(BuildContext context) {
    final done = _today.values.where((v) => v != 'missed').length;
    // Demo tokens, both modes (visual only — tracking logic untouched).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final chipBg = isDark ? AppTheme.chipDark : AppTheme.chipLight;
    final arabic =
        isDark ? AppTheme.arabicGold : AppTheme.arabicGreen;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        const SectionTitle(
          title: 'Prayer Tracker',
          subtitle: "Mark today's prayers — saved on this phone.",
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Text(
                  'Today: $done / 5 prayers done',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: done / 5,
                  color: gold,
                  backgroundColor: chipBg,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
          ),
        ),
        for (final p in _prayers)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _prayerNames[p]!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Wrap (not a single Row): the three chips + label used to
                  // overflow on narrow phones in elder (large-text) mode.
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final opt in const ['jamaat', 'alone', 'missed'])
                        ChoiceChip(
                          label: Text(
                            opt == 'jamaat'
                                ? 'Congregation'
                                : opt == 'alone'
                                    ? 'Alone'
                                    : 'Missed',
                            style: TextStyle(fontSize: 11, color: ink),
                          ),
                          selected: _today[p] == opt,
                          onSelected: (_) => _set(p, opt),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const SectionTitle(title: 'Tasbih'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButton<String>(
                  value: _tasbihDhikr,
                  dropdownColor:
                      isDark ? AppTheme.nightCard : AppTheme.cardLight,
                  iconEnabledColor: gold,
                  style: TextStyle(color: ink, fontSize: 14),
                  items: const [
                    'SubhanAllah',
                    'Alhamdulillah',
                    'Allahu Akbar',
                    'La ilaha illallah',
                    'Astaghfirullah',
                  ].map((d) {
                    return DropdownMenuItem(value: d, child: Text(d));
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _tasbihDhikr = v!;
                    _tasbihCount = 0;
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_tasbihCount / $_tasbihTarget',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                Text(
                  _tasbihDhikr,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 22,
                    color: arabic,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [33, 99, 100, 500, 1000].map((t) {
                    return ChoiceChip(
                      label: Text('$t', style: TextStyle(color: ink)),
                      selected: _tasbihTarget == t,
                      onSelected: (_) => setState(() {
                        _tasbihTarget = t;
                        _tasbihCount = 0;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: isDark
                              ? AppTheme.emeraldLight
                              : AppTheme.emerald,
                          foregroundColor: const Color(0xFFF7F1E3),
                        ),
                        onPressed: _tapTasbih,
                        child: const Text(
                          'TAP',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => setState(() => _tasbihCount = 0),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                if (_tasbihCount >= _tasbihTarget)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'MashaAllah — target reached! ✓',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.goldDarkLight
                            : AppTheme.emerald,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Demo v13 Tasbih: daily goal (300) + today's history.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily goal · 300 counts',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$_tasbihTodayTotal of 300 done today',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (_tasbihTodayTotal / 300).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        isDark ? AppTheme.chipDark : AppTheme.chipLight,
                    valueColor: AlwaysStoppedAnimation<Color>(gold),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's history",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: _nextDhikr,
                      child: const Text('Next dhikr ›'),
                    ),
                  ],
                ),
                ..._tasbihDhikrs.map((d) {
                  final c = _tasbihToday[d] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(d)),
                        Text(
                          c >= 33
                              ? '$c ✓'
                              : c > 0
                                  ? '$c · in progress'
                                  : '—',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: c >= 33 ? gold : muted,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
