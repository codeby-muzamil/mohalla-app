import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All user settings in one place, persisted with SharedPreferences.
/// Everything in here is stored ON THE PHONE ONLY — nothing is uploaded
/// anywhere (there is no backend until Firebase is added, see BUILD_NOTES).
///
/// LOCATION: there is no city any more — prayer times come from the
/// phone's GPS location (LocationService). Settings only holds the
/// calculation METHOD and the Asr madhab, which the user picks here.
class SettingsProvider extends ChangeNotifier {
  static const _kDark = 'dark_mode';
  static const _kElder = 'elder_mode';
  static const _kMethod = 'calculation_method';
  static const _kMadhab = 'asr_madhab';
  static const _kHijriAdj = 'hijri_adjustment';
  static const _kGeminiKey = 'gemini_api_key';
  static const _kVoice = 'muezzin_voice';
  static const _kReminder = 'reminder_minutes';
  static const _kNotifPrefix = 'notify_';
  static const _kQuranFont = 'quran_font';
  static const _kQuranSize = 'quran_font_size';
  static const _kQuranTheme = 'quran_theme';
  static const _kQuranTrans = 'quran_translation';
  static const _kMasjidPhoto = 'masjid_photo_path';
  static const _kMasjidName = 'masjid_name';
  static const _kMasjidTimings = 'masjid_timings_json';
  static const _kBoardPhoto = 'timings_board_photo_path';
  static const _kProfileName = 'profile_name';
  static const _kProfilePhoto = 'profile_photo_path';
  static const _kProfileGender = 'profile_gender';
  static const _kProfileDob = 'profile_dob';
  static const _kProfileEmail = 'profile_email';
  static const _kOnboarded = 'onboarded';
  static const _kBookmarks = 'quran_bookmarks';
  static const _kLastRead = 'quran_last_read';
  static const _kMushafPage = 'mushaf_page';

  bool darkMode = false;
  bool elderMode = false;

  /// Prayer calculation method id (see [calculationMethods]).
  /// Default 'karachi' (University of Islamic Sciences, Karachi).
  String calculationMethodId = 'karachi';

  /// Asr madhab id: 'hanafi' or 'shafi'. Default 'hanafi'.
  String madhabId = 'hanafi';

  /// Hijri date adjustment in days: -1, 0 or +1 (default 0). The
  /// Hijri date comes from the phone's Islamic calendar, but moon
  /// sighting can shift a date by a day vs the calculation — the
  /// user picks the shift in Settings and it applies everywhere
  /// the Hijri date is shown (Home header + calendar).
  int hijriAdjustment = 0;

  /// The user's own Gemini API key, pasted in Settings (AI Friend).
  /// Stored ONLY on this phone (SharedPreferences) — never uploaded,
  /// never written in source, never baked into the APK build. It is
  /// used in preference to the --dart-define key. Empty = no key.
  /// Note the honest limit: anyone with the phone can read a key
  /// stored on it, so this is for the owner's own key only.
  String geminiApiKey = '';

  /// The saved key, masked for display — only the last 4 characters
  /// are ever shown, never the full key, and the key is never logged.
  String get geminiApiKeyMasked {
    if (geminiApiKey.isEmpty) return '';
    if (geminiApiKey.length <= 4) return '••••';
    return '••••••••${geminiApiKey.substring(geminiApiKey.length - 4)}';
  }

  /// The 5 calculation methods offered in Settings (id, label,
  /// description). Ids are stored; the adhan enum lives behind
  /// [calculationMethod].
  static const List<(String, String, String)> calculationMethods = [
    (
      'karachi',
      'Karachi',
      'University of Islamic Sciences, Karachi',
    ),
    (
      'isna',
      'ISNA (North America)',
      'Islamic Society of North America',
    ),
    (
      'mwl',
      'Muslim World League',
      'Muslim World League',
    ),
    (
      'egypt',
      'Egyptian',
      'Egyptian General Authority of Survey',
    ),
    (
      'makkah',
      'Makkah (Umm al-Qura)',
      'Umm al-Qura University, Makkah',
    ),
  ];

