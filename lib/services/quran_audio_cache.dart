import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'quran_reciters.dart';
import 'quran_service.dart';

/// Per-surah Quran audio downloads (default reciter Alafasy,
/// 128kbps — the same files the reader streams today from
/// cdn.islamic.network; other reciters via [QuranReciter]).
///
/// The full Quran is ~1 GB+ of audio and is NEVER bundled with the
/// app. Instead the user downloads one surah at a time; each ayah is
/// saved as `<global ayah number>.mp3` under the app documents
/// directory. For Alafasy the directory is the legacy
/// `quran_audio/<surah>/` — existing downloads are NOT moved or
/// renamed. For any other reciter it is
/// `quran_audio/<reciterId>/<surah>/`. When a surah is downloaded,
/// the reader plays the local files instead of streaming — no
/// internet needed. Anything not downloaded streams exactly as
/// before. Deleting a surah removes its files; the total cached size
/// is shown on the Quran list screen and in the reader.
class QuranAudioCache {
  static const _kDirName = 'quran_audio';
  static const _kLegacyReciterId = 'ar.alafasy';
  static final Set<String> _downloading = {};

  static String _key(String reciterId, int surahNumber) =>
      '$reciterId:$surahNumber';

  static bool isDownloading(
    int surahNumber, {
    String reciterId = _kLegacyReciterId,
  }) =>
      _downloading.contains(_key(reciterId, surahNumber));

  static Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_kDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Alafasy keeps the legacy `quran_audio/<surah>/` directory so
  /// existing downloads keep working; every other reciter gets its
  /// own `quran_audio/<reciterId>/<surah>/` directory.
  static Future<Directory> _surahDir(
    int surahNumber, {
    String reciterId = _kLegacyReciterId,
  }) async {
    final root = await _rootDir();
    final path = reciterId == _kLegacyReciterId
        ? '${root.path}/$surahNumber'
        : '${root.path}/$reciterId/$surahNumber';
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _ayahFileName(int globalAyah) => '$globalAyah.mp3';

  /// Local file for one ayah, or null when it is not downloaded.
  static Future<File?> localFileForAyah(
    int surahNumber,
    int ayahIndex, {
    String reciterId = _kLegacyReciterId,
  }) async {
    try {
      final global =
          QuranService.globalAyahNumber(surahNumber, ayahIndex);
      final dir = await _surahDir(surahNumber, reciterId: reciterId);
      final file = File('${dir.path}/${_ayahFileName(global)}');
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  /// True when every ayah of the surah is downloaded.
  static Future<bool> isSurahDownloaded(
    int surahNumber, {
    String reciterId = _kLegacyReciterId,
  }) async {
    try {
      final surah = QuranService.surah(surahNumber);
      for (var i = 0; i < surah.ayahs.length; i++) {
        if (await localFileForAyah(
              surahNumber,
              i,
              reciterId: reciterId,
            ) ==
            null) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the surah's ayahs (only the ones not already
  /// downloaded — a failed download resumes where it stopped).
  /// [onProgress] reports (downloadedAyahs, totalAyahs,
  /// bytesDownloadedThisRun). Throws on a network failure — the
  /// caller shows the message. A failed ayah never leaves a
  /// half-written file behind: bytes go to a `.tmp` file first and
  /// are renamed to the real name only on success.
  static Future<void> downloadSurah(
    int surahNumber, {
    String reciterId = _kLegacyReciterId,
    void Function(int done, int total, int bytes)? onProgress,
  }) async {
    final key = _key(reciterId, surahNumber);
    if (_downloading.contains(key)) return;
    _downloading.add(key);
    try {
      final surah = QuranService.surah(surahNumber);
      final reciter = QuranReciter.byEdition(reciterId);
      final total = surah.ayahs.length;
      var done = 0;
      var bytes = 0;
      final dir = await _surahDir(surahNumber, reciterId: reciterId);
      final client = http.Client();
      try {
        for (var i = 0; i < total; i++) {
          final global =
              QuranService.globalAyahNumber(surahNumber, i);
          final file = File('${dir.path}/${_ayahFileName(global)}');
          if (await file.exists()) {
            done++;
            onProgress?.call(done, total, bytes);
            continue;
          }
          final tmp = File('${file.path}.tmp');
          try {
            final url = QuranService.audioUrlForGlobalAyah(
              global,
              reciter.edition,
              reciter.bitrate,
            );
            final request = http.Request('GET', Uri.parse(url));
            final response = await client.send(request);
            if (response.statusCode != 200) {
              throw HttpException(
                'Audio download failed (HTTP ${response.statusCode})',
              );
            }
            final sink = tmp.openWrite();
            try {
              await for (final chunk in response.stream) {
                sink.add(chunk);
                bytes += chunk.length;
              }
            } finally {
              await sink.close();
            }
            await tmp.rename(file.path);
          } catch (_) {
            try {
              if (await tmp.exists()) await tmp.delete();
            } catch (_) {}
            rethrow;
          }
          done++;
          onProgress?.call(done, total, bytes);
        }
      } finally {
        client.close();
      }
    } finally {
      _downloading.remove(key);
    }
  }

  /// Deletes a downloaded surah (all its ayah files).
  static Future<void> deleteSurah(
    int surahNumber, {
    String reciterId = _kLegacyReciterId,
  }) async {
    try {
      final dir = await _surahDir(surahNumber, reciterId: reciterId);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Deleting must never crash the UI — the files stay.
    }
  }

  /// Bytes downloaded for one surah (0 when nothing is downloaded).
  static Future<int> cachedBytesForSurah(
    int surahNumber, {
    String reciterId = _kLegacyReciterId,
  }) async {
    try {
      final dir = await _surahDir(surahNumber, reciterId: reciterId);
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.mp3')) {
          total += await e.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Estimated bytes for one surah with one reciter. Tries a HEAD
  /// request on the per-surah file first — note the path is ALWAYS
  /// the 128kbps one, because that is where the surah files live
  /// (only Alafasy and Abdul Basit have them; the other reciters
  /// 404). Otherwise estimates from the ayah count and bitrate
  /// (~180 KB per ayah at 128kbps, ~270 KB at 192kbps). Returns null
  /// only when even the ayah count is unavailable (Quran text not
  /// loaded and no HEAD size).
  static Future<int?> estimateSurahBytes(
    String reciterId,
    int surahNumber,
  ) async {
    final reciter = QuranReciter.byEdition(reciterId);
    try {
      final uri = Uri.parse(
        'https://cdn.islamic.network/quran/audio-surah/128/${reciter.edition}/$surahNumber.mp3',
      );
      final response =
          await http.head(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final length =
            int.tryParse(response.headers['content-length'] ?? '');
        if (length != null && length > 0) return length;
      }
    } catch (_) {
      // Fall through to the per-ayah estimate below.
    }
    try {
      final surah = QuranService.surah(surahNumber);
      final perAyah = reciter.bitrate == 192 ? 270000 : 180000;
      return surah.ayahs.length * perAyah;
    } catch (_) {
      return null;
    }
  }

  /// Total bytes of downloaded Quran audio (all surahs).
  static Future<int> totalCachedBytes() async {
    try {
      final root = await _rootDir();
      if (!await root.exists()) return 0;
      var total = 0;
      await for (final e in root.list(recursive: true)) {
        if (e is File && e.path.endsWith('.mp3')) {
          total += await e.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// '1.2 MB' / '340 KB' / '512 B' for a byte count.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
