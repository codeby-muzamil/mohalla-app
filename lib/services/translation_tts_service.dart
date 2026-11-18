import 'package:flutter_tts/flutter_tts.dart';

/// One piece of translation text to read aloud, with its language.
class TtsPart {
  final String text;
  final String languageCode; // e.g. 'ur', 'en', 'fr'

  const TtsPart(this.text, this.languageCode);
}

/// Phone voice: reads a shown translation aloud with the phone's
/// built-in text-to-speech engine. This is NOT a reciter — it is
/// the device voice, and it only works for languages the phone has
/// a voice for. Everything is best-effort: any failure returns
/// false and the UI says so honestly. Never throws.
///
/// Only one reading runs at a time: starting a new one (or stop())
/// invalidates the previous run via a generation counter, so two
/// readings can never talk over each other.
class TranslationTtsService {
  final FlutterTts _tts = FlutterTts();
  int _generation = 0;
  bool _configured = false;

  /// Language code (e.g. 'ur') → TTS locale (e.g. 'ur-PK').
  /// Codes not listed here are passed through as-is and the engine
  /// decides; speakParts() then reports unavailable.
  static const Map<String, String> _locales = {
    'ur': 'ur-PK',
    'en': 'en-US',
    'ar': 'ar-SA',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'es': 'es-ES',
    'tr': 'tr-TR',
    'ru': 'ru-RU',
    'fa': 'fa-IR',
    'id': 'id-ID',
    'bn': 'bn-BD',
    'hi': 'hi-IN',
    'zh': 'zh-CN',
    'it': 'it-IT',
    'nl': 'nl-NL',
    'pt': 'pt-PT',
    'sv': 'sv-SE',
    'ms': 'ms-MY',
    'sw': 'sw-KE',
    'ta': 'ta-IN',
    'th': 'th-TH',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'pl': 'pl-PL',
    'no': 'nb-NO',
    'ro': 'ro-RO',
    'cs': 'cs-CZ',
    'bg': 'bg-BG',
    'bs': 'bs-BA',
    'sq': 'sq-AL',
    'si': 'si-LK',
    'my': 'my-MM',
    'gu': 'gu-IN',
    'vi': 'vi-VN',
    'yo': 'yo-NG',
    'om': 'om-ET',
    'ps': 'ps-AF',
    'sd': 'sd-PK',
    'ml': 'ml-IN',
    'ku': 'ku-TR',
    'tg': 'tg-TJ',
    'tt': 'tt-RU',
    'ug': 'ug-CN',
    'uz': 'uz-UZ',
    'az': 'az-AZ',
    'am': 'am-ET',
    'ha': 'ha-NG',
    'so': 'so-SO',
    'dv': 'dv-MV',
  };

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _configured = true;
    } catch (_) {
      // Best-effort: speaking still attempted below.
    }
  }

  /// Reads [parts] in order, one language at a time. Returns true
  /// if everything was read, false if stopped early or a part could
  /// not be spoken (missing voice / no TTS engine).
  Future<bool> speakParts(List<TtsPart> parts) async {
    final gen = ++_generation;
    await _ensureConfigured();
    try {
      final installed = await _installedLanguages();
      for (final part in parts) {
        if (gen != _generation) return false;
        final text = part.text.trim();
        if (text.isEmpty) continue;
        final locale = _locales[part.languageCode] ?? part.languageCode;
        if (!_languageUsable(installed, locale)) return false;
        await _tts.setLanguage(locale);
        if (gen != _generation) return false;
        await _tts.speak(text);
      }
      return gen == _generation;
    } catch (_) {
      return false;
    }
  }

  /// Stops any reading in progress.
  Future<void> stop() async {
    _generation++;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<Set<String>> _installedLanguages() async {
    try {
      final langs = await _tts.getLanguages;
      if (langs is List) {
        return langs.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  /// True when the engine lists the locale (or its language part),
  /// or when the list is unknown (empty) — then we try anyway
  /// instead of refusing outright.
  bool _languageUsable(Set<String> installed, String locale) {
    if (installed.isEmpty) return true;
    if (installed.contains(locale)) return true;
    final lang = locale.split('-').first.toLowerCase();
    return installed.any((l) {
      final lower = l.toLowerCase();
      return lower == lang || lower.startsWith('$lang-');
    });
  }
}
