import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../theme/app_theme.dart';

/// Hijri Calendar: monthly grid (Gregorian dates with the Hijri date
/// under each day), Islamic events marked, upcoming-events countdowns.
/// Uses the `hijri` package (device Islamic calendar) — NOT the tabular
/// (Kuwaiti) estimate, which drifted 1-2 days in the web prototype.
/// A note still says: confirm with your local mosque, moon sighting
/// can shift a date by a day.
class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _hijriMonths = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    'Shaban',
    'Ramadan',
    'Shawwal',
    'Dhul Qadah',
    'Dhul Hijjah',
  ];

  /// Islamic events keyed by (Hijri month, Hijri day).
  static const Map<String, String> _events = {
    '1-1': 'Islamic New Year',
    '1-10': 'Ashura',
    '3-12': 'Eid Milad-un-Nabi',
    '7-27': 'Shab-e-Mi\'raj',
    '8-15': 'Shab-e-Barat',
    '9-1': 'Ramadan begins',
    '9-21': 'Laylatul Qadr',
    '9-23': 'Laylatul Qadr',
    '9-25': 'Laylatul Qadr',
    '9-27': 'Laylatul Qadr',
    '9-29': 'Laylatul Qadr',
    '10-1': 'Eid-ul-Fitr',
    '12-9': 'Day of Arafah',
    '12-10': 'Eid-ul-Adha',
  };

  List<Map<String, dynamic>> _upcomingEvents() {
    final result = <Map<String, dynamic>>[];
    final today = DateTime.now();
    for (var d = 0; d < 370 && result.length < 6; d++) {
      final date = today.add(Duration(days: d));
      final h = HijriCalendar.fromDate(date);
      final key = '${h.hMonth}-${h.hDay}';
      final name = _events[key];
      if (name != null) {
        result.add({'date': date, 'hijri': h, 'name': name, 'inDays': d});
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    final today = DateTime.now();
    final upcoming = _upcomingEvents();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1, 1);
              }),
            ),
            Text(
              '${_month.month}/${_month.year}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1, 1);
              }),
            ),
          ],
        ),
        const Text(
          'Hijri dates come from the phone\'s Islamic calendar — '
          'moon sighting may shift a date by a day; '
          'confirm with your mosque.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            Text('Su'),
            Text('Mo'),
            Text('Tu'),
            Text('We'),
            Text('Th'),
            Text('Fr'),
            Text('Sa'),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            // 0.72 (not 0.85): day number + Hijri date + optional star
            // need headroom at 1.3x elder-mode text scaling.
            childAspectRatio: 0.72,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, i) {
            if (i < startWeekday) return const SizedBox.shrink();
            final day = i - startWeekday + 1;
            final date = DateTime(_month.year, _month.month, day);
            final h = HijriCalendar.fromDate(date);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final event = _events['${h.hMonth}-${h.hDay}'];
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isToday
                    ? AppTheme.gold.withValues(alpha: 0.35)
                    : event != null
                        ? AppTheme.emerald.withValues(alpha: 0.15)
                        : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: AppTheme.gold, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${h.hDay} ${_hijriMonths[h.hMonth - 1].split(' ').first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                  if (event != null)
                    const Icon(Icons.star,
                        size: 12, color: AppTheme.gold),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Upcoming Islamic dates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final e in upcoming)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event, color: AppTheme.emerald),
              title: Text(e['name'] as String),
              subtitle: Text(
                '${(e['hijri'] as HijriCalendar).hDay} '
                '${_hijriMonths[(e['hijri'] as HijriCalendar).hMonth - 1]} '
                '${(e['hijri'] as HijriCalendar).hYear} AH',
              ),
              trailing: Text(
                e['inDays'] == 0 ? 'Today' : '${e['inDays']} days',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
