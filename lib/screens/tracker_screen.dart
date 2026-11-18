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
    return ListView(
      padding: const EdgeInsets.all(16),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: done / 5,
                  color: AppTheme.gold,
                  backgroundColor: Colors.grey.shade300,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                            style: const TextStyle(fontSize: 11),
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
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _tasbihDhikr,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [33, 99, 100, 500, 1000].map((t) {
                    return ChoiceChip(
                      label: Text('$t'),
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
                          backgroundColor: AppTheme.emerald,
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
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'MashaAllah — target reached! ✓',
                      style: TextStyle(
                        color: AppTheme.emerald,
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