  /// Asr options offered in Settings (id, label, description).
  static const List<(String, String, String)> asrMadhabs = [
    (
      'hanafi',
      'Hanafi',
      'Asr starts when the shadow is twice the object length',
    ),
    (
      'shafi',
      'Shafi\'i',
      'Asr starts when the shadow equals the object length',
    ),
  ];

  /// The adhan calculation method for [calculationMethodId].
  CalculationMethod get calculationMethod {
    switch (calculationMethodId) {
      case 'isna':
        return CalculationMethod.north_america;
      case 'mwl':
        return CalculationMethod.muslim_world_league;
      case 'egypt':
        return CalculationMethod.egyptian;
      case 'makkah':
        return CalculationMethod.umm_al_qura;
      case 'karachi':
      default:
        return CalculationMethod.karachi;
    }
  }

  /// The adhan madhab for [madhabId].
  Madhab get madhab =>
      madhabId == 'shafi' ? Madhab.shafi : Madhab.hanafi;

  /// Label of the selected calculation method (for notes + headers).
  String get calculationMethodLabel => calculationMethods
      .firstWhere(
        (m) => m.$1 == calculationMethodId,
        orElse: () => calculationMethods.first,
      )
      .$2;

  /// Label of the selected Asr madhab ('Hanafi' / 'Shafi'i').
  String get madhabLabel =>
      madhabId == 'shafi' ? 'Shafi\'i' : 'Hanafi';

  String muezzinVoice = 'afasy';
  int reminderMinutes = 10; // 0 = no reminder, else 5 or 10

  /// Per-prayer Azan notification toggles. Keys: fajr, dhuhr, asr, maghrib,
  /// isha, jumuah. All ON by default.
  Map<String, bool> notify = {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
    'jumuah': true,
  };

  String quranFont = 'Amiri'; // Amiri | ScheherazadeNew | Lateef | Default
  double quranFontSize = 26;
  String quranTheme = 'paper'; // see ReaderTheme ids
  String quranTranslation = 'both'; // urdu | english | both | off

  String masjidName = '';
  String? masjidPhotoPath; // local file path from image_picker, or null
  String? boardPhotoPath; // photo of the timings board, or null

  /// The user's own masjid Jamaat times (HH:mm, 24h). Empty = use the
  /// calculated Azan times. These are the times the user typed (or that
  /// the camera flow helped fill in) — never presented as verified.
  Map<String, String> masjidTimings = {};

  String profileName = '';
  String profileEmail = '';
  String profilePhotoPath = ''; // local file path, or '' when unset
  String profileGender = ''; // 'male' | 'female' | 'prefer_not' | ''
  String profileDob = ''; // ISO 'yyyy-MM-dd', or '' when unset

