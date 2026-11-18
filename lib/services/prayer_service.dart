import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/city.dart';

/// Prayer times, Qibla bearing and Makkah distance — all computed
/// ON-DEVICE from real coordinates. No internet needed.
///
/// TIME-ZONE RULE (this is the bug that bit the web prototype once):
/// the adhan package returns wall-clock times for the LOCATION. We never
/// display the phone's own local time. Every time is rebuilt as a
/// TZDateTime in the SELECTED city's IANA zone, so Hyderabad always shows
/// PKT (05:25 Fajr) even if the phone itself is set to UTC.
class PrayerService {
  static CalculationParameters _params() {
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    return params;
  }

  /// City time zone, falling back to Asia/Karachi if the saved zone string
  /// is unknown — a bad zone must never throw. (It used to crash the app
  /// right after login, when Azan scheduling runs.)
  static tz.Location _loc(CityPreset city) {
    try {
      return tz.getLocation(city.timeZone);
    } catch (_) {
      return tz.getLocation('Asia/Karachi');
    }
  }

  /// Prayer times for [city] on [date] (Gregorian date in that city).
  /// Keys: fajr, sunrise, dhuhr, asr, maghrib, isha — values are
  /// TZDateTime in the city's own time zone.
  static Map<String, tz.TZDateTime> timesFor(CityPreset city, DateTime date) {
    final loc = _loc(city);
    final components = DateComponents(date.year, date.month, date.day);
    final pt = PrayerTimes(
      Coordinates(city.latitude, city.longitude),
      components,
      _params(),
    );
    tz.TZDateTime inZone(DateTime dt) => tz.TZDateTime(
          loc,
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
        );
    return {
      'fajr': inZone(pt.fajr),
      'sunrise': inZone(pt.sunrise),
      'dhuhr': inZone(pt.dhuhr),
      'asr': inZone(pt.asr),
      'maghrib': inZone(pt.maghrib),
      'isha': inZone(pt.isha),
    };
  }

  /// Calculated times with the user's own masjid times applied on top.
  /// [custom] maps prayer key -> 'HH:mm' (24h), as stored by
  /// SettingsProvider.masjidTimings. Sunrise is never overridden.
  /// A 'jumuah' entry overrides Dhuhr on Fridays only. Invalid or
  /// missing entries are ignored (calculated time stays).
  static Map<String, tz.TZDateTime> effectiveTimesFor(
    CityPreset city,
    DateTime date, [
    Map<String, String> custom = const {},
  ]) {
    final times = timesFor(city, date);
    if (custom.isEmpty) return times;
    final loc = _loc(city);
    for (final e in custom.entries) {
      if (e.key == 'sunrise') continue;
      final parts = e.value.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        continue;
      }
      final at = tz.TZDateTime(loc, date.year, date.month, date.day, h, m);
      if (e.key == 'jumuah') {
        if (date.weekday == DateTime.friday) times['dhuhr'] = at;
        continue;
      }
      if (!times.containsKey(e.key)) continue;
      times[e.key] = at;
    }
    return times;
  }

  /// "Now" in the city's time zone.
  static tz.TZDateTime nowIn(CityPreset city) =>
      tz.TZDateTime.now(_loc(city));

  /// The next prayer after [now] (today, else tomorrow's Fajr).
  /// Returns (key, time). Sunrise is never a "next prayer" for countdown.
  static MapEntry<String, tz.TZDateTime> nextPrayer(
    CityPreset city,
    tz.TZDateTime now,
  ) {
    return nextPrayerWith(city, now);
  }

  /// Same as [nextPrayer] but with the user's own masjid times applied
  /// (see [effectiveTimesFor]). Home countdown + Azan use this one.
  static MapEntry<String, tz.TZDateTime> nextPrayerWith(
    CityPreset city,
    tz.TZDateTime now, [
    Map<String, String> custom = const {},
  ]) {
    final today = effectiveTimesFor(
      city,
      DateTime(now.year, now.month, now.day),
      custom,
    );
    const order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (final key in order) {
      if (today[key]!.isAfter(now)) {
        return MapEntry(key, today[key]!);
      }
    }
    final tomorrow = now.add(const Duration(days: 1));
    final t = effectiveTimesFor(
      city,
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      custom,
    );
    return MapEntry('fajr', t['fajr']!);
  }

  static String formatTime(tz.TZDateTime dt) =>
      DateFormat('h:mm a').format(dt);

  static String formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  static const Map<String, String> prayerNamesEnglish = {
    'fajr': 'Fajr',
    'sunrise': 'Sunrise',
    'dhuhr': 'Dhuhr',
    'asr': 'Asr',
    'maghrib': 'Maghrib',
    'isha': 'Isha',
    'jumuah': 'Jumu\'ah',
  };

  /// Qibla bearing from [city] to the Kaaba (21.4225 N, 39.8262 E),
  /// great-circle formula. Hyderabad = 267 degrees (west).
  static double qiblaBearing(CityPreset city) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;
    final lat1 = city.latitude * math.pi / 180;
    final lng1 = city.longitude * math.pi / 180;
    final lat2 = kaabaLat * math.pi / 180;
    final lng2 = kaabaLng * math.pi / 180;
    final dLng = lng2 - lng1;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    var bearing = math.atan2(y, x) * 180 / math.pi;
    bearing = (bearing + 360) % 360;
    return bearing;
  }

  /// Great-circle distance from [city] to the Kaaba, in kilometres.
  static double distanceToMakkahKm(CityPreset city) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;
    const r = 6371.0;
    final lat1 = city.latitude * math.pi / 180;
    final lat2 = kaabaLat * math.pi / 180;
    final dLat = (kaabaLat - city.latitude) * math.pi / 180;
    final dLng = (kaabaLng - city.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
