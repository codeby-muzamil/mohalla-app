import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../services/mosque_service.dart';
import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'location_screen.dart';

/// Nearby mosques — listed IN the app (no Google Maps any more):
/// a map with mosque pins, a list sorted by distance, and walking
/// directions (route on the map + turn-by-turn steps) when a mosque
/// is tapped. Data comes from OpenStreetMap (Overpass for the list,
/// OSRM for routes) — free, no API key. The user's own mosque card
/// is kept as-is. The list is only what OpenStreetMap has mapped:
/// small unnamed mosques may be missing, and congregation (Iqama)
/// times are not published anywhere, so none are shown.
class MosquesScreen extends StatefulWidget {
  const MosquesScreen({super.key});

  @override
  State<MosquesScreen> createState() => _MosquesScreenState();
}

class _MosquesScreenState extends State<MosquesScreen> {
  final MapController _mapController = MapController();
  List<NearbyMosque> _mosques = [];
  bool _loading = false;
  String _error = '';
  double _radiusKm = 5;
  NearbyMosque? _selected;
  RouteInfo? _route;
  bool _routeLoading = false;
  String _routeError = '';
  String _fetchKey = '';

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchMosques(double lat, double lng) async {
    final key =
        '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)},$_radiusKm';
    _fetchKey = key;
    setState(() {
      _loading = true;
      _error = '';
      _selected = null;
      _route = null;
      _routeError = '';
    });
    try {
      final list = await fetchNearbyMosques(
        latitude: lat,
        longitude: lng,
        radiusKm: _radiusKm,
      );
      if (!mounted) return;
      setState(() {
        _mosques = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not load mosques. Check your internet and try again.';
      });
    }
  }

