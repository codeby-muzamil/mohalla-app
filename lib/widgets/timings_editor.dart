import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/prayer_service.dart';
import '../services/settings_provider.dart';
import 'common.dart';

/// The "apni masjid ki timings" editor, shared by Home and Settings.
/// The user types his own masjid's Jamaat times (HH:mm, 24h) per prayer.
/// Times are stored in SettingsProvider.masjidTimings (persisted) and,
/// when set, OVERRIDE the calculated Azan times everywhere: the Home
/// countdown, the times table and the Azan notifications (see
/// PrayerService.effectiveTimesFor). "Sab saaf karein" resets to the
/// calculated times. The board photo is only a visual reference —
/// there is no OCR; the user reads the board and types the times.
Future<void> showMasjidTimingsEditor(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final cityNow = PrayerService.nowIn(settings.city);
  final times = PrayerService.timesFor(
    settings.city,
    DateTime(cityNow.year, cityNow.month, cityNow.day),
  );
  final controllers = <String, TextEditingController>{};
  for (final key in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'jumuah']) {
    final existing = settings.masjidTimings[key];
    final fallback = key == 'jumuah'
        ? '13:30'
        : PrayerService.formatTime(times[key] ?? times['dhuhr']!)
            .replaceAll(' AM', '')
            .replaceAll(' PM', '');
    controllers[key] = TextEditingController(text: existing ?? fallback);
  }
  final hasCustom = settings.masjidTimings.isNotEmpty;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('My mosque timings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasCustom
                  ? 'Your mosque timings are currently set — the Home '
                      'countdown and Azan use them.'
                  : 'These are congregation timings (as per the mosque board). '
                      'Once set, the Home countdown and Azan will use them.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (settings.boardPhotoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(settings.boardPhotoPath!),
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            GoldButton(
              label: 'Take a photo of the clock/board',
              icon: Icons.camera_alt,
              onPressed: () async {
                final file = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1200,
                );
                if (file != null && ctx.mounted) {
                  context.read<SettingsProvider>().setBoardPhoto(file.path);
                  Navigator.pop(ctx);
                  showMasjidTimingsEditor(context);
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Read the time from the photo yourself and write it below (no OCR yet).',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (final key in [
              'fajr',
              'dhuhr',
              'asr',
              'maghrib',
              'isha',
              'jumuah',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: controllers[key],
                  decoration: InputDecoration(
                    labelText: PrayerService.prayerNamesEnglish[key] ?? key,
                    hintText: 'HH:MM (24h, e.g. 05:30)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.datetime,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            settings.setMasjidTimings({});
            Navigator.pop(ctx);
          },
          child: const Text('Calculated timings'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final map = <String, String>{};
            for (final e in controllers.entries) {
              final v = e.value.text.trim();
              if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(v)) {
                map[e.key] = v;
              }
            }
            settings.setMasjidTimings(map);
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
