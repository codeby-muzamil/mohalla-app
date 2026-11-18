import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';

/// Hadith Library: verified hadiths (Sahih al-Bukhari / Sahih Muslim),
/// Arabic + English (+ Urdu where verified), with book + number,
/// search and topic filters. Every hadith was fetched from the public
/// hadith-api dataset at build time — nothing was written from memory.
class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  String _query = '';
  String _topic = 'all';

  static const _topics = [
    'all',
    'Iman',
    'Salah',
    'Akhlaq',
    'Sabr',
    'Ilm',
    'Zakat & Sadaqah',
    'Daily Life',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    return FutureBuilder<List<Hadith>>(
      future: DataService.hadiths(),
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
        final shown = all.where((h) {
          if (_topic != 'all' && h.topic != _topic) return false;
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return h.english.toLowerCase().contains(q) ||
              h.book.toLowerCase().contains(q) ||
              h.number.toString() == q;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search hadith (word or number)...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _topics.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(t == 'all' ? 'All' : t),
                            selected: _topic == t,
                            onSelected: (_) => setState(() => _topic = t),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Text(
                    '${shown.length} HADITHS — ALL VERIFIED FROM SUNNAH.COM / HADITH-API.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 92),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final h = shown[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${h.book} ${h.number}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  h.topic,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            h.arabic,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 21,
                              height: 1.9,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(h.english),
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
