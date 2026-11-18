import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/quran_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'mushaf_reader_screen.dart';
import 'quran_reader_screen.dart';

/// Quran home: search, Surah list (114), Para (Juz) navigation,
/// bookmarks, last-read resume. Works fully offline (bundled JSON).
class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> {
  String _query = '';
  bool _loading = true;
  int _juzFilter = 0; // 0 = all

  @override
  void initState() {
    super.initState();
    QuranService.load().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final surahs = QuranService.surahs.where((s) {
      if (_juzFilter != 0) {
        // A surah belongs to a Juz if any of its ayat fall in it.
        final firstJuz = QuranService.juzOf(s.number, 1);
        final lastJuz = QuranService.juzOf(s.number, s.ayahs.length);
        if (firstJuz == 0 || lastJuz == 0) return false;
        if (_juzFilter < firstJuz || _juzFilter > lastJuz) return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return s.englishName.toLowerCase().contains(q) ||
          s.englishNameTranslation.toLowerCase().contains(q) ||
          s.number.toString() == q;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              PressableCard(
                gradientBorder: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MushafReaderScreen(),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_stories,
                        color: AppTheme.emerald,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mushaf — 16 Line (Pakistani)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '548 pages • 16 lines per page • Translation included',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search Surahs (name or number)...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${QuranService.totalSurahs} Surahs • '
                      '${QuranService.totalAyahs} Verses • Offline',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  if (settings.lastRead.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Resume'),
                      onPressed: () {
                        final parts = settings.lastRead.split(':');
                        final s = int.tryParse(parts[0]) ?? 1;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuranReaderScreen(
                              surahNumber: s,
                              initialAyah: parts.length > 1
                                  ? int.tryParse(parts[1]) ?? 1
                                  : 1,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('All Surahs'),
                      selected: _juzFilter == 0,
                      onSelected: (_) => setState(() => _juzFilter = 0),
                    ),
                    for (var j = 1; j <= 30; j++)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text('Juz $j'),
                          selected: _juzFilter == j,
                          onSelected: (_) => setState(() => _juzFilter = j),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: surahs.length,
            itemBuilder: (context, i) {
              final s = surahs[i];
              final juz = QuranService.juzOf(s.number, 1);
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: PressableCard(
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          QuranReaderScreen(surahNumber: s.number),
                    ),
                  ),
                  child: ListTile(
                  leading: NumberBadge(text: '${s.number}'),
                  title: Text(
                    s.name,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 22,
                    ),
                  ),
                  subtitle: Text(
                    '${s.englishName} — ${s.englishNameTranslation} • '
                    '${s.ayahs.length} verses • ${s.revelationType}'
                    '${juz > 0 ? ' • Juz $juz' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            );
            },
          ),
        ),
      ],
    );
  }
}
