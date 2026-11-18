import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Seekhein (Learning): Wudu ka Tareeqa (9 steps, animated human figure
/// drawn with simple shapes) + Namaz Parhne ka Tareeqa (7 positions) +
/// Namaz ke Baad ki Dua (with Tasbih-e-Fatima counters).
///
/// ACCURACY: only the verified before/after Wudu duas are shown
/// (from assets/data/duas.json, category "wudu"). Limb-specific duas
/// during Wudu are NOT authentically established, so they are NOT
/// presented as Sunnah anywhere here. Salah recitations come from
/// assets/data/salah_texts.json (verified hadith sources).
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'How to Perform Wudu'),
            Tab(text: 'How to Pray'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _WuduSteps(),
              _NamazSteps(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 9 steps of Wudu (standard practice, as taught in Fiqh).
const List<Map<String, String>> _wuduSteps = [
  {'title': '1. Intention (Niyyah)', 'body': 'Make the intention for Wudu in your heart.'},
  {
    'title': '2. Wash hands (3x)',
    'body': 'Wash both hands up to the wrists 3 times.',
  },
  {
    'title': '3. Rinse mouth (3x)',
    'body': 'Rinse the mouth with water 3 times.',
  },
  {
    'title': '4. Nose (3x)',
    'body': 'Clean the nose with water 3 times.',
  },
  {
    'title': '5. Face (3x)',
    'body': 'Wash the whole face 3 times.',
  },
  {
    'title': '6. Arms (3x)',
    'body': 'Wash both arms up to the elbows 3 times.',
  },
  {
    'title': '7. Wipe head (1x)',
    'body': 'Wipe the head with wet hands (1x).',
  },
  {
    'title': '8. Ears (1x)',
    'body': 'Wipe the ears with the fingers (1x).',
  },
  {
    'title': '9. Feet (3x)',
    'body': 'Wash both feet up to the ankles 3 times.',
  },
];

/// The 7 positions of Salah.
const List<Map<String, String>> _namazPositions = [
  {
    'title': '1. Standing (Qiyam)',
    'body': 'Stand straight, fold your hands, and recite Sana.',
  },
  {
    'title': '2. Bowing (Ruku)',
    'body': 'Bow down, hands on knees, and recite the tasbih.',
  },
  {
    'title': '3. Standing up (Qauma)',
    'body': 'Stand straight up from Ruku and recite the dua.',
  },
  {
    'title': '4. Prostration (Sujood)',
    'body': 'Prostrate — forehead, nose, hands, knees and feet on the ground.',
  },
  {
    'title': '5. Sitting between prostrations (Jalsa)',
    'body': 'Sit between the two prostrations and recite the dua.',
  },
  {
    'title': '6. Tashahhud',
    'body': 'In the last rak\'ah, sit and recite Tashahhud and Durood.',
  },
  {
    'title': '7. Salam',
    'body': 'Turn your face right, then left, to say Salam.',
  },
];

class _WuduSteps extends StatefulWidget {
  const _WuduSteps();

  @override
  State<_WuduSteps> createState() => _WuduStepsState();
}

class _WuduStepsState extends State<_WuduSteps> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final step = _wuduSteps[_step];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Animated human figure (simple, respectful illustration).
        Center(
          child: _AnimatedFigure(
            label: step['title'] ?? '',
            color: AppTheme.emerald,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          step['title'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          step['body'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _step > 0 ? () => setState(() => _step--) : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 12),
            Text('Step ${_step + 1} / ${_wuduSteps.length}'),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _step < _wuduSteps.length - 1
                  ? () => setState(() => _step++)
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionTitle(title: 'Wudu duas'),
        FutureBuilder<List<Dua>>(
          future: DataService.duas(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Could not load data — close and reopen the app.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final wuduDuas = snap.data!
                .where((d) => d.category == 'wudu')
                .toList();
            if (wuduDuas.isEmpty) {
              return const Text(
                'Wudu duas are being verified — coming soon.',
                style: TextStyle(color: Colors.grey),
              );
            }
            return Column(
              children: wuduDuas
                  .map(
                    (d) => Card(
                      child: ListTile(
                        title: Text(d.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.arabic,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 20,
                              ),
                            ),
                            Text(d.english),
                            Text(
                              d.reference,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SampleNote(
          text:
              'Note: A separate dua for each limb during Wudu is not '
              'authentically established — so only the verified duas before '
              'and after Wudu are given here.',
        ),
      ],
    );
  }
}

class _NamazSteps extends StatefulWidget {
  const _NamazSteps();

  @override
  State<_NamazSteps> createState() => _NamazStepsState();
}

class _NamazStepsState extends State<_NamazSteps> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final step = _namazPositions[_step];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: _AnimatedFigure(
            label: step['title'] ?? '',
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          step['title'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          step['body'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _step > 0 ? () => setState(() => _step--) : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 12),
            Text('Position ${_step + 1} / ${_namazPositions.length}'),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _step < _namazPositions.length - 1
                  ? () => setState(() => _step++)
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionTitle(title: 'What to recite in each position'),
        FutureBuilder<List<SalahText>>(
          future: DataService.salahTexts(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Could not load data — close and reopen the app.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.isEmpty) {
              return const Text(
                'Prayer duas are being verified — coming soon.',
                style: TextStyle(color: Colors.grey),
              );
            }
            return Column(
              children: snap.data!
                  .map(
                    (t) => Card(
                      child: ListTile(
                        title: Text(t.step),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.arabic,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 20,
                              ),
                            ),
                            if (t.englishIsTransliteration)
                              const Text(
                                'Roman transliteration:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(t.english),
                            Text(
                              t.reference,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'Dua After Prayer'),
        const _PostNamazTasbih(),
      ],
    );
  }
}

/// Tasbih-e-Fatima counters: SubhanAllah 33, Alhamdulillah 33,
/// Allahu Akbar 34 — tap to count.
class _PostNamazTasbih extends StatefulWidget {
  const _PostNamazTasbih();

  @override
  State<_PostNamazTasbih> createState() => _PostNamazTasbihState();
}

class _PostNamazTasbihState extends State<_PostNamazTasbih> {
  final _counts = [0, 0, 0];
  static const _labels = ['SubhanAllah', 'Alhamdulillah', 'Allahu Akbar'];
  static const _targets = [33, 33, 34];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Say Astaghfirullah 3x, then "Allahumma Antas-Salam...", '
          'then Ayat-ul-Kursi, then Tasbih-e-Fatima:',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < 3; i++)
          Card(
            child: ListTile(
              title: Text(_labels[i]),
              subtitle: Text('${_counts[i]} / ${_targets[i]}'),
              trailing: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (_counts[i] < _targets[i]) _counts[i]++;
                  });
                },
                child: const Text('Tap'),
              ),
            ),
          ),
        TextButton(
          onPressed: () => setState(() {
            _counts[0] = 0;
            _counts[1] = 0;
            _counts[2] = 0;
          }),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}

/// Simple animated human figure: a circle head + body that gently
/// bobs, with the current step label. (A respectful, abstract figure —
/// no face details.)
class _AnimatedFigure extends StatefulWidget {
  final String label;
  final Color color;

  const _AnimatedFigure({required this.label, required this.color});

  @override
  State<_AnimatedFigure> createState() => _AnimatedFigureState();
}

class _AnimatedFigureState extends State<_AnimatedFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _c.value),
          child: child,
        );
      },
      child: Container(
        width: 140,
        height: 180,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.gold,
              child: Icon(Icons.person, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.accessibility_new,
                size: 48, color: AppTheme.emerald),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
