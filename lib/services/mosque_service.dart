import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One mosque found near the user (OpenStreetMap data).
class NearbyMosque {
  final String name; // '' when the map has no name for it
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String address; // street, when mapped (may be '')

  const NearbyMosque({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.address,
  });

  /// 'Jamia Masjid Khizra' — or 'Masjid' when unnamed.
  String get displayName => name.isNotEmpty ? name : 'Masjid';

  /// '450 m' or '1.2 km'.
  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

/// Finds mosques around ([latitude], [longitude]) using the free
/// OpenStreetMap Overpass API — no API key, no account, no billing.
/// (Google Places would need a key + billing; this keeps the
/// feature free, like everything else in the app.)
///
/// Coverage is whatever the community has mapped: most named
/// mosques in a city are there, small unnamed ones may be missing,
/// and congregation (Iqama) times are NOT published anywhere, so
/// the list shows name + distance + direction only. Throws on
/// network failure or a bad response — the screen shows a retry.
Future<List<NearbyMosque>> fetchNearbyMosques({
  required double latitude,
  required double longitude,
  required double radiusKm,
}) async {
  final radiusM = (radiusKm * 1000).round();
  final query = '''
[out:json][timeout:25];
(
  node(around:$radiusM,$latitude,$longitude)[amenity=place_of_worship];
  way(around:$radiusM,$latitude,$longitude)[amenity=place_of_worship];
);
out center 60;
''';
  final res = await http
      .post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'data': query},
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw Exception('Overpass returned ${res.statusCode}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final elements = (data['elements'] as List?) ?? [];
  final distance = Distance();
  final here = LatLng(latitude, longitude);
  final seen = <String>{};
  final out = <NearbyMosque>[];
  for (final e in elements) {
    final el = e as Map<String, dynamic>;
    double? lat;
    double? lng;
    if (el['type'] == 'node') {
      lat = (el['lat'] as num?)?.toDouble();
      lng = (el['lon'] as num?)?.toDouble();
    } else {
      final center = el['center'] as Map<String, dynamic>?;
      lat = (center?['lat'] as num?)?.toDouble();
      lng = (center?['lon'] as num?)?.toDouble();
    }
    if (lat == null || lng == null) continue;
    final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
    // Keep mosques and untagged places of worship; drop other
    // religions' buildings (churches etc. are tagged as such).
    final religion = (tags['religion'] ?? '').toString();
    if (religion.isNotEmpty && religion != 'muslim') continue;
    // Same mosque mapped as both a node and a way: keep it once.
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (!seen.add(key)) continue;
    final name = (tags['name'] ?? tags['name:en'] ?? tags['name:ur'] ?? '')
        .toString();
    final street = (tags['addr:street'] ?? '').toString();
    final suburb = (tags['addr:suburb'] ?? '').toString();
    final address =
        [street, suburb].where((s) => s.isNotEmpty).join(', ');
    final km = distance.as(LengthUnit.Kilometer, here, LatLng(lat, lng));
    out.add(
      NearbyMosque(
        name: name,
        latitude: lat,
        longitude: lng,
        distanceKm: km,
        address: address,
      ),
    );
  }
  out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return out;
}

/// Compass direction from the user to a mosque ('NE', 'S', ...).
String compassDirection(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  final lat1 = fromLat * math.pi / 180;
  final lat2 = toLat * math.pi / 180;
  final dLng = (toLng - fromLng) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final brng = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[((brng + 22.5) / 45).floor() % 8];
}

/// One turn on a route ("Turn left onto Main Street", 120 m).
class RouteStep {
  final String instruction;
  final String roadName;
  final double distanceM;

  const RouteStep({
    required this.instruction,
    required this.roadName,
    required this.distanceM,
  });

  /// '120 m' or '1.2 km'.
  String get distanceLabel => distanceM < 1000
      ? '${distanceM.round()} m'
      : '${(distanceM / 1000).toStringAsFixed(1)} km';
}

/// A walking route to a mosque: path + distance + time + turns.
class RouteInfo {
  final double distanceKm;
  final double durationMin;
  final List<LatLng> points;
  final List<RouteStep> steps;

  const RouteInfo({
    required this.distanceKm,
    required this.durationMin,
    required this.points,
    required this.steps,
  });

  /// '1.2 km' / '14 min'.
  String get summaryLabel =>
      '${distanceKm < 1 ? '${(distanceKm * 1000).round()} m' : '${distanceKm.toStringAsFixed(1)} km'}'
      ' • ${durationMin < 1 ? '<1 min' : '${durationMin.round()} min walk'}';
}

/// Walking directions from ([fromLat], [fromLng]) to ([toLat], [toLng])
/// using the free OSRM router (OpenStreetMap data, no key). Tries the
/// walking profile first, falls back to driving if it fails. Returns
/// the route path (for the map), total distance/time, and turn-by-turn
/// steps. Throws on network failure or no route — the screen shows a
/// retry. Only the two coordinate pairs leave the phone, to OSRM.
Future<RouteInfo> fetchRoute({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) async {
  Object? lastError;
  // Walking first (mosques are usually walked to); driving fallback.
  for (final profile in ['foot', 'driving']) {
    try {
      return await _fetchRouteProfile(
        profile: profile,
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? Exception('No route found');
}

Future<RouteInfo> _fetchRouteProfile({
  required String profile,
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) async {
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/$profile/'
    '$fromLng,$fromLat;$toLng,$toLat'
    '?overview=full&geometries=geojson&steps=true',
  );
  final res = await http
      .get(uri, headers: {'User-Agent': 'Mohalla/1.0 (mohalla app)'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw Exception('OSRM returned ${res.statusCode}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final routes = (data['routes'] as List?) ?? [];
  if (routes.isEmpty) throw Exception('No route found');
  final r = routes.first as Map<String, dynamic>;
  final coords =
      ((r['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?) ??
          [];
  final points = <LatLng>[];
  for (final c in coords) {
    final p = c as List;
    // GeoJSON is [longitude, latitude].
    points.add(
      LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
    );
  }
  if (points.isEmpty) throw Exception('No route found');
  final steps = <RouteStep>[];
  final legs = (r['legs'] as List?) ?? [];
  if (legs.isNotEmpty) {
    final legSteps =
        ((legs.first as Map<String, dynamic>)['steps'] as List?) ?? [];
    for (final s in legSteps) {
      final sm = s as Map<String, dynamic>;
      final man = (sm['maneuver'] as Map<String, dynamic>?) ?? {};
      final instruction = (man['instruction'] as String?) ?? '';
      final road = (sm['name'] as String?) ?? '';
      final d = (sm['distance'] as num?)?.toDouble() ?? 0;
      if (instruction.isEmpty && road.isEmpty) continue;
      steps.add(
        RouteStep(
          instruction:
              instruction.isNotEmpty ? instruction : 'Continue on $road',
          roadName: road,
          distanceM: d,
        ),
      );
    }
  }
  return RouteInfo(
    distanceKm: ((r['distance'] as num?)?.toDouble() ?? 0) / 1000,
    durationMin: ((r['duration'] as num?)?.toDouble() ?? 0) / 60,
    points: points,
    steps: steps,
  );
}
