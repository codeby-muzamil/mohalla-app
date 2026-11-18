import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'quran_service.dart';

/// One downloadable translation edition (text, one per language).
/// `translator` is '' when the source names no translator — the UI
/// then shows just the language name.
class TranslationEdition {
  final String id;
  final String languageCode;
  final String languageName;
  final String translator;
  final String source; // 'alquran' | 'quranenc'

  const TranslationEdition({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.translator,
    required this.source,
  });
}

/// Translation TEXT in 51 languages, downloaded one surah at a time
/// and cached on the phone as `translations/<editionId>/<surah>.json`
/// (`{"ayahs": ["...", ...]}`, index 0 = ayah 1).
///
/// Sources (both free, no key):
/// - alquran.cloud (47 languages): GET
///   https://api.alquran.cloud/v1/surah/{n}/{edition} →
///   data.ayahs[].text. Every edition listed here was confirmed
///   `format: "text"` in the alquran.cloud editions list on
///   2026-11-19 (the 'ar' entries are audio, so text languages = 47).
/// - QuranEnc (4 languages alquran.cloud does not have): GET
///   https://quranenc.com/api/v1/translation/sura/{key}/{sura} →
///   {"result": [{"sura", "aya", "arabic_text", "translation",
///   "footnotes"}]}. Verified live 2026-11-19 (Yoruba + Gujarati
///   surah 1 return 200 with this shape; the translation strings
///   carry their footnote markers, e.g. "[1]", inline).
/// Tanzil adds ZERO new languages — every one of its languages is
/// already on alquran.cloud, so it is not used.
class TranslationTextService {
  static const List<TranslationEdition> all = [
    TranslationEdition(
      id: 'sq.ahmeti',
      languageCode: 'sq',
      languageName: 'Albanian',
      translator: 'Sherif Ahmeti',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ber.mensur',
      languageCode: 'ber',
      languageName: 'Amazigh',
      translator: 'At Mensur',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'am.sadiq',
      languageCode: 'am',
      languageName: 'Amharic',
      translator: 'Sadiq & Sani Habib',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'az.mammadaliyev',
      languageCode: 'az',
      languageName: 'Azerbaijani',
      translator: 'Vasim Mammadaliyev and Ziya Bunyadov',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'bn.bengali',
      languageCode: 'bn',
      languageName: 'Bengali',
      translator: 'Muhiuddin Khan',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ba.mehanovic',
      languageCode: 'ba',
      languageName: 'Bosnian',
      translator: 'Muhamed Mehanovic',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'bs.mlivo',
      languageCode: 'bs',
      languageName: 'Bosnian',
      translator: 'Mustafa Mlivo',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'bg.theophanov',
      languageCode: 'bg',
      languageName: 'Bulgarian',
      translator: 'Tzvetan Theophanov',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'my.ghazi',
      languageCode: 'my',
      languageName: 'Burmese',
      translator: 'Translation by Ghazi Muhammed Hashim',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ce.magomedov',
      languageCode: 'ce',
      languageName: 'Chechen',
      translator: 'Chechen by Magomedov',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'zh.jian',
      languageCode: 'zh',
      languageName: 'Chinese',
      translator: 'Ma Jian',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'cs.hrbek',
      languageCode: 'cs',
      languageName: 'Czech',
      translator: 'Preklad I. Hrbek',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'dv.divehi',
      languageCode: 'dv',
      languageName: 'Divehi',
      translator: 'Office of the President of Maldives',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'nl.keyzer',
      languageCode: 'nl',
      languageName: 'Dutch',
      translator: 'Salomo Keyzer',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'en.sahih',
      languageCode: 'en',
      languageName: 'English',
      translator: 'Saheeh International',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'fr.hamidullah',
      languageCode: 'fr',
      languageName: 'French',
      translator: 'Muhammad Hamidullah',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'de.bubenheim',
      languageCode: 'de',
      languageName: 'German',
      translator: 'A. S. F. Bubenheim and N. Elyas',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'gujarati_omari',
      languageCode: 'gu',
      languageName: 'Gujarati',
      translator: 'Rabella Al-Omari',
      source: 'quranenc',
    ),
    TranslationEdition(
      id: 'ha.gumi',
      languageCode: 'ha',
      languageName: 'Hausa',
      translator: 'Abubakar Mahmoud Gumi',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'hi.hindi',
      languageCode: 'hi',
      languageName: 'Hindi',
      translator: 'Suhel Farooq Khan and Saifur Rahman Nadwi',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'id.muntakhab',
      languageCode: 'id',
      languageName: 'Indonesian',
      translator: 'Muhammad Quraish Shihab et al.',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'it.piccardo',
      languageCode: 'it',
      languageName: 'Italian',
      translator: 'Hamza Roberto Piccardo',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ja.japanese',
      languageCode: 'ja',
      languageName: 'Japanese',
      translator: '',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ko.korean',
      languageCode: 'ko',
      languageName: 'Korean',
      translator: '',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ku.asan',
      languageCode: 'ku',
      languageName: 'Kurdish',
      translator: 'Burhan Muhammad-Amin',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ms.basmeih',
      languageCode: 'ms',
      languageName: 'Malay',
      translator: 'Abdullah Muhammad Basmeih',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ml.abdulhameed',
      languageCode: 'ml',
      languageName: 'Malayalam',
      translator: 'Cheriyamundam Abdul Hameed and Kunhi Mohammed Parappoor',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'no.berg',
      languageCode: 'no',
      languageName: 'Norwegian',
      translator: 'Einar Berg',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'oromo_rwwad',
      languageCode: 'om',
      languageName: 'Oromo',
      translator: 'Rowwad Translation Center',
      source: 'quranenc',
    ),
    TranslationEdition(
      id: 'ps.abdulwali',
      languageCode: 'ps',
      languageName: 'Pashto',
      translator: 'Abdul Wali',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'fa.fooladvand',
      languageCode: 'fa',
      languageName: 'Persian',
      translator: 'Mohammad Mahdi Fooladvand',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'pl.bielawskiego',
      languageCode: 'pl',
      languageName: 'Polish',
      translator: 'Józefa Bielawskiego',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'pt.elhayek',
      languageCode: 'pt',
      languageName: 'Portuguese',
      translator: 'Samir El-Hayek',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ro.grigore',
      languageCode: 'ro',
      languageName: 'Romanian',
      translator: 'George Grigore',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ru.kuliev',
      languageCode: 'ru',
      languageName: 'Russian',
      translator: 'Elmir Kuliev',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'sd.amroti',
      languageCode: 'sd',
      languageName: 'Sindhi',
      translator: 'Taj Mehmood Amroti',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'si.naseemismail',
      languageCode: 'si',
      languageName: 'Sinhala',
      translator: 'Naseem Isamil and Masoor Maulana, Kaleel',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'so.abduh',
      languageCode: 'so',
      languageName: 'Somali',
      translator: 'Mahmud Muhammad Abduh',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'es.cortes',
      languageCode: 'es',
      languageName: 'Spanish',
      translator: 'Julio Cortes',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'sw.barwani',
      languageCode: 'sw',
      languageName: 'Swahili',
      translator: 'Ali Muhsin Al-Barwani',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'sv.bernstrom',
      languageCode: 'sv',
      languageName: 'Swedish',
      translator: 'Knut Bernström',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'tg.ayati',
      languageCode: 'tg',
      languageName: 'Tajik',
      translator: 'AbdolMohammad Ayati',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ta.tamil',
      languageCode: 'ta',
      languageName: 'Tamil',
      translator: 'Jan Turst Foundation',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'tt.nugman',
      languageCode: 'tt',
      languageName: 'Tatar',
      translator: 'Yakub Ibn Nugman',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'th.thai',
      languageCode: 'th',
      languageName: 'Thai',
      translator: 'King Fahad Quran Complex',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'tr.diyanet',
      languageCode: 'tr',
      languageName: 'Turkish',
      translator: 'Diyanet Isleri',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ur.jalandhry',
      languageCode: 'ur',
      languageName: 'Urdu',
      translator: 'Fateh Muhammad Jalandhry',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'ug.saleh',
      languageCode: 'ug',
      languageName: 'Uyghur',
      translator: 'Muhammad Saleh',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'uz.sodik',
      languageCode: 'uz',
      languageName: 'Uzbek',
      translator: 'Muhammad Sodik Muhammad Yusuf',
      source: 'alquran',
    ),
    TranslationEdition(
      id: 'vietnamese_rwwad',
      languageCode: 'vi',
      languageName: 'Vietnamese',
      translator: 'Rowwad Translation Center',
      source: 'quranenc',
    ),
    TranslationEdition(
      id: 'yoruba_mikail',
      languageCode: 'yo',
      languageName: 'Yoruba',
      translator: 'Abu Rahimah Mikael',
      source: 'quranenc',
    ),
  ];

