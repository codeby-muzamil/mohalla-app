import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/location_service.dart';
import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// My Location: a full map (OpenStreetMap, free — no API key) plus
/// today's prayer times and the Qibla bearing at the shown location.
///
/// GPS is the default. Tapping anywhere on the map pins a MANUAL
/// location: prayer times, Qibla, mosques, Azan and the countdown
/// all switch to the pin at once, until "Use GPS location" is
/// pressed. A place search (OpenStreetMap Nominatim, free) moves
/// the map and pins the chosen place. The pin is stored on the
/// phone only, never uploaded. A VPN does NOT move GPS (GPS comes
/// from satellites, not the network); the map pin is the way to
/// check another place on purpose.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

/// One place-search hit (OpenStreetMap Nominatim).
class _PlaceResult {
  final String name;
  final double latitude;
  final double longitude;

  const _PlaceResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// 'Hyderabad, Sindh, Pakistan' — the first two parts are enough.
  String get shortName {
    final parts = name.split(',').map((p) => p.trim()).toList();
    return parts.take(2).join(', ');
  }
}

class _LocationScreenState extends State<LocationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _clockTimer;
  List<_PlaceResult> _searchResults = [];
  bool _searching = false;
  String _searchMessage = '';
  bool _searchWasEmpty = true;

  /// Hyderabad — the map's fallback centre when no location is known yet.
  static const _defaultCentre = LatLng(25.3960, 68.3578);

  @override
  void initState() {
    super.initState();
    // Show/hide the search clear button as the user types.
    _searchController.addListener(() {
      final empty = _searchController.text.isEmpty;
      if (empty != _searchWasEmpty) {
        _searchWasEmpty = empty;
        if (mounted) setState(() {});
      }
    });
    // Keep the "last updated" time fresh once a minute.
    _clockTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Searches places via OpenStreetMap Nominatim (free, no key).
  Future<void> _searchPlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchMessage = '';
      _searchResults = [];
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'q': q,
      });
      final res = await http
          .get(uri, headers: {'User-Agent': 'Mohalla/1.0 (mohalla app)'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('search failed');
      final list = jsonDecode(res.body) as List;
      final results = <_PlaceResult>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final lat = double.tryParse('${m['lat']}');
        final lng = double.tryParse('${m['lon']}');
        final name = (m['display_name'] as String?) ?? '';
        if (lat != null && lng != null && name.isNotEmpty) {
          results.add(
            _PlaceResult(name: name, latitude: lat, longitude: lng),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        if (results.isEmpty) _searchMessage = 'No places found for "$q".';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchMessage =
            'Search needs internet. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// A tap on the map pins a manual location there.
  Future<void> _onMapTap(LatLng point) async {
    await context
        .read<LocationService>()
        .setManualLocation(point.latitude, point.longitude);
  }

  /// Moves the map to a searched place and pins it.
  Future<void> _pickSearchResult(_PlaceResult place) async {
    _mapController.move(LatLng(place.latitude, place.longitude), 13.0);
    setState(() {
      _searchResults = [];
      _searchController.text = place.shortName;
    });
    await context
        .read<LocationService>()
        .setManualLocation(place.latitude, place.longitude);
  }

  /// Drops the manual pin, goes back to GPS, and centres the map there.
  Future<void> _useGps() async {
    final location = context.read<LocationService>();
    await location.clearManualLocation();
    if (!mounted) return;
    final coords = location.current;
    if (coords != null) {
      _mapController.move(LatLng(coords.latitude, coords.longitude), 13.0);
    }
  }

  /// Centres the map on the current (GPS or manual) location.
  void _recentre(UserLocation? coords) {
    if (coords == null) return;
    _mapController.move(LatLng(coords.latitude, coords.longitude), 13.0);
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationService>();
    final settings = context.watch<SettingsProvider>();
    final coords = location.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final centre = coords != null
        ? LatLng(coords.latitude, coords.longitude)
        : _defaultCentre;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SectionTitle(
            title: 'My Location',
            subtitle: location.isManual
                ? 'Manual location (set on the map). Tap "Use GPS location" to go back to GPS.'
                : 'Tap the map to set a location, or use your phone\'s GPS.',
          ),
        ),
        // ---- Place search ----
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchPlaces,
                  decoration: InputDecoration(
                    hintText: 'Search a place or city…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _searchMessage = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Search',
                onPressed:
                    _searching ? null : () => _searchPlaces(_searchController.text),
                icon: _searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),
        ),
        if (_searchMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              _searchMessage,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: muted.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                for (final r in _searchResults)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place, size: 20),
                    title: Text(r.shortName),
                    subtitle: Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    onTap: () => _pickSearchResult(r),
                  ),
              ],
            ),
          ),
        // ---- The map ----
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 340,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: centre,
                      initialZoom: coords != null ? 13.0 : 6.0,
                      onTap: (_, point) => _onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mohalla.app',
                      ),
                      if (coords != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                coords.latitude,
                                coords.longitude,
                              ),
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.location_pin,
                                size: 40,
                                color:
                                    location.isManual ? gold : accent,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'recentre-map',
                      tooltip: 'Go to my location',
                      onPressed: () => _recentre(coords),
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ---- Details below the map ----
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- Location status card ----
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (coords == null
                                        ? Colors.red
                                        : accent)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                coords == null
                                    ? Icons.location_off
                                    : Icons.location_on,
                                color:
                                    coords == null ? Colors.red : accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                coords == null
                                    ? 'Location not available'
                                    : coords.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (coords != null) ...[
                          const SizedBox(height: 4),
                          Text(coords.coordinatesLabel),
                          Text(
                            'Last updated: '
                            '${DateFormat('h:mm a').format(coords.updatedAt)}'
                            '${coords.fromCache ? ' (last known location)' : ''}'
                            '${location.isManual ? ' • Manual location' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ],
                        if (location.message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            location.message,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            GoldButton(
                              label: 'Refresh location',
                              icon: Icons.refresh,
                              onPressed: () => location.refresh(),
                            ),
                            if (location.isManual)
                              GoldButton(
                                label: 'Use GPS location',
                                icon: Icons.my_location,
                                onPressed: _useGps,
                              ),
                            if (location.status ==
                                LocationStatus.permissionDeniedForever)
                              GoldButton(
                                label: 'Open settings',
                                icon: Icons.settings,
                                onPressed: () => location.openSettings(),
                              ),
                            if (location.status ==
                                LocationStatus.serviceDisabled)
                              GoldButton(
                                label: 'Open location settings',
                                icon: Icons.location_on,
                                onPressed: () =>
                                    location.openLocationSettings(),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (coords != null) ...[
                  // ---- Today's prayer times at this location ----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TODAY\'S PRAYER TIMES HERE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.1,
                              color: gold,
                            ),
                          ),
                          Text(
                            '${settings.calculationMethodLabel} method, '
                            '${settings.madhabLabel} Asr'
                            '${settings.masjidTimings.isNotEmpty ? ' • My mosque timings' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final now = DateTime.now();
                              final times =
                                  PrayerService.effectiveTimesFor(
                                coords.latitude,
                                coords.longitude,
                                DateTime(now.year, now.month, now.day),
                                method: settings.calculationMethod,
                                madhab: settings.madhab,
                                custom: settings.masjidTimings,
                              );
                              return Column(
                                children: [
                                  for (final key in [
                                    'fajr',
                                    'dhuhr',
                                    'asr',
                                    'maghrib',
                                    'isha',
                                  ]) ...[
                                    Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              PrayerService
                                                  .prayerNamesEnglish[key]!,
                                            ),
                                          ),
                                          Text(
                                            PrayerService.formatTime(
                                                times[key]!),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (key != 'isha') const Divider(height: 1),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ---- Qibla from here ----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QIBLA FROM HERE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.1,
                              color: gold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bearing: ${PrayerService.qiblaBearing(coords.latitude, coords.longitude).toStringAsFixed(0)}° • '
                            'Distance to Makkah: ${PrayerService.distanceToMakkahKm(coords.latitude, coords.longitude).toStringAsFixed(0)} km',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const SampleNote(
                  text:
                      'Tap the map (or search a place) to set a manual location — prayer times, Qibla, mosques and Azan all use it until you press "Use GPS location". Your location is stored only on this phone, never sent anywhere. A VPN does not move GPS: GPS comes from satellites, so the map pin is the way to check another place.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
