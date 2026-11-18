import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/settings_provider.dart';

/// Background entrypoint run by BootReceiver (Android) after a phone
/// restart. Reschedules today's Azan notifications from the saved
/// GPS location + saved method/madhab, WITHOUT opening the app UI.
///
/// Never throws and never opens the UI: if there is no cached
/// location (the app was never opened, or the cache was cleared),
/// it simply does nothing — the next app launch reschedules as
/// usual. The BootReceiver shuts the headless engine down after
/// ~20 seconds, so this must finish quickly (it only reads saved
/// settings and schedules notifications).
@pragma('vm:entry-point')
Future<void> bootReschedule() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (_) {}
  try {
    tzdata.initializeTimeZones();
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(LocationService.cacheKey);
    if (raw == null) return; // No location saved yet — nothing to do.
    final location = UserLocation.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    final settings = SettingsProvider();
    await settings.init();
    await NotificationService.init();
    await NotificationService.rescheduleAll(
      latitude: location.latitude,
      longitude: location.longitude,
      method: settings.calculationMethod,
      madhab: settings.madhab,
      notify: settings.notify,
      reminderMinutes: settings.reminderMinutes,
      voiceId: settings.muezzinVoice,
      customTimings: settings.masjidTimings,
    );
  } catch (_) {
    // Boot rescheduling must never crash the boot sequence.
  }
}