  /// Selects a mosque and loads walking directions to it (in-app).
  Future<void> _selectMosque(
    NearbyMosque mosque,
    double fromLat,
    double fromLng,
  ) async {
    setState(() {
      _selected = mosque;
      _route = null;
      _routeError = '';
      _routeLoading = true;
    });
    _mapController.move(
      LatLng(mosque.latitude, mosque.longitude),
      15.0,
    );
    try {
      final route = await fetchRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: mosque.latitude,
        toLng: mosque.longitude,
      );
      if (!mounted) return;
      setState(() {
        // Keep it only if this mosque is still selected.
        if (_selected == mosque) {
          _route = route;
          _routeLoading = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_selected == mosque) {
          _routeLoading = false;
          _routeError =
              'Could not find a route. Check your internet and try again.';
        }
      });
    }
  }

  void _clearRoute() {
    setState(() {
      _selected = null;
      _route = null;
      _routeError = '';
      _routeLoading = false;
    });
  }

  Future<void> _openMasjidOnMaps(
    String masjidName,
    String place,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$masjidName $place')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

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
    final ink = isDark ? AppTheme.nightInk : AppTheme.ink;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;

    // Fetch when the location (or radius) changes — including when
    // GPS arrives after the screen opened, or the manual map pin moves.
    if (coords != null) {
      final key =
          '${coords.latitude.toStringAsFixed(4)},${coords.longitude.toStringAsFixed(4)},$_radiusKm';
      if (key != _fetchKey && !_loading) {
        _fetchKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _fetchMosques(coords.latitude, coords.longitude);
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SectionTitle(
            title: 'Nearby Mosques',
            subtitle: 'Mosques near you — listed in the app.',
          ),
        ),
        // Demo v13 Mosques: "Your mosque" card on top (name only —
        // Iqama times do not exist anywhere, so none are shown).
        if (settings.masjidName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.mosque, color: accent),
                ),
                title: Text(
                  settings.masjidName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    const Text('Your mosque · Your mohalla masjid'),
              ),
            ),
          ),
        if (coords == null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 44,
                        color: accent,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Location is needed to find mosques near you',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        location.message.isNotEmpty
                            ? location.message
                            : 'Allow location permission so the app can find mosques around you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GoldButton(
                            label: 'Enable location',
                            icon: Icons.my_location,
                            onPressed: () => location.refresh(),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      title: const Text('My Location'),
                                    ),
                                    body: const LocationScreen(),
                                  ),
                                ),
                              );
                            },
                            child: const Text('My Location'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Icon(Icons.my_location, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are in ${coords.displayName}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ---- Map with mosque pins + route ----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          coords.latitude,
                          coords.longitude,
                        ),
                        initialZoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.mohalla.app',
                        ),
                        if (_route != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _route!.points,
                                color: gold,
                                strokeWidth: 4,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                coords.latitude,
                                coords.longitude,
                              ),
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.my_location,
                                size: 28,
                                color: accent,
                              ),
                            ),
                            for (final m in _mosques)
                              Marker(
                                point: LatLng(m.latitude, m.longitude),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _selectMosque(
                                    m,
                                    coords.latitude,
                                    coords.longitude,
                                  ),
                                  child: Icon(
                                    Icons.location_pin,
                                    size: _selected == m ? 40 : 32,
                                    color:
                                        _selected == m ? gold : accent,
                                  ),
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
                        heroTag: 'recentre-mosques-map',
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
          // ---- Radius + refresh ----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                for (final r in [2.0, 5.0, 10.0])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${r.toInt()} km'),
                      selected: _radiusKm == r,
                      onSelected: (_) {
                        setState(() => _radiusKm = r);
                        _fetchMosques(
                          coords.latitude,
                          coords.longitude,
                        );
                      },
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading
                      ? null
                      : () => _fetchMosques(
                            coords.latitude,
                            coords.longitude,
                          ),
                ),
              ],
            ),
          ),
          // ---- List + directions ----
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Finding mosques near you…'),
                      ],
                    ),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted),
                              ),
                              const SizedBox(height: 12),
                              GoldButton(
                                label: 'Try again',
                                icon: Icons.refresh,
                                onPressed: () => _fetchMosques(
                                  coords.latitude,
                                  coords.longitude,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _mosques.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No mosques found within ${_radiusKm.toInt()} km — try a larger radius.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted),
                              ),
                            ),
                          )
                        : ListView(
                            padding:
                                const EdgeInsets.fromLTRB(20, 12, 20, 92),
                            children: [
                              // ---- Walking directions to the selected mosque ----
                              if (_selected != null) ...[
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Route to ${_selected!.displayName}',
                                                style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 16,
                                                  color: ink,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Clear route',
                                              icon:
                                                  const Icon(Icons.close),
                                              onPressed: _clearRoute,
                                            ),
                                          ],
                                        ),
                                        if (_routeLoading) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Finding the route…',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (_routeError.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            _routeError,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: muted,
                                            ),
                                          ),
                                        ] else if (_route != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _route!.summaryLabel,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: gold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          for (var i = 0;
                                              i < _route!.steps.length;
                                              i++)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    '${i + 1}.',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: gold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _route!.steps[i]
                                                          .instruction,
                                                      style: TextStyle(
                                                        color: ink,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _route!.steps[i]
                                                        .distanceLabel,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              // ---- The user's own mosque ----
                              if (settings.masjidName.isNotEmpty) ...[
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My mosque',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: ink,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          settings.masjidName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: ink,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Builder(
                                          builder: (context) {
                                            final now = DateTime.now();
                                            final times = PrayerService
                                                .effectiveTimesFor(
                                              coords.latitude,
                                              coords.longitude,
                                              DateTime(now.year, now.month,
                                                  now.day),
                                              method: settings
                                                  .calculationMethod,
                                              madhab: settings.madhab,
                                              custom:
                                                  settings.masjidTimings,
                                            );
                                            return Column(
                                              children: [
                                                for (final key in [
                                                  'fajr',
                                                  'dhuhr',
                                                  'asr',
                                                  'maghrib',
                                                  'isha',
                                                ])
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 2,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            PrayerService
                                                                    .prayerNamesEnglish[
                                                                key]!,
                                                            style: TextStyle(
                                                              color: ink,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          PrayerService
                                                              .formatTime(
                                                            times[key]!,
                                                          ),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                            color: ink,
                                                          ),
                                                        ),
                                                        if (settings
                                                                    .masjidTimings[
                                                                key] !=
                                                            null)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              left: 6,
                                                            ),
                                                            child: Text(
                                                              'My mosque',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: gold,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.map,
                                              size: 16),
                                          label:
                                              const Text('View on Maps'),
                                          onPressed: () =>
                                              _openMasjidOnMaps(
                                            settings.masjidName,
                                            coords.displayName,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              // ---- Mosque list ----
                              for (final m in _mosques) ...[
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: _selected == m
                                        ? BorderSide(
                                            color: gold, width: 2)
                                        : BorderSide.none,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _selectMosque(
                                      m,
                                      coords.latitude,
                                      coords.longitude,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.mosque,
                                            color: accent,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  m.displayName,
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${m.distanceLabel} • ${compassDirection(coords.latitude, coords.longitude, m.latitude, m.longitude)}'
                                                  '${m.address.isNotEmpty ? ' • ${m.address}' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: muted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              const SizedBox(height: 12),
                              const SampleNote(
                                text:
                                    'Mosque list comes from OpenStreetMap — some small mosques may be missing. Timings shown are your own mosque\'s settings — confirm the actual congregation times from the mosque notice board.',
                              ),
                            ],
                          ),
          ),
        ],
      ],
    );
  }
}
