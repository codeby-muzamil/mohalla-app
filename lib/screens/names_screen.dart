import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Asma-ul-Husna: Allah ke 99 Naam — Arabic, transliteration,
/// English meaning (AlAdhan API se verified). Search + "Yaad kar liya"
/// memorisation marking (session + persisted count via SharedPreferences
/// is handled by the parent through a simple in-memory set here;
/// progress resets per session and is labelled as such).
class NamesScreen extends StatefulWidget {
  const NamesScreen({super.key});

  @override
  State<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends State<NamesScreen> {
  String _query = '';
  bool _onlyMemorised = false;
  final Set<int> _memorised = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AsmaName>>(
      future: DataService.asma(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load data — close and reopen the app.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final shown = all.where((n) {
          if (_onlyMemorised && !_memorised.contains(n.number)) {
            return false;
          }
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return n.transliteration.toLowerCase().contains(q) ||
              n.enMeaning.toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search names (e.g. Rahman)...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 8),
                  // Wrap (not Row + Spacer): the long FilterChip label
                  // used to squeeze the counter on narrow phones at
                  // 1.3x elder text.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Memorised: ${_memorised.length} / 99',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      FilterChip(
                        label: const Text('Memorised only'),
                        selected: _onlyMemorised,
                        onSelected: (v) =>
                            setState(() => _onlyMemorised = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _memorised.length / 99,
                    backgroundColor: Colors.grey.shade300,
                    color: AppTheme.gold,
                  ),
                  const Text(
                    'Memorisation progress is for this session only.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final n = shown[i];
                  final done = _memorised.contains(n.number);
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: NumberBadge(text: '${n.number}'),
                      title: Text(
                        n.arabic,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 24,
                        ),
                      ),
                      subtitle: Text(
                        '${n.transliteration} — ${n.enMeaning}',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          done
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: done ? AppTheme.emerald : Colors.grey,
                        ),
                        tooltip: 'Mark as memorised',
                        onPressed: () {
                          setState(() {
                            if (done) {
                              _memorised.remove(n.number);
                            } else {
                              _memorised.add(n.number);
                            }
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
