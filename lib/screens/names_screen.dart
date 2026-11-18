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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final card = isDark ? AppTheme.nightCard : AppTheme.cardLight;
    final cardLine =
        isDark ? AppTheme.cardLineDark : AppTheme.cardLineLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    // Demo v13 Arabic gold: #D4AF37 in dark mode, emerald #005A45
    // on the light card.
    final arabicColor =
        isDark ? AppTheme.arabicGold : AppTheme.arabicGreen;
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search names (e.g. Rahman)...',
                      prefixIcon: Icon(Icons.search),
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
                    backgroundColor: cardLine,
                    color: gold,
                  ),
                  Text(
                    'Memorisation progress is for this session only.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 92),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // 0.85 (not 1.0): Arabic + transliteration + meaning
                  // need headroom at 1.3x elder-mode text scaling.
                  childAspectRatio: 0.85,
                ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final n = shown[i];
                  final done = _memorised.contains(n.number);
                  return Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardLine, width: 1),
                      boxShadow: [AppTheme.cardShadow(isDark)],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              10,
                              30,
                              10,
                              10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                NumberBadge(
                                  text: '${n.number}',
                                  radius: 13,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.arabic,
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 22,
                                    color: arabicColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  n.transliteration,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  n.enMeaning,
                                  textAlign: TextAlign.center,
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
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton(
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              color: done
                                  ? gold
                                  : (isDark
                                      ? AppTheme.mutedDark
                                      : AppTheme.mutedLight),
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
                      ],
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
