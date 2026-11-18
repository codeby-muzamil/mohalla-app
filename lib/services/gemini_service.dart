import 'package:google_generative_ai/google_generative_ai.dart';

/// AI Dost — the in-app AI helper.
///
/// SECURITY RULE (non-negotiable): the Gemini API key is NEVER baked
/// into the APK or written in source code. Two ways to supply it:
///   1. At BUILD time: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY
///      (the owner's own testing only).
///   2. In the app: Settings → AI Friend (Gemini) — the user pastes
///      their own key, stored ONLY on their phone (SharedPreferences
///      via SettingsProvider). The in-app key wins over the build-time
///      one. Anyone can extract a key baked into an APK, so a baked-in
///      key would be stolen and abused. The proper production setup
///      is a small server / Firebase Function that holds the key
///      (see BUILD_NOTES.md).
///
/// When no key is supplied, the bot answers a few built-in questions
/// offline and says plainly that Gemini is not connected.
class GeminiService {
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Key pasted by the user in Settings (set once from main() after
  /// SettingsProvider.init, and again whenever the user saves a new
  /// key). Never logged, never shown back in full anywhere.
  static String _runtimeKey = '';

  static void setRuntimeKey(String key) {
    _runtimeKey = key.trim();
  }

  /// The in-app key wins; the --dart-define key is the fallback.
  static String get _effectiveKey =>
      _runtimeKey.isNotEmpty ? _runtimeKey : _apiKey;

  static bool get hasKey => _effectiveKey.isNotEmpty;

  static const Map<String, String> offlineAnswers = {
    'zakat':
        'Zakat: 2.5% is due on wealth held for a full year (cash, gold, silver, trade goods) once it reaches the nisab (the value of 52.5 tola silver or 7.5 tola gold). Calculate it with the Zakat Calculator in the app.',
    'namaz':
        'The 5 obligatory prayer times are: Fajr, Dhuhr, Asr, Maghrib, Isha. Today\'s times are on the Home screen. How to pray is shown step by step in the Learn section.',
    'roza':
        'Fasting: from Fajr (Sehri) to Maghrib (Iftar), abstain from food, drink and anything that breaks the fast. Ramadan times appear on Home as Sehri/Iftar.',
    'wudu':
        'How to perform Wudu is in the Learn section: intention, hands, rinsing the mouth, nose, face, arms, wiping the head, ears, feet — every step is animated.',
  };

  static String offlineAnswer(String question) {
    final q = question.toLowerCase();
    for (final entry in offlineAnswers.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return 'No offline answer for this question. To connect Gemini, paste your key in Settings → AI Friend (Gemini), or build with --dart-define=GEMINI_API_KEY=... (see README).';
  }

  /// Ask Gemini. Returns the answer text, or an honest message when the
  /// key is missing / the call fails.
  static Future<String> ask(String question) async {
    if (!hasKey) return offlineAnswer(question);
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _effectiveKey,
      );
      final prompt =
          'You are AI Friend, a helpful Islamic assistant in the Mohalla app. '
          'Answer briefly and accurately in English. '
          'Never invent a hadith reference or Quran '
          'verse number; if unsure, say so. Question: $question';
      final response =
          await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return 'No answer from Gemini — please try again.';
      }
      return text.trim();
    } catch (e) {
      return 'Could not reach Gemini ($e). Check your internet and API key.';
    }
  }
}
