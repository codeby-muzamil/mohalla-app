import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The phone's location, shared by every location-dependent feature:
/// prayer times, nearby mosques, Qibla bearing/distance, Azan,
/// countdown and the header place name.
///
/// GPS is the default. The user can also pin a MANUAL location on
/// the map (My Location screen): the pin wins over GPS everywhere
/// until it is cleared ("Use GPS location"). The last good GPS fix
/// is cached on the phone ('last_location_json') so the app still
/// shows timings when GPS is briefly unavailable; a cached location
/// is always labelled as "last known location", never presented as
/// a fresh fix. Location never leaves the phone: no coordinates are
/// uploaded anywhere (there is no backend). A VPN does NOT move GPS
/// — GPS comes from satellites, not the network — which is why the
/// map pin exists: it is the way to check another place on purpose.
enum LocationStatus {
  unknown,
  ready,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  error,
}

class UserLocation {
  final double latitude;
  final double longitude;
  final String cityName; // e.g. 'Hyderabad' (may be '')
  final String country; // e.g. 'Pakistan' (may be '')
  final DateTime updatedAt;

  /// True when this is the cached last-known location, not a fresh
  /// GPS fix.
  final bool fromCache;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.cityName,
    required this.country,
    required this.updatedAt,
    this.fromCache = false,
  });

  /// 'Hyderabad, Pakistan' — or 'Your location' when the place name
  /// is unknown (reverse geocoding can come back empty).
  String get displayName {
    if (cityName.isNotEmpty && country.isNotEmpty) {
      return '$cityName, $country';
    }
    if (cityName.isNotEmpty) return cityName;
    return 'Your location';
  }

  /// '25.39°, 68.37°' — shown under the place name.
  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(2)}°, ${longitude.toStringAsFixed(2)}°';

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'cityName': cityName,
        'country': country,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserLocation.fromJson(Map<String, dynamic> json) =>
      UserLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        cityName: json['cityName'] as String? ?? '',
        country: json['country'] as String? ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        fromCache: true,
      );
}

class LocationService extends ChangeNotifier {
  /// SharedPreferences key for the cached last-known location.
  /// Also read by the BOOT_COMPLETED background entrypoint
  /// (lib/boot_reschedule.dart), which runs without this instance.
  static const cacheKey = 'last_location_json';
  static const _kLastLocation = cacheKey;

  /// SharedPreferences key for the manual map pin.
  static const _kManualLocation = 'manual_location_json';

  /// The fresh GPS fix (null until the first fix arrives).
  UserLocation? _gps;

  /// The manual pin set on the map (null when the user uses GPS).
  /// Stored on the phone only.
  UserLocation? manualLocation;

  /// The location the app actually uses: the manual pin when one
  /// is set, otherwise the GPS fix. Every reader (Home, Qibla,
  /// mosques, Azan scheduling, header) goes through this getter,
  /// so a manual pin takes effect everywhere at once.
  UserLocation? get current => manualLocation ?? _gps;

  /// True when a manual pin from the map is active.
  bool get isManual => manualLocation != null;

  LocationStatus status = LocationStatus.unknown;
  String message = '';

  bool get hasLocation => current != null;

  /// Header subtitle: the detected place, or the location state
  /// ('Locating...' / 'Location off') when there is no fix yet.
  /// A manual pin is labelled as manual.
  String get headerSubtitle {
    if (manualLocation != null) {
      return '${manualLocation!.displayName} (manual)';
    }
    if (current != null) return current!.displayName;
    switch (status) {
      case LocationStatus.permissionDenied:
      case LocationStatus.permissionDeniedForever:
      case LocationStatus.serviceDisabled:
        return 'Location off';
      default:
        return 'Locating...';
    }
  }

