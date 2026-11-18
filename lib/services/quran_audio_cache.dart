import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'quran_service.dart';

/// Per-surah Quran audio downloads (Alafasy, 128kbps — the same files
/// the reader streams today from cdn.islamic.network).
///
/// The full Quran is ~1 GB+ of audio and is NEVER bundled with the
/// app. Instead the user downloads one surah at a time; each ayah is
/// saved as `<global ayah number>.mp3` under the app documents
/// directory (`quran_audio/<surah>/`). When a surah is downloaded,
/// the reader plays the local files instead of streaming — no
/// internet needed. Anything not downloaded streams exactly as
/// before. Deleting a surah removes its files; the total cached size
/// is shown on the Quran list screen and in the reader.
class QuranAudioCache {
  static const _kDirName = 'quran_audio';
  static final Set<int> _downloading = {};

  static bool isDownloading(int surahNumber) =>
      _downloading.contains(surahNumber);

  static Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_kDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _surahDir(int surahNumber) async {
    final root = await _rootDir();
    final dir = Directory('${root.path}/$surahNumber');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _ayahFileName(int globalAyah) => '$globalAyah.mp3';

  /// Local file for one ayah, or null when it is not downloaded.
  static Future<File?> localFileForAyah(
    int surahNumber,
    int ayahIndex,
  ) async {
    try {
      final global =
          QuranService.globalAyahNumber(surahNumber, ayahIndex);
      final dir = await _surahDir(surahNumber);
      final file = File('${dir.path}/${_ayahFileName(global)}');
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  /// True when every ayah of the surah is downloaded.
  static Future<bool> isSurahDownloaded(int surahNumber) async {
    try {
      final surah = QuranService.surah(surahNumber);
      for (var i = 0; i < surah.ayahs.length; i++) {
        if (await localFileForAyah(surahNumber, i) == null) return false;
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
    void Function(int done, int total, int bytes)? onProgress,
  }) async {
    if (_downloading.contains(surahNumber)) return;
    _downloading.add(surahNumber);
    try {
      final surah = QuranService.surah(surahNumber);
      final total = surah.ayahs.length;
      var done = 0;
      var bytes = 0;
      final dir = await _surahDir(surahNumber);
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
            final url = QuranService.audioUrlForGlobalAyah(global);
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
      _downloading.remove(surahNumber);
    }
  }

  /// Deletes a downloaded surah (all its ayah files).
  static Future<void> deleteSurah(int surahNumber) async {
    try {
      final dir = await _surahDir(surahNumber);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Deleting must never crash the UI — the files stay.
    }
  }

  /// Bytes downloaded for one surah (0 when nothing is downloaded).
  static Future<int> cachedBytesForSurah(int surahNumber) async {
    try {
      final dir = await _surahDir(surahNumber);
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
