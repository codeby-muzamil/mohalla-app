import 'dart:convert';

import 'package:flutter/services.dart';

/// 16-line Pakistani Mushaf (Taj Company layout, 548 pages x 16 lines).
///
/// Source: QUL — TarteelAI Quranic Universal Library — "Indopak 16 lines
/// layout (Taj Company)" + IndoPak word-by-word text, as shipped by the
/// open-source Nimaz app (arshad-shah/Nimaz, nimaz-pro-data). QUL states
/// layouts are free to bundle (personal + commercial); the IndoPak
/// Nastaleeq font (QuranWBW) asks for written notice before distribution
/// — see assets/quran/mushaf_16line_README.md.
///
/// VERIFIED (2026-11-17, conversion script in /tmp/mushaf16/convert.py):
/// 548 pages (1..548), 8,743 visual lines, 6,236 ayat reconstructed
/// word-for-word (83,668 words, 0 mismatches vs the source text),
/// 114 surah headers, 112 basmalah lines. 544 pages have exactly 16
/// lines; pp. 1-2 have 7 (opening spread), p. 290 has 15, p. 548 has 10.
///
/// Line format in assets/quran/mushaf_16line.json:
///   ['a', [[surah, ayah, 'words...'], ...]]  ayah segments (a line can
///       span several ayat — pages often end mid-ayah in this layout)
///   ['h', surah]    surah header line
///   ['b']           basmalah line (text = the standard Bismillah)
///   ['hb', surah]   header + basmalah share one line (81 surahs)
class MushafService {
  static List<List<List<dynamic>>>? _pages;
  static Map<int, int>? _surahPage;
  static String _basmalah = '';

  static Future<void> load() async {
    if (_pages != null) return;
    final raw =
        await rootBundle.loadString('assets/quran/mushaf_16line.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _pages = (json['pages'] as List)
        .map((p) => (p as List).cast<List<dynamic>>())
        .toList();
    final sp = json['surahPage'] as Map<String, dynamic>;
    _surahPage = sp.map((k, v) => MapEntry(int.parse(k), v as int));
    _basmalah = json['basmalah'] as String? ?? '';
  }

  static bool get isLoaded => _pages != null;
  static int get totalPages => _pages?.length ?? 548;
  static String get basmalah => _basmalah;

  /// First page on which [surah] starts.
  static int firstPageOfSurah(int surah) => _surahPage?[surah] ?? 1;

  /// Raw lines of page [page] (1-based). Each line is a JSON array
  /// (see the class doc above).
  static List<List<dynamic>> pageLines(int page) {
    final pages = _pages;
    if (pages == null || page < 1 || page > pages.length) return const [];
    return pages[page - 1];
  }

  /// All (surah, ayah) pairs printed on [page], in order, duplicates
  /// removed — for the translation panel.
  static List<(int, int)> pageAyahs(int page) {
    final seen = <(int, int)>{};
    final out = <(int, int)>[];
    for (final line in pageLines(page)) {
      if (line.isEmpty || line[0] != 'a') continue;
      final segs = line[1] as List;
      for (final seg in segs) {
        final pair = (seg[0] as int, seg[1] as int);
        if (seen.add(pair)) out.add(pair);
      }
    }
    return out;
  }

  /// Surah numbers whose header appears on [page].
  static List<int> pageSurahs(int page) {
    final out = <int>[];
    for (final line in pageLines(page)) {
      if (line.isEmpty) continue;
      if ((line[0] == 'h' || line[0] == 'hb') && line.length > 1) {
        out.add(line[1] as int);
      }
    }
    return out;
  }
}
