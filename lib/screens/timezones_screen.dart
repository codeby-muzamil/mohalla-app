import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/city.dart';
import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import '../widgets/common.dart';

/// Timezones: 18 preset world cities (picking one recalculates that
/// city's prayer times in its own zone) + the phone's full IANA list
/// (searchable, count computed live) + Auto (device) mode.
/// Like Muslim Pro: times come from the sun for the selected PLACE —
/// a time zone only changes the clock, never the prayer itself.
///
/// LAYOUT FIX (Run 7): the old screen rebuilt the 600+ zone list
/// (sort + `tz.getLocation` per visible row) on EVERY build — every
/// search keystroke janked on a low-end phone — and the zone rows were
/// bare ListTiles straight on the pattern background, with the
/// selected-city prayer rows as unpadded bare Rows and the switch
/// floating without a card. Now the zone list is computed ONCE in
/// initState (times refreshed on a 60s timer), the zones live in one
/// Card with dividers, and every section has consistent card + spacing.
class TimezonesScreen extends StatefulWidget {
  const TimezonesScreen({super.key});

  @override
  State<TimezonesScreen> createState() => _TimezonesScreenState();
}

class _ZoneRow {
  final String zone;
  final String offset; // e.g. +5:00
  final String time; // e.g. 5:25 PM

  const _ZoneRow(this.zone, this.offset, this.time);
}

class _TimezonesScreenState extends State<TimezonesScreen> {
  String _query = '';
  List<String> _allZones = [];
  List<_ZoneRow> _zoneRows = [];
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // Computed once: sorting 600+ zone names + building the display
    // rows on every build was the jank on this screen.
    _allZones = tz.timeZoneDatabase.locations.keys.toList()..sort();
    _rebuildZoneRows();
    // The "current time" per zone goes stale by the minute — refresh
    // the strings once a minute, not on every keystroke/rebuild.
    _clockTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) setState(_rebuildZoneRows);
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _rebuildZoneRows() {
    _zoneRows = _allZones.map((z) {
      final loc = tz.getLocation(z);
      final now = tz.TZDateTime.now(loc);
      final offset = now.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final hours = offset.inHours.abs();
      final mins =
          (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      return _ZoneRow(
        z,
        '$sign$hours:$mins',
        DateFormat('h:mm a').format(now),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final city = settings.city;
    final shownZones = _zoneRows.where((r) {
      if (_query.isEmpty) return true;
      return r.zone.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    // First 60 only (the rest need a search) — computed once per build.
    final visibleZones = shownZones.take(60).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(
          title: 'Worldwide Timings',
          subtitle:
              'Changing the city changes its prayer timings, date and countdown.',
        ),
        Card(
          child: SwitchListTile(
            title: const Text('Auto (device location)'),
            subtitle: const Text(
              "Use the phone's own location/timezone — like Muslim Pro.",
            ),
            value: settings.autoTimezone,
            onChanged: (v) => settings.setAutoTimezone(v),
          ),
        ),
        if (settings.autoTimezone)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "In Auto mode, times come from the phone's location. "
                'In the real app, the city will be picked by GPS.',
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Popular cities',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presetCities.map((c) {
            final selected = c.name == city.name && !settings.autoTimezone;
            return ChoiceChip(
              label: Text('${c.name} (${c.country})'),
              selected: selected,
              onSelected: (_) => settings.setCity(c),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected city: ${city.name}, ${city.country}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text('Timezone: ${city.timeZone}'),
                Text(
                  'Qibla: ${PrayerService.qiblaBearing(city).toStringAsFixed(0)}° • '
                  'Distance to Makkah: ${PrayerService.distanceToMakkahKm(city).toStringAsFixed(0)} km',
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final now = PrayerService.nowIn(city);
                    final times = PrayerService.timesFor(
                      city,
                      DateTime(now.year, now.month, now.day),
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
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    PrayerService.prayerNamesEnglish[key]!,
                                  ),
                                ),
                                Text(
                                  PrayerService.formatTime(times[key]!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Full timezone list (from the phone's IANA database)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          '${_allZones.length} timezones are available on your phone.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search city or country...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        // One card, dividers between rows, aligned check icon — the
        // old bare ListTiles on the pattern looked unfinished.
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < visibleZones.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  title: Text(
                    visibleZones[i].zone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'UTC${visibleZones[i].offset} • ${visibleZones[i].time}',
                  ),
                  trailing: city.timeZone == visibleZones[i].zone
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                ),
              ],
            ],
          ),
        ),
        if (shownZones.length > 60)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '...and ${shownZones.length - 60} more zones — search to find them.',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        const SampleNote(
          text:
              "Prayer times come from the sun's position — the timezone "
              'only shows clock time; changing the city changes the times.',
        ),
      ],
    );
  }
}