  static TranslationEdition? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static const _kDirName = 'translations';
  static const _kMaxCachedSurahs = 30;
  static final Map<String, List<String>> _cache = {};

  static String _key(String editionId, int surah) => '$editionId:$surah';

  static Future<Directory> _editionDir(String editionId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_kDirName/$editionId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _surahFile(String editionId, int surah) async {
    final dir = await _editionDir(editionId);
    return File('${dir.path}/$surah.json');
  }

  static void _putInMemory(String editionId, int surah, List<String> ayahs) {
    if (_cache.length >= _kMaxCachedSurahs) _cache.clear();
    _cache[_key(editionId, surah)] = ayahs;
  }

  static Future<List<String>?> _loadFromDisk(
    String editionId,
    int surah,
  ) async {
    try {
      final file = await _surahFile(editionId, surah);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['ayahs'] as List)
          .map((a) => a.toString())
          .toList();
      if (list.isEmpty) return null;
      _putInMemory(editionId, surah, list);
      return list;
    } catch (_) {
      return null;
    }
  }

  static int _expectedAyahCount(int surah) {
    try {
      return QuranService.surah(surah).ayahs.length;
    } catch (_) {
      return 0; // Quran text not loaded yet — accept any non-empty list.
    }
  }

  /// One ayah's translation text ('' when unavailable). Reads the
  /// in-memory cache, then the disk cache. Does NOT download — the
  /// UI calls [ensureSurah] first.
  static Future<String> ayah(
    String editionId,
    int surah,
    int ayahIndex,
  ) async {
    final key = _key(editionId, surah);
    var list = _cache[key];
    list ??= await _loadFromDisk(editionId, surah);
    if (list == null || ayahIndex < 0 || ayahIndex >= list.length) return '';
    return list[ayahIndex];
  }

