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

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final k in _prayers) {
      final v = p.getString('$_todayKey-$k');
      if (v != null) map[k] = v;
    }
    if (mounted) setState(() => _today = map);
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
                        onPressed: () => setState(() => _tasbihCount++),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
