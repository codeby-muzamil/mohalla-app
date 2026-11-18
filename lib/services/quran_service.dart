import 'dart:convert';

import 'package:flutter/services.dart';

/// Full Quran text bundled as JSON assets (see assets/quran/).
/// Sources (AlQuran Cloud, public API — fetched at build time):
/// - Arabic Uthmani text: quran-uthmani edition
/// - Urdu translation: Fateh Muhammad Jalandhari (ur.jalandhry)
/// - English translation: Muhammad Asad (en.asad)
/// Verified counts: 114 surahs, 6,236 ayat in each edition.
/// Juz (Para) boundaries come from assets/data/juz_boundaries.json,
/// fetched from the same API (/v1/juz/1..30) — never hardcoded.
class Surah {
  final int number;
  final String name; // Arabic name
  final String englishName;
  final String englishNameTranslation;
  final String revelationType; // Meccan | Medinan
  final List<String> ayahs; // Arabic Uthmani text

  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.revelationType,
    required this.ayahs,
  });

  int get numberOfAyahs => ayahs.length;
}

class QuranService {
  static List<Surah>? _surahs;
  static Map<int, List<String>>? _urdu;
  static Map<int, List<String>>? _english;
  static List<(int, int)>? _juzStarts; // (surah, ayah) per Juz 1..30

  static bool get isLoaded => _surahs != null;

  static int get totalSurahs => _surahs?.length ?? 0;

  static int get totalAyahs =>
      _surahs?.fold<int>(0, (sum, s) => sum + s.ayahs.length) ?? 0;

  /// Loads all three editions + Juz boundaries once.
  static Future<void> load() async {
    if (_surahs != null) return;
    final arRaw = await rootBundle.loadString('assets/quran/ar.json');
    final arJson = jsonDecode(arRaw) as Map<String, dynamic>;
    final arSurahs = (arJson['surahs'] as List).cast<Map<String, dynamic>>();
    _surahs = arSurahs
        .map(
          (s) => Surah(
            number: s['number'] as int,
            name: s['name'] as String,
            englishName: s['englishName'] as String,
            englishNameTranslation: s['englishNameTranslation'] as String,
            revelationType: s['revelationType'] as String,
            ayahs: (s['ayahs'] as List).map((a) => a.toString()).toList(),
          ),
        )
        .toList();

    _urdu = await _loadTranslation('assets/quran/ur.json');
    _english = await _loadTranslation('assets/quran/en.json');

    try {
      final jRaw =
          await rootBundle.loadString('assets/data/juz_boundaries.json');
      final jJson = jsonDecode(jRaw) as Map<String, dynamic>;
      final list = (jJson['boundaries'] as List).cast<Map<String, dynamic>>();
      _juzStarts = list
          .map((b) => (b['surah'] as int, b['ayah'] as int))
          .toList();
    } catch (_) {
      _juzStarts = null; // Juz labels fall back to "—" in the UI.
    }
  }

  static Future<Map<int, List<String>>> _loadTranslation(String asset) async {
    final raw = await rootBundle.loadString(asset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final surahs = (json['surahs'] as List).cast<Map<String, dynamic>>();
    final map = <int, List<String>>{};
    for (final s in surahs) {
      map[s['number'] as int] =
          (s['ayahs'] as List).map((a) => a.toString()).toList();
    }
    return map;
  }

  static List<Surah> get surahs => _surahs ?? const [];

  static Surah surah(int number) =>
      _surahs!.firstWhere((s) => s.number == number);

  static String urduAyah(int surah, int ayahIndex) {
    final list = _urdu?[surah];
    if (list == null || ayahIndex >= list.length) return '';
    return list[ayahIndex];
  }

  static String englishAyah(int surah, int ayahIndex) {
    final list = _english?[surah];
    if (list == null || ayahIndex >= list.length) return '';
    return list[ayahIndex];
  }

  /// Juz (Para) number for an ayah, from the verified boundaries file.
  /// Returns 0 when the boundaries file is unavailable.
  static int juzOf(int surah, int ayahNumberInSurah) {
    final starts = _juzStarts;
    if (starts == null || starts.length != 30) return 0;
    var juz = 1;
    for (var i = 0; i < starts.length; i++) {
      final (s, a) = starts[i];
      if (surah > s || (surah == s && ayahNumberInSurah >= a)) {
        juz = i + 1;
      }
    }
    return juz;
  }

  /// Online per-ayah audio — needs internet.
  /// Pattern: https://cdn.islamic.network/quran/audio/{bitrate}/{edition}/{n}.mp3
  /// where n is the GLOBAL ayah number (1..6236). The bitrate is per
  /// reciter: Abdul Basit and Sudais are 192kbps, the rest 128 —
  /// their 128kbps URLs return 403 (verified 2026-11-19).
  /// Defaults keep the old Alafasy behaviour.
  static String audioUrlForGlobalAyah(
    int globalAyahNumber, [
    String edition = 'ar.alafasy',
    int bitrate = 128,
  ]) =>
      'https://cdn.islamic.network/quran/audio/$bitrate/$edition/$globalAyahNumber.mp3';

  /// Global ayah number (1..6236) for surah + ayah-in-surah.
  static int globalAyahNumber(int surahNumber, int ayahIndex) {
    var n = 0;
    for (final s in _surahs ?? const <Surah>[]) {
      if (s.number < surahNumber) {
        n += s.ayahs.length;
      } else {
        break;
      }
    }
    return n + ayahIndex + 1;
  }
}
