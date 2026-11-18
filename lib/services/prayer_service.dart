import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

/// Prayer times, Qibla bearing and Makkah distance — all computed
/// ON-DEVICE from the phone's GPS coordinates. No internet needed.
///
/// GPS RULE: every method takes raw coordinates (latitude, longitude)
/// from LocationService. The adhan package returns wall-clock times
/// for the LOCATION in the phone's own local time — we display them
/// exactly as returned (DateTime.now() is the same clock), never
/// re-interpreted into another time zone. There is no city picker
/// any more: the coordinates come from GPS, the method/madhab from
/// SettingsProvider (calculationMethod / madhab).
class PrayerService {
  static CalculationParameters _params(
    CalculationMethod method,
    Madhab madhab,
  ) {
    final params = method.getParameters();
    params.madhab = madhab;
    return params;
  }

  /// Prayer times at ([latitude], [longitude]) on [date].
  /// Keys: fajr, sunrise, dhuhr, asr, maghrib, isha — values are
  /// DateTime in the phone's local time.
  static Map<String, DateTime> timesFor(
    double latitude,
    double longitude,
    DateTime date, {
    required CalculationMethod method,
    required Madhab madhab,
  }) {
    final components = DateComponents(date.year, date.month, date.day);
    final pt = PrayerTimes(
      Coordinates(latitude, longitude),
      components,
      _params(method, madhab),
    );
    return {
      'fajr': pt.fajr,
      'sunrise': pt.sunrise,
      'dhuhr': pt.dhuhr,
      'asr': pt.asr,
      'maghrib': pt.maghrib,
      'isha': pt.isha,
    };
  }

  /// Calculated times with the user's own masjid times applied on top.
  /// [custom] maps prayer key -> 'HH:mm' (24h), as stored by
  /// SettingsProvider.masjidTimings. Sunrise is never overridden.
  /// A 'jumuah' entry overrides Dhuhr on Fridays only. Invalid or
  /// missing entries are ignored (calculated time stays).
  static Map<String, DateTime> effectiveTimesFor(
    double latitude,
    double longitude,
    DateTime date, {
    required CalculationMethod method,
    required Madhab madhab,
    Map<String, String> custom = const {},
  }) {
    final times = timesFor(
      latitude,
      longitude,
      date,
      method: method,
      madhab: madhab,
    );
    if (custom.isEmpty) return times;
    for (final e in custom.entries) {
      if (e.key == 'sunrise') continue;
      final parts = e.value.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        continue;
      }
      final at = DateTime(date.year, date.month, date.day, h, m);
      if (e.key == 'jumuah') {
        if (date.weekday == DateTime.friday) times['dhuhr'] = at;
        continue;
      }
      if (!times.containsKey(e.key)) continue;
      times[e.key] = at;
    }
    return times;
  }

  /// "Now" on the phone's own clock.
  static DateTime nowIn() => DateTime.now();

  /// The next prayer after [now] (today, else tomorrow's Fajr).
  /// Returns (key, time). Sunrise is never a "next prayer" for countdown.
  static MapEntry<String, DateTime> nextPrayer(
    double latitude,
    double longitude,
    DateTime now, {
    required CalculationMethod method,
    required Madhab madhab,
  }) {
    return nextPrayerWith(
      latitude,
      longitude,
      now,
      method: method,
      madhab: madhab,
    );
  }

  /// Same as [nextPrayer] but with the user's own masjid times applied
  /// (see [effectiveTimesFor]). Home countdown + Azan use this one.
  static MapEntry<String, DateTime> nextPrayerWith(
    double latitude,
    double longitude,
    DateTime now, {
    required CalculationMethod method,
    required Madhab madhab,
    Map<String, String> custom = const {},
  }) {
    final today = effectiveTimesFor(
      latitude,
      longitude,
      DateTime(now.year, now.month, now.day),
      method: method,
      madhab: madhab,
      custom: custom,
    );
    const order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (final key in order) {
      if (today[key]!.isAfter(now)) {
        return MapEntry(key, today[key]!);
      }
    }
    final tomorrow = now.add(const Duration(days: 1));
    final t = effectiveTimesFor(
      latitude,
      longitude,
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      method: method,
      madhab: madhab,
      custom: custom,
    );
    return MapEntry('fajr', t['fajr']!);
  }

  static String formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

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

  /// Qibla bearing from ([latitude], [longitude]) to the Kaaba
  /// (21.4225 N, 39.8262 E), great-circle formula.
  static double qiblaBearing(double latitude, double longitude) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;
    final lat1 = latitude * math.pi / 180;
    final lng1 = longitude * math.pi / 180;
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

  /// Great-circle distance from ([latitude], [longitude]) to the
  /// Kaaba, in kilometres.
  static double distanceToMakkahKm(double latitude, double longitude) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;
    const r = 6371.0;
    final lat1 = latitude * math.pi / 180;
    final lat2 = kaabaLat * math.pi / 180;
    final dLat = (kaabaLat - latitude) * math.pi / 180;
    final dLng = (kaabaLng - longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
