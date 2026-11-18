import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/city.dart';

/// All user settings in one place, persisted with SharedPreferences.
/// Everything in here is stored ON THE PHONE ONLY — nothing is uploaded
/// anywhere (there is no backend until Firebase is added, see BUILD_NOTES).
class SettingsProvider extends ChangeNotifier {
  static const _kDark = 'dark_mode';
  static const _kElder = 'elder_mode';
  static const _kCity = 'city_json';
  static const _kAutoTz = 'auto_timezone';
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
  CityPreset city = presetCities.first; // Hyderabad default
  bool autoTimezone = false;
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
    autoTimezone = p.getBool(_kAutoTz) ?? false;
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
    final cityJson = p.getString(_kCity);
    if (cityJson != null) {
      try {
        city = CityPreset.fromJson(
          jsonDecode(cityJson) as Map<String, dynamic>,
        );
      } catch (_) {
        city = presetCities.first;
      }
    }
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
    await p.setBool(_kAutoTz, autoTimezone);
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
    await p.setString(_kCity, jsonEncode(city.toJson()));
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

  void setCity(CityPreset c) {
    city = c;
    autoTimezone = false;
    // A different city means different Jamaat times: clear the old
    // masjid's manual timings so they are never shown for the new city.
    masjidTimings = {};
    _save();
    notifyListeners();
  }

  void setAutoTimezone(bool v) {
    autoTimezone = v;
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