  /// True when the surah's translation is cached on disk.
  static Future<bool> isSurahDownloaded(String editionId, int surah) async {
    final list = await _loadFromDisk(editionId, surah);
    if (list == null) return false;
    final expected = _expectedAyahCount(surah);
    return expected == 0 || list.length >= expected;
  }

  /// Downloads the surah's translation if it is not cached yet.
  /// Throws on a network failure or a bad response — the caller
  /// shows the message (or stays silent, per screen).
  static Future<void> ensureSurah(String editionId, int surah) async {
    if (await isSurahDownloaded(editionId, surah)) return;
    final edition = byId(editionId);
    if (edition == null) {
      throw ArgumentError('Unknown translation edition: $editionId');
    }
    final ayahs = await _download(edition, surah);
    if (ayahs.isEmpty) {
      throw HttpException(
        'Empty translation response for $editionId surah $surah',
      );
    }
    final file = await _surahFile(editionId, surah);
    await file.writeAsString(jsonEncode({'ayahs': ayahs}));
    _putInMemory(editionId, surah, ayahs);
  }

  static Future<List<String>> _download(
    TranslationEdition edition,
    int surah,
  ) async {
    if (edition.source == 'quranenc') {
      return _downloadQuranEnc(edition, surah);
    }
    final uri = Uri.parse(
      'https://api.alquran.cloud/v1/surah/$surah/${edition.id}',
    );
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException(
        'Translation download failed (HTTP ${response.statusCode})',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();
    return ayahs.map((a) => (a['text'] ?? '').toString()).toList();
  }

  /// QuranEnc: {"result": [{"sura", "aya", "translation",
  /// "footnotes", ...}]}. Items are placed by their 'aya' number
  /// so a shuffled or sparse response still lands correctly.
  /// Falls back to a 'text' field if 'translation' is ever absent.
  static Future<List<String>> _downloadQuranEnc(
    TranslationEdition edition,
    int surah,
  ) async {
    final uri = Uri.parse(
      'https://quranenc.com/api/v1/translation/sura/${edition.id}/$surah',
    );
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException(
        'Translation download failed (HTTP ${response.statusCode})',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final result = (json['result'] as List).cast<Map<String, dynamic>>();
    var count = _expectedAyahCount(surah);
    if (count == 0) {
      for (final item in result) {
        final aya = int.tryParse((item['aya'] ?? '').toString()) ?? 0;
        if (aya > count) count = aya;
      }
    }
    final ayahs = List<String>.filled(count, '');
    for (final item in result) {
      final aya = int.tryParse((item['aya'] ?? '').toString()) ?? 0;
      if (aya < 1 || aya > count) continue;
      final text = item['translation'] ?? item['text'] ?? '';
      ayahs[aya - 1] = text.toString();
    }
    return ayahs;
  }

  /// Deletes a whole language's cached translations (all surahs)
  /// and drops its in-memory entries.
  static Future<void> deleteLanguage(String editionId) async {
    _cache.removeWhere((k, _) => k.startsWith('$editionId:'));
    try {
      final dir = await _editionDir(editionId);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Deleting must never crash the UI — the files stay.
    }
  }

  /// Bytes cached for one language (0 when nothing is downloaded).
  static Future<int> cachedBytesForLanguage(String editionId) async {
    try {
      final dir = await _editionDir(editionId);
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.json')) {
          total += await e.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
