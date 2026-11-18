/// A preset world city for the Timezones feature.
/// Prayer times are recalculated on-device from these real coordinates
/// (adhan package, Karachi method, Hanafi Asr) and displayed in the city's
/// own IANA time zone. Coordinates are the city centres as listed by
/// public gazetteers (GeoNames / Wikipedia); times vary by 1-2 minutes
/// within a large city.
class CityPreset {
  final String name; // e.g. Hyderabad
  final String country; // e.g. Pakistan
  final double latitude;
  final double longitude;
  final String timeZone; // IANA identifier, e.g. Asia/Karachi

  const CityPreset({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timeZone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'timeZone': timeZone,
      };

  factory CityPreset.fromJson(Map<String, dynamic> json) => CityPreset(
        name: json['name'] as String,
        country: json['country'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timeZone: json['timeZone'] as String,
      );
}

/// The 18 preset cities shipped with the app. Hyderabad (Sindh, Pakistan)
/// is the default — the owner's home city.
const List<CityPreset> presetCities = [
  CityPreset(
    name: 'Hyderabad',
    country: 'Pakistan',
    latitude: 25.39,
    longitude: 68.37,
    timeZone: 'Asia/Karachi',
  ),
  CityPreset(
    name: 'Karachi',
    country: 'Pakistan',
    latitude: 24.86,
    longitude: 67.01,
    timeZone: 'Asia/Karachi',
  ),
  CityPreset(
    name: 'Lahore',
    country: 'Pakistan',
    latitude: 31.52,
    longitude: 74.36,
    timeZone: 'Asia/Karachi',
  ),
  CityPreset(
    name: 'Islamabad',
    country: 'Pakistan',
    latitude: 33.68,
    longitude: 73.05,
    timeZone: 'Asia/Karachi',
  ),
  CityPreset(
    name: 'Makkah',
    country: 'Saudi Arabia',
    latitude: 21.42,
    longitude: 39.83,
    timeZone: 'Asia/Riyadh',
  ),
  CityPreset(
    name: 'Madinah',
    country: 'Saudi Arabia',
    latitude: 24.47,
    longitude: 39.61,
    timeZone: 'Asia/Riyadh',
  ),
  CityPreset(
    name: 'Dubai',
    country: 'UAE',
    latitude: 25.20,
    longitude: 55.27,
    timeZone: 'Asia/Dubai',
  ),
  CityPreset(
    name: 'Doha',
    country: 'Qatar',
    latitude: 25.29,
    longitude: 51.53,
    timeZone: 'Asia/Qatar',
  ),
  CityPreset(
    name: 'Dhaka',
    country: 'Bangladesh',
    latitude: 23.81,
    longitude: 90.41,
    timeZone: 'Asia/Dhaka',
  ),
  CityPreset(
    name: 'Delhi',
    country: 'India',
    latitude: 28.61,
    longitude: 77.21,
    timeZone: 'Asia/Kolkata',
  ),
  CityPreset(
    name: 'Kuala Lumpur',
    country: 'Malaysia',
    latitude: 3.13,
    longitude: 101.71,
    timeZone: 'Asia/Kuala_Lumpur',
  ),
  CityPreset(
    name: 'Jakarta',
    country: 'Indonesia',
    latitude: -6.21,
    longitude: 106.85,
    timeZone: 'Asia/Jakarta',
  ),
  CityPreset(
    name: 'Istanbul',
    country: 'Türkiye',
    latitude: 41.01,
    longitude: 28.98,
    timeZone: 'Europe/Istanbul',
  ),
  CityPreset(
    name: 'Cairo',
    country: 'Egypt',
    latitude: 30.06,
    longitude: 31.25,
    timeZone: 'Africa/Cairo',
  ),
  CityPreset(
    name: 'London',
    country: 'United Kingdom',
    latitude: 51.51,
    longitude: -0.13,
    timeZone: 'Europe/London',
  ),
  CityPreset(
    name: 'New York',
    country: 'United States',
    latitude: 40.71,
    longitude: -74.01,
    timeZone: 'America/New_York',
  ),
  CityPreset(
    name: 'Toronto',
    country: 'Canada',
    latitude: 43.65,
    longitude: -79.38,
    timeZone: 'America/Toronto',
  ),
  CityPreset(
    name: 'Sydney',
    country: 'Australia',
    latitude: -33.87,
    longitude: 151.21,
    timeZone: 'Australia/Sydney',
  ),
];

CityPreset cityByName(String name) => presetCities.firstWhere(
      (c) => c.name == name,
      orElse: () => presetCities.first,
    );