  /// Age in years from an ISO 'yyyy-MM-dd' birthday, or null when
  /// the birthday is empty or unparsable.
  static int? ageFromDob(String isoDob) {
    if (isoDob.isEmpty) return null;
    final dob = DateTime.tryParse(isoDob);
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Age in years from [profileDob], or null when no birthday is set.
  int? get profileAge => ageFromDob(profileDob);
  bool onboarded = false;

  Set<String> quranBookmarks = {}; // "surah:ayah" e.g. "2:255"
  String lastRead = ''; // "surah:ayah"
  int mushafPage = 1; // last-read 16-line Mushaf page (1..548)

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    darkMode = p.getBool(_kDark) ?? false;
    elderMode = p.getBool(_kElder) ?? false;
    calculationMethodId = p.getString(_kMethod) ?? 'karachi';
    if (!calculationMethods.any((m) => m.$1 == calculationMethodId)) {
      calculationMethodId = 'karachi';
    }
    madhabId = p.getString(_kMadhab) ?? 'hanafi';
    if (madhabId != 'hanafi' && madhabId != 'shafi') madhabId = 'hanafi';
    hijriAdjustment = p.getInt(_kHijriAdj) ?? 0;
    if (hijriAdjustment < -1 || hijriAdjustment > 1) hijriAdjustment = 0;
    geminiApiKey = p.getString(_kGeminiKey) ?? '';
    muezzinVoice = p.getString(_kVoice) ?? 'afasy';
    reminderMinutes = p.getInt(_kReminder) ?? 10;
    for (final k in notify.keys) {
      notify[k] = p.getBool('$_kNotifPrefix$k') ?? true;
    }
    quranFont = p.getString(_kQuranFont) ?? 'Amiri';
    quranFontSize = p.getDouble(_kQuranSize) ?? 26;
    quranTheme = p.getString(_kQuranTheme) ?? 'paper';
    quranTranslation = p.getString(_kQuranTrans) ?? 'both';
    masjidName = p.getString(_kMasjidName) ?? '';
    masjidPhotoPath = p.getString(_kMasjidPhoto);
    boardPhotoPath = p.getString(_kBoardPhoto);
    profileName = p.getString(_kProfileName) ?? '';
    profileEmail = p.getString(_kProfileEmail) ?? '';
    profilePhotoPath = p.getString(_kProfilePhoto) ?? '';
    profileGender = p.getString(_kProfileGender) ?? '';
    profileDob = p.getString(_kProfileDob) ?? '';
    onboarded = p.getBool(_kOnboarded) ?? false;
    quranBookmarks = (p.getStringList(_kBookmarks) ?? []).toSet();
    lastRead = p.getString(_kLastRead) ?? '';
    mushafPage = p.getInt(_kMushafPage) ?? 1;
    if (mushafPage < 1 || mushafPage > 548) mushafPage = 1;
    final timingsJson = p.getString(_kMasjidTimings);
    if (timingsJson != null) {
      try {
        final map = jsonDecode(timingsJson) as Map<String, dynamic>;
        masjidTimings = map.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        masjidTimings = {};
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kDark, darkMode);
    await p.setBool(_kElder, elderMode);
    await p.setString(_kMethod, calculationMethodId);
    await p.setString(_kMadhab, madhabId);
    await p.setInt(_kHijriAdj, hijriAdjustment);
    await p.setString(_kGeminiKey, geminiApiKey);
    await p.setString(_kVoice, muezzinVoice);
    await p.setInt(_kReminder, reminderMinutes);
    for (final e in notify.entries) {
      await p.setBool('$_kNotifPrefix${e.key}', e.value);
    }
    await p.setString(_kQuranFont, quranFont);
    await p.setDouble(_kQuranSize, quranFontSize);
    await p.setString(_kQuranTheme, quranTheme);
    await p.setString(_kQuranTrans, quranTranslation);
    await p.setString(_kMasjidName, masjidName);
    if (masjidPhotoPath != null) {
      await p.setString(_kMasjidPhoto, masjidPhotoPath!);
    }
    if (boardPhotoPath != null) {
      await p.setString(_kBoardPhoto, boardPhotoPath!);
    }
    await p.setString(_kProfileName, profileName);
    await p.setString(_kProfileEmail, profileEmail);
    await p.setString(_kProfilePhoto, profilePhotoPath);
    await p.setString(_kProfileGender, profileGender);
    await p.setString(_kProfileDob, profileDob);
    await p.setBool(_kOnboarded, onboarded);
    await p.setStringList(_kBookmarks, quranBookmarks.toList());
    await p.setString(_kLastRead, lastRead);
    await p.setInt(_kMushafPage, mushafPage);
    await p.setString(_kMasjidTimings, jsonEncode(masjidTimings));
  }

  void setDarkMode(bool v) {
    darkMode = v;
    _save();
    notifyListeners();
  }

  void setElderMode(bool v) {
    elderMode = v;
    _save();
    notifyListeners();
  }

  void setCalculationMethod(String id) {
    if (!calculationMethods.any((m) => m.$1 == id)) return;
    calculationMethodId = id;
    _save();
    notifyListeners();
  }

  void setMadhab(String id) {
    if (id != 'hanafi' && id != 'shafi') return;
    madhabId = id;
    _save();
    notifyListeners();
  }

  /// -1, 0 or +1. Anything else is ignored (clamped by init anyway).
  void setHijriAdjustment(int v) {
    if (v < -1 || v > 1) return;
    hijriAdjustment = v;
    _save();
    notifyListeners();
  }

  /// Save (or clear with '') the user's own Gemini API key. The
  /// value is trimmed; an empty key means "no key" (offline answers).
  void setGeminiApiKey(String v) {
    geminiApiKey = v.trim();
    _save();
    notifyListeners();
  }

  void setMuezzinVoice(String v) {
    muezzinVoice = v;
    _save();
    notifyListeners();
  }

  void setReminderMinutes(int v) {
    reminderMinutes = v;
    _save();
    notifyListeners();
  }

  void setNotify(String prayer, bool v) {
    notify[prayer] = v;
    _save();
    notifyListeners();
  }

  void setQuranFont(String v) {
    quranFont = v;
    _save();
    notifyListeners();
  }

  void setQuranFontSize(double v) {
    quranFontSize = v;
    _save();
    notifyListeners();
  }

  void setQuranTheme(String v) {
    quranTheme = v;
    _save();
    notifyListeners();
  }

  void setQuranTranslation(String v) {
    quranTranslation = v;
    _save();
    notifyListeners();
  }

  void setMasjidPhoto(String? path) {
    masjidPhotoPath = path;
    _save();
    notifyListeners();
  }

  void setBoardPhoto(String? path) {
    boardPhotoPath = path;
    _save();
    notifyListeners();
  }

  void setMasjidName(String name) {
    masjidName = name;
    _save();
    notifyListeners();
  }

  void setMasjidTimings(Map<String, String> timings) {
    masjidTimings = Map.of(timings);
    _save();
    notifyListeners();
  }

  void setProfile(String name, String email) {
    profileName = name;
    profileEmail = email;
    onboarded = true;
    _save();
    notifyListeners();
  }

  void setProfilePhoto(String path) {
    profilePhotoPath = path;
    _save();
    notifyListeners();
  }

  void setProfileGender(String v) {
    profileGender = v;
    _save();
    notifyListeners();
  }

  void setProfileDob(String v) {
    profileDob = v;
    _save();
    notifyListeners();
  }

  void toggleBookmark(String key) {
    if (quranBookmarks.contains(key)) {
      quranBookmarks.remove(key);
    } else {
      quranBookmarks.add(key);
    }
    _save();
    notifyListeners();
  }

  void setLastRead(String key) {
    lastRead = key;
    _save();
    notifyListeners();
  }

  void setMushafPage(int page) {
    mushafPage = page.clamp(1, 548);
    _save();
    notifyListeners();
  }
}

/// The 4 Azan voices bundled in assets/azan/ (verified Internet Archive
/// recordings — see assets/azan/README.md for sources).
/// NOTE: makkah.mp3 is a FAJR adhan (it includes "as-salatu khayrun
/// min an-nawm"); madinah.mp3 is an ASR adhan. Labels say so honestly.
class MuezzinVoice {
  final String id;
  final String label;
  final String asset; // assets/azan/<file> (without the leading assets/)
  final String rawName; // android res/raw name for notification sound
  final String note;

