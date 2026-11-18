import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/city.dart';
import 'prayer_service.dart';
import 'settings_provider.dart';

/// Azan notifications + in-app Azan.
///
/// TWO layers (be honest about what each can do):
/// 1. SCHEDULED notifications (flutter_local_notifications, exact alarms):
///    fire even when the app is closed. On Android 12+ the user must allow
///    exact alarms; on Android 13+ the user must allow notifications.
///    The sound is the selected muezzin voice — the MP3 must ALSO exist in
///    android/app/src/main/res/raw/ (see assets/azan/README.md).
/// 2. IN-APP Azan: while the app is open, a timer checks every 30 seconds
///    and, at prayer time, shows a banner and plays the Azan audio.
///    This layer is what you can test immediately in `flutter run`.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _player = AudioPlayer();

  static bool _initialised = false;

  /// Call once from main(). Returns true when the plugin initialised.
  static Future<bool> init() async {
    if (_initialised) return true;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings: settings);
      _initialised = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ask Android 13+ for notification permission and Android 12+ for
  /// exact-alarm permission. Call from Settings when the user enables Azan.
  static Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  /// Schedules today's Azan for every enabled prayer in [city], plus a
  /// reminder [reminderMinutes] before (0 = none). Old schedules are
  /// cancelled first. Call on app start and whenever the city, the
  /// toggles, the reminder or the voice changes. [customTimings] are
  /// the user's own masjid times (SettingsProvider.masjidTimings) —
  /// Azan fires at the masjid time when one is set.
  static Future<void> rescheduleAll({
    required CityPreset city,
    required Map<String, bool> notify,
    required int reminderMinutes,
    required String voiceId,
    Map<String, String> customTimings = const {},
  }) async {
    if (!_initialised) return;
    // Azan scheduling must never crash the app: this runs unawaited from
    // RootScreen.initState right after login, so any failure is swallowed.
    try {
      await _plugin.cancelAll();
      final voice = MuezzinVoice.byId(voiceId);
      final now = PrayerService.nowIn(city);
      final today = PrayerService.effectiveTimesFor(
        city,
        DateTime(now.year, now.month, now.day),
        customTimings,
      );
      const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
      var id = 1;
      for (final key in prayers) {
        if (notify[key] != true) continue;
        final time = today[key]!;
        if (time.isAfter(now)) {
          await _scheduleOne(
            id++,
            key,
            time,
            voice,
            isReminder: false,
          );
        }
        if (reminderMinutes > 0 && notify[key] == true) {
          final rem = time.subtract(Duration(minutes: reminderMinutes));
          if (rem.isAfter(now)) {
            await _scheduleOne(id++, key, rem, voice, isReminder: true);
          }
        }
      }
      // Jumu'ah reminder (Friday Dhuhr) — same Dhuhr slot, labelled Jumu'ah.
      if (notify['jumuah'] == true && now.weekday == DateTime.friday) {
        final dhuhr = today['dhuhr']!;
        if (dhuhr.isAfter(now)) {
          await _scheduleOne(id++, 'jumuah', dhuhr, voice, isReminder: false);
        }
      }
    } catch (_) {
      // Scheduling failed (bad zone, plugin error) — skip Azan silently.
    }
  }

  static Future<void> _scheduleOne(
    int id,
    String prayerKey,
    tz.TZDateTime when,
    MuezzinVoice voice, {
    required bool isReminder,
  }) async {
    final name = PrayerService.prayerNamesEnglish[prayerKey] ?? prayerKey;
    final title = isReminder ? '$name prayer reminder' : 'Azan — $name';
    final body = isReminder
        ? 'Time for $name prayer is near'
        : 'Time for $name prayer — Azan';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mohalla_azan',
        'Azan',
        channelDescription: 'Azan notification at prayer time',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound(voice.rawName),
        playSound: true,
      ),
    );
    try {
      // flutter_local_notifications 23.x: zonedSchedule takes only
      // NAMED arguments, and uiLocalNotificationDateInterpretation
      // was removed from the package entirely.
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Scheduling failed (e.g. exact alarms not allowed) — the in-app
      // Azan layer still works while the app is open.
    }
  }

  /// Plays the selected muezzin voice now (used by the in-app Azan banner
  /// and the Settings "sunn kar dekhein" test button).
  static Future<bool> playAzan(String voiceId) async {
    final voice = MuezzinVoice.byId(voiceId);
    try {
      await _player.stop();
      // just_audio needs the full asset path (with the assets/ prefix);
      // MuezzinVoice.asset stores it without the prefix ('azan/afasy.mp3').
      await _player.setAsset('assets/${voice.asset}');
      await _player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopAzan() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// In-app Azan watcher: checks every 30 seconds while the app is open.
  /// When a prayer time arrives, calls [onAzan] once for that prayer.
  /// Returns the timer so the caller can cancel it. [getCustomTimings]
  /// supplies the user's own masjid times, if any.
  static Timer startInAppWatcher({
    required CityPreset Function() getCity,
    required Map<String, bool> Function() getNotify,
    required void Function(String prayerKey) onAzan,
    Map<String, String> Function()? getCustomTimings,
  }) {
    String lastFired = '';
    return Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        final city = getCity();
        final notify = getNotify();
        final now = PrayerService.nowIn(city);
        final today = PrayerService.effectiveTimesFor(
          city,
          DateTime(now.year, now.month, now.day),
          getCustomTimings?.call() ?? const {},
        );
        const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
        for (final key in prayers) {
          if (notify[key] != true) continue;
          final t = today[key]!;
          final key2 =
              '${now.year}-${now.month}-${now.day}-$key';
          if (key2 == lastFired) continue;
          if (!now.isBefore(t) &&
              now.difference(t) < const Duration(minutes: 1)) {
            lastFired = key2;
            onAzan(key);
          }
        }
      } catch (_) {
        // Watcher must never crash the app — skip this tick.
      }
    });
  }
}
