/// Arabic reciters (per-ayah MP3 from cdn.islamic.network) and
/// translation voices (per-ayah MP3 from everyayah.com / the same
/// Islamic Network CDN).
///
/// Bitrate is PER RECITER and matters: Abdul Basit and Sudais are
/// 192kbps — their 128kbps URLs return 403. All six reciters below
/// were verified live (HTTP 200) on 2026-11-19. Two candidates were
/// dropped (403): ar.abdullahbasfar and ar.saoodshuraym.
///
/// Per-surah single files (audio-surah/...) exist ONLY for Alafasy
/// and Abdul Basit; the app never plays them — it streams/downloads
/// per-ayah files. The surah URL is used ONLY for size estimation
/// (see QuranAudioCache.estimateSurahBytes).
class QuranReciter {
  final String id;
  final String edition;
  final int bitrate;
  final String label;
  final String note;

  const QuranReciter({
    required this.id,
    required this.edition,
    required this.bitrate,
    required this.label,
    required this.note,
  });

  static const List<QuranReciter> all = [
    QuranReciter(
      id: 'alafasy',
      edition: 'ar.alafasy',
      bitrate: 128,
      label: 'Mishary Alafasy',
      note: 'World-famous reciter, Kuwait',
    ),
    QuranReciter(
      id: 'abdulbasit',
      edition: 'ar.abdulbasitmurattal',
      bitrate: 192,
      label: 'Abdul Basit',
      note: 'Egyptian master of Tajwid',
    ),
    QuranReciter(
      id: 'sudais',
      edition: 'ar.abdurrahmaansudais',
      bitrate: 192,
      label: 'Abdurrahmaan As-Sudais',
      note: 'Imam of the Grand Mosque, Makkah',
    ),
    QuranReciter(
      id: 'husary',
      edition: 'ar.husary',
      bitrate: 128,
      label: 'Mahmoud Khalil Al-Husary',
      note: 'Egyptian master, Murattal style',
    ),
    QuranReciter(
      id: 'minshawi',
      edition: 'ar.minshawi',
      bitrate: 128,
      label: 'Mohamed Siddiq Al-Minshawi',
      note: 'Egyptian master, Mujawwad style',
    ),
    QuranReciter(
      id: 'muaiqly',
      edition: 'ar.mahermuaiqly',
      bitrate: 128,
      label: 'Maher Al Muaiqly',
      note: 'Imam of the Grand Mosque, Makkah',
    ),
  ];

  static QuranReciter byEdition(String edition) =>
      all.firstWhere((r) => r.edition == edition, orElse: () => all.first);

  String ayahUrl(int globalAyah) =>
      'https://cdn.islamic.network/quran/audio/$bitrate/$edition/$globalAyah.mp3';

  String surahUrl(int surah) =>
      'https://cdn.islamic.network/quran/audio-surah/$bitrate/$edition/$surah.mp3';
}

/// A spoken translation of the Quran, one voice per language.
/// Only two exist anywhere as per-ayah audio (verified 2026-11-19):
/// Urdu by Shamshad Ali Khan (everyayah.com) and English by Ibrahim
/// Walk (Islamic Network CDN). Translation audio in 50+ languages
/// does not exist — translation TEXT covers 51 languages instead
/// (see TranslationTextService).
class TranslationVoice {
  final String id;
  final String language;
  final String label;
  final String kind; // 'everyayah' | 'cdn'
  final String edition; // 'en.walk' for cdn kind, '' for everyayah kind
  final String baseUrl; // everyayah folder URL with trailing slash, '' for cdn kind
  final int bitrate;
  final int avgBytesPerAyah;

  const TranslationVoice({
    required this.id,
    required this.language,
    required this.label,
    required this.kind,
    required this.edition,
    required this.baseUrl,
    required this.bitrate,
    required this.avgBytesPerAyah,
  });

  static const List<TranslationVoice> all = [
    TranslationVoice(
      id: 'ur.shamshad',
      language: 'ur',
      label: 'Urdu — Shamshad Ali Khan',
      kind: 'everyayah',
      edition: '',
      baseUrl:
          'https://everyayah.com/data/translations/urdu_shamshad_ali_khan_46kbps/',
      bitrate: 46,
      avgBytesPerAyah: 65000,
    ),
    TranslationVoice(
      id: 'en.walk',
      language: 'en',
      label: 'English — Ibrahim Walk',
      kind: 'cdn',
      edition: 'en.walk',
      baseUrl: '',
      bitrate: 192,
      avgBytesPerAyah: 280000,
    ),
  ];

  static TranslationVoice? byId(String id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return null;
  }

  String urlFor(int surah, int ayah, int globalAyah) {
    if (kind == 'everyayah') {
      return '$baseUrl${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';
    }
    return 'https://cdn.islamic.network/quran/audio/$bitrate/$edition/$globalAyah.mp3';
  }
}