  /// Loads the cached location (fast), then refreshes from GPS in
  /// the background. Called once from main() before runApp.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // A manual pin from the map wins over everything.
      final manualRaw = prefs.getString(_kManualLocation);
      if (manualRaw != null) {
        final m = UserLocation.fromJson(
          jsonDecode(manualRaw) as Map<String, dynamic>,
        );
        // fromJson marks it "from cache"; a manual pin is the
        // user's choice, not a stale fix.
        manualLocation = UserLocation(
          latitude: m.latitude,
          longitude: m.longitude,
          cityName: m.cityName,
          country: m.country,
          updatedAt: m.updatedAt,
        );
      }
      final raw = prefs.getString(_kLastLocation);
      if (raw != null) {
        _gps = UserLocation.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        status = LocationStatus.ready;
        message = manualLocation != null
            ? ''
            : 'Showing last known location.';
        notifyListeners();
      }
    } catch (_) {
      // A bad cache must never block startup.
    }
    // GPS refresh runs async — the app opens on the cached location
    // (or the "locating" state) and updates when the fix arrives.
    unawaited(refresh());
  }

  /// Gets a fresh GPS fix. Never throws — failures are recorded in
  /// [status]/[message] instead. A cached location is kept (and
  /// labelled as last-known) when the fresh fix fails.
  Future<void> refresh() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        status = LocationStatus.serviceDisabled;
        message =
            'Location is turned off on this phone. Turn it on to get prayer times, Qibla and nearby mosques.';
        notifyListeners();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        status = LocationStatus.permissionDenied;
        message =
            'Location permission is needed for prayer times, Qibla and mosques.';
        notifyListeners();
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        status = LocationStatus.permissionDeniedForever;
        message =
            'Location permission is blocked. Open Settings to allow it.';
        notifyListeners();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          // 30s, not 10s: a cold fix indoors (first fix, weak
          // satellite signal) routinely takes longer than 10s.
          timeLimit: Duration(seconds: 30),
        ),
      );
      final place = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      final fresh = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: place.$1,
        country: place.$2,
        updatedAt: DateTime.now(),
      );
      _gps = fresh;
      status = LocationStatus.ready;
      message = '';
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kLastLocation, jsonEncode(fresh.toJson()));
      } catch (_) {
        // Caching must never fail the refresh.
      }
    } catch (_) {
      if (manualLocation != null) {
        // A manual pin stays put — a failed GPS fix changes nothing.
        status = LocationStatus.ready;
        message = '';
      } else if (_gps != null) {
        // Keep the cached location, labelled as last-known.
        status = LocationStatus.ready;
        message =
            'Could not get a fresh GPS fix — showing last known location.';
      } else {
        status = LocationStatus.error;
        message =
            'Could not get your location. Check GPS and try again.';
      }
      notifyListeners();
    }
  }

  /// Pins a manual location from the map. The pin wins over GPS
  /// everywhere (prayer times, Qibla, mosques, Azan, countdown)
  /// until the user clears it. Stored on the phone only.
  Future<void> setManualLocation(double latitude, double longitude) async {
    final place = await _reverseGeocode(latitude, longitude);
    manualLocation = UserLocation(
      latitude: latitude,
      longitude: longitude,
      cityName: place.$1,
      country: place.$2,
      updatedAt: DateTime.now(),
    );
    status = LocationStatus.ready;
    message = '';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kManualLocation,
        jsonEncode(manualLocation!.toJson()),
      );
    } catch (_) {
      // Saving the pin must never fail the tap.
    }
  }

  /// Drops the manual pin and goes back to GPS.
  Future<void> clearManualLocation() async {
    manualLocation = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kManualLocation);
    } catch (_) {}
    unawaited(refresh());
  }

  /// Reverse-geocodes coordinates to (city, country). Locality can
  /// come back empty — fall back subLocality -> administrativeArea.
  /// A geocoding failure still returns ('', ''): the coordinates
  /// themselves are what matter, the name is only a label.
  Future<(String, String)> _reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      // geocoding 5.x: placemarkFromCoordinates is an instance method
      // of the Geocoding class, NOT a top-level function any more
      // (the old top-level API was removed in 5.0.0).
      final marks = await Geocoding()
          .placemarkFromCoordinates(latitude, longitude);
      if (marks.isEmpty) return ('', '');
      final m = marks.first;
      final city = m.locality?.isNotEmpty == true
          ? m.locality!
          : (m.subLocality?.isNotEmpty == true
              ? m.subLocality!
              : (m.administrativeArea ?? ''));
      return (city, m.country ?? '');
    } catch (_) {
      return ('', '');
    }
  }

  /// Opens the app's Settings page (for denied-forever permission).
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  /// Opens the phone's location settings (for disabled location).
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }
}
