import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'profile_edit_screen.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/timings_editor.dart';

/// Settings: appearance, Azan notifications, muezzin voice, reminders,
/// profile, and the honest notes about what needs the owner's input
/// (Gemini key, launcher icon, Firebase).
///
/// LAYOUT (Run 7 sweep): sections now live in Cards with dividers —
/// the old bare SwitchListTiles / RadioListTiles straight on the
/// pattern looked unfinished next to the card-based Home. The masjid
/// timings button moved out of the ListTile trailing slot (it squeezed
/// the title on narrow phones) to a full-width button under the row.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _testingVoice = false;
  String? _voiceTestResult;

  Future<void> _testVoice(String voiceId) async {
    setState(() {
      _testingVoice = true;
      _voiceTestResult = null;
    });
    final ok = await NotificationService.playAzan(voiceId);
    if (mounted) {
      setState(() {
        _testingVoice = false;
        _voiceTestResult = ok
            ? 'Sound is playing — listen.'
            : 'Audio did not load — check the file.';
      });
    }
  }

  Future<void> _reschedule(SettingsProvider settings) async {
    await NotificationService.rescheduleAll(
      city: settings.city,
      notify: settings.notify,
      reminderMinutes: settings.reminderMinutes,
      voiceId: settings.muezzinVoice,
      customTimings: settings.masjidTimings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(title: 'Appearance'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark mode'),
                value: settings.darkMode,
                onChanged: settings.setDarkMode,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Elder / large font mode'),
                subtitle: const Text('Larger text for elders.'),
                value: settings.elderMode,
                onChanged: settings.setElderMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'Azan notifications'),
        const Text(
          'When prayer time comes, an Azan notification and sound. '
          'The phone will ask permission the first time you turn it on '
          '(Android 13+ notifications, Android 12+ exact alarms).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0;
                  i < settings.notify.entries.length;
                  i++) ...[
                if (i > 0) const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    settings.notify.entries.elementAt(i).key == 'jumuah'
                        ? 'Jumu\'ah'
                        : settings.notify.entries.elementAt(i).key[0]
                                .toUpperCase() +
                            settings.notify.entries
                                .elementAt(i)
                                .key
                                .substring(1),
                  ),
                  value: settings.notify.entries.elementAt(i).value,
                  onChanged: (v) async {
                    settings.setNotify(
                      settings.notify.entries.elementAt(i).key,
                      v,
                    );
                    if (v) {
                      await NotificationService.requestPermissions();
                    }
                    await _reschedule(settings);
                  },
                ),
              ],
              const Divider(height: 1),
              ListTile(
                title: const Text('Reminder'),
                subtitle: const Text(
                  'How long before Azan should we remind you?',
                ),
                trailing: DropdownButton<int>(
                  value: settings.reminderMinutes,
                  items: const [0, 5, 10].map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(m == 0 ? 'Off' : '$m minutes before'),
                    );
                  }).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    settings.setReminderMinutes(v);
                    await _reschedule(settings);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'My mosque\'s prayer timings'),
        const Text(
          'Set your mosque\'s congregation timings here — the Home countdown '
          'and Azan notifications will use them. If not set, the '
          'calculated (Karachi method) timings are used.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.mosque,
                        color: AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.masjidTimings.isEmpty
                                ? 'Calculated timings are in use'
                                : 'Your mosque timings are set',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (settings.masjidTimings.isNotEmpty)
                            Text(
                              ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']
                                  .where(
                                    (k) =>
                                        settings.masjidTimings[k] != null,
                                  )
                                  .map(
                                    (k) =>
                                        '$k ${settings.masjidTimings[k]}',
                                  )
                                  .join(' • '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GoldButton(
                  label: 'Set timings',
                  icon: Icons.edit,
                  onPressed: () async {
                    await showMasjidTimingsEditor(context);
                    await _reschedule(settings);
                  },
                ),
                if (settings.masjidTimings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: () async {
                        settings.setMasjidTimings({});
                        await _reschedule(settings);
                      },
                      child: const Text(
                        'Back to calculated timings',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'Muezzin voice'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < MuezzinVoice.all.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                RadioListTile<String>(
                  title: Text(MuezzinVoice.all[i].label),
                  subtitle: Text(MuezzinVoice.all[i].note),
                  value: MuezzinVoice.all[i].id,
                  groupValue: settings.muezzinVoice,
                  onChanged: (v) async {
                    if (v == null) return;
                    settings.setMuezzinVoice(v);
                    await _reschedule(settings);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GoldButton(
              label: _testingVoice ? 'Playing...' : 'Listen',
              icon: Icons.play_arrow,
              onPressed: _testingVoice
                  ? null
                  : () => _testVoice(settings.muezzinVoice),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => NotificationService.stopAzan(),
              child: const Text('Rokein'),
            ),
          ],
        ),
        if (_voiceTestResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _voiceTestResult!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'AI Friend (Gemini)'),
        Card(
          child: ListTile(
            leading: Icon(
              GeminiService.hasKey ? Icons.check_circle : Icons.warning,
              color: GeminiService.hasKey
                  ? Colors.green
                  : AppTheme.gold,
            ),
            title: Text(
              GeminiService.hasKey
                  ? 'Gemini is connected'
                  : 'No Gemini key set',
            ),
            subtitle: const Text(
              'The key is never written in the app. Provide it when building:\n'
              'flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY',
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'Profile'),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              child: Icon(Icons.person),
            ),
            title: Text(
              settings.profileName.isEmpty
                  ? 'Guest user'
                  : settings.profileName,
            ),
            subtitle: Text(
              settings.profileEmail.isEmpty
                  ? 'Not signed in — set your profile from the More tab.'
                  : settings.profileEmail,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            subtitle: const Text('Photo, name, gender, birthday'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileEditScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Version 0.1.0 (prototype) • Mohalla • com.mohalla.app',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
