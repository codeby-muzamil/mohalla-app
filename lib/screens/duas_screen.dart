import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';

/// Duas & Azkar: verified duas in 8 categories (plus Wudu), plus
/// Manzil (protection verses), Durood (salawat) and Morning & Evening
/// Azkar — each with Arabic + English, source reference, and a
/// tap-to-count repeat counter. Counts are session-only.
class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  String _query = '';
  String _category = 'all';
  String _azkarTime = 'all'; // Morning/Evening sub-filter, azkar only
  final Map<String, int> _counts = {};

  late final Future<List<Dua>> _allFuture = _loadAll();

  static Future<List<Dua>> _loadAll() async {
    final lists = await Future.wait([
      DataService.duas(),
      DataService.manzil(),
      DataService.durood(),
      DataService.morningEveningAzkar(),
    ]);
    return lists.expand((l) => l).toList();
  }

  static const Map<String, String> _categories = {
    'all': 'All',
    'morning-evening': 'Morning & Evening',
    'waking': 'On Waking',
    'sleeping': 'Before Sleep',
    'eating': 'Before/After Eating',
    'home': 'Leaving/Entering Home',
    'mosque': 'Entering the Mosque',
    'travel': 'Travel',
    'difficulty': 'Hard Times',
    'wudu': 'Wudu',
    'manzil': 'Manzil',
    'durood': 'Durood',
    'azkar': 'Morning & Evening Azkar',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Dua>>(
      future: _allFuture,
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
        final shown = all.where((d) {
          if (_category != 'all' && d.category != _category) return false;
          if (_category == 'azkar' &&
              _azkarTime != 'all' &&
              d.time != _azkarTime) {
            return false;
          }
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return d.title.toLowerCase().contains(q) ||
              d.reference.toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search duas...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _categories.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _category == e.key,
                            onSelected: (_) =>
                                setState(() => _category = e.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_category == 'azkar')
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const {
                          'all': 'All',
                          'morning': 'Morning',
                          'evening': 'Evening',
                        }.entries.map((e) {
                          return Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(e.value),
                              selected: _azkarTime == e.key,
                              onSelected: (_) =>
                                  setState(() => _azkarTime = e.key),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Text(
                    '${shown.length} items — Arabic text and references verified for all.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final d = shown[i];
                  final count = _counts[d.id] ?? 0;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  _categories[d.category] ?? d.category,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.arabic,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 22,
                              height: 1.9,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (d.transliteration != null) ...[
                            const Text(
                              'Roman transliteration:',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                            Text(d.transliteration!),
                            const SizedBox(height: 6),
                          ],
                          if (d.englishIsTransliteration)
                            const Text(
                              'Roman transliteration:',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          Text(d.english),
                          const SizedBox(height: 4),
                          Text(
                            d.reference,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.emerald,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _counts[d.id] = count + 1;
                                  });
                                },
                                child: Text(
                                  'Count: $count / ${d.repeat}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (count >= d.repeat)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.emerald,
                                ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() => _counts[d.id] = 0);
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        ],
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