  const MuezzinVoice({
    required this.id,
    required this.label,
    required this.asset,
    required this.rawName,
    required this.note,
  });

  static const List<MuezzinVoice> all = [
    MuezzinVoice(
      id: 'afasy',
      label: 'Mishary Al-Afasy',
      asset: 'azan/afasy.mp3',
      rawName: 'afasy',
      note: 'Azan by a famous reciter (Internet Archive recording)',
    ),
    MuezzinVoice(
      id: 'qatami',
      label: 'Nasser Al-Qatami',
      asset: 'azan/qatami.mp3',
      rawName: 'qatami',
      note: 'Azan by Nasser Al-Qatami (Internet Archive recording)',
    ),
    MuezzinVoice(
      id: 'makkah',
      label: 'Makkah — Sheikh Yunus Khoja (Fajr)',
      asset: 'azan/makkah.mp3',
      rawName: 'makkah',
      note: 'Makkah Fajr Azan — includes "as-salatu khayrun min an-nawm"',
    ),
    MuezzinVoice(
      id: 'madinah',
      label: 'Madinah — Sheikh Surayhi (Asr)',
      asset: 'azan/madinah.mp3',
      rawName: 'madinah',
      note: 'Madinah Asr Azan (Internet Archive recording)',
    ),
  ];

  static MuezzinVoice byId(String id) =>
      all.firstWhere((v) => v.id == id, orElse: () => all.first);
}
