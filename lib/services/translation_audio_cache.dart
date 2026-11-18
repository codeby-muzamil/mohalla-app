import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'quran_reciters.dart';
import 'quran_service.dart';

/// Per-surah spoken-translation audio downloads (see
/// [TranslationVoice] — Urdu by Shamshad Ali Khan from everyayah.com,
/// English by Ibrahim Walk from cdn.islamic.network).
///
/// Same model as [QuranAudioCache]: the user downloads one surah at
/// a time; each ayah is saved as `<SSSAAA>.mp3` (3-digit surah +
/// 3-digit ayah) under the app documents directory
/// (`translation_audio/<voiceId>/<surah>/`). When a surah is
/// downloaded, the reader plays the local files instead of streaming.
/// A failed ayah never leaves a half-written file behind: bytes go
/// to a `.tmp` file first and are renamed to the real name only on
/// success. An unknown voice id is a silent no-op.
class TranslationAudioCache {
  static const _kDirName = 'translation_audio';
  static final Set<String> _downloading = {};

  static String _key(String voiceId, int surah) => '$voiceId:$surah';

  static bool isDownloading(String voiceId, int surah) =>
      _downloading.contains(_key(voiceId, surah));

  static Future<Directory> _rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_kDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _surahDir(String voiceId, int surah) async {
    final root = await _rootDir();
    final dir = Directory('${root.path}/$voiceId/$surah');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _ayahFileName(int surah, int ayah) =>
      '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  /// Local file for one ayah ([ayah] is the 1-based ayah number in
  /// the surah), or null when it is not downloaded.
  static Future<File?> localFileForAyah(
    String voiceId,
    int surah,
    int ayah,
  ) async {
    try {
      final dir = await _surahDir(voiceId, surah);
      final file = File('${dir.path}/${_ayahFileName(surah, ayah)}');
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  /// True when every ayah of the surah is downloaded.
  static Future<bool> isSurahDownloaded(String voiceId, int surah) async {
    try {
      final qSurah = QuranService.surah(surah);
      for (var i = 1; i <= qSurah.ayahs.length; i++) {
        if (await localFileForAyah(voiceId, surah, i) == null) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the surah's ayahs (only the ones not already
  /// downloaded — a failed download resumes where it stopped).
  /// [onProgress] reports (downloadedAyahs, totalAyahs,
  /// bytesDownloadedThisRun). Throws on a network failure or an
  /// HTTP status other than 200 — the caller shows the message.
  /// Returns silently (no-op) when the voice id is unknown.
  static Future<void> downloadSurah(
    String voiceId,
    int surah, {
    void Function(int done, int total, int bytes)? onProgress,
  }) async {
    final voice = TranslationVoice.byId(voiceId);
    if (voice == null) return;
    final key = _key(voiceId, surah);
    if (_downloading.contains(key)) return;
    _downloading.add(key);
    try {
      final qSurah = QuranService.surah(surah);
      final total = qSurah.ayahs.length;
      var done = 0;
      var bytes = 0;
      final dir = await _surahDir(voiceId, surah);
      final client = http.Client();
      try {
        for (var i = 0; i < total; i++) {
          final ayahNumber = i + 1;
          final global =
              QuranService.globalAyahNumber(surah, i);
          final file =
              File('${dir.path}/${_ayahFileName(surah, ayahNumber)}');
          if (await file.exists()) {
            done++;
            onProgress?.call(done, total, bytes);
            continue;
          }
          final tmp = File('${file.path}.tmp');
          try {
            final url = voice.urlFor(surah, ayahNumber, global);
            final request = http.Request('GET', Uri.parse(url));
            final response = await client.send(request);
            if (response.statusCode != 200) {
              throw HttpException(
                'Translation audio download failed (HTTP ${response.statusCode})',
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
  static Future<void> deleteSurah(String voiceId, int surah) async {
    try {
      final dir = await _surahDir(voiceId, surah);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Deleting must never crash the UI — the files stay.
    }
  }

  /// Bytes downloaded for one surah (0 when nothing is downloaded).
  static Future<int> cachedBytesForSurah(String voiceId, int surah) async {
    try {
      final dir = await _surahDir(voiceId, surah);
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

  /// Total bytes of downloaded translation audio (all voices).
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
}
