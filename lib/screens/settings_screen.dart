import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'profile_edit_screen.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/quran_reciters.dart';
import '../services/settings_provider.dart';
import '../services/translation_text_service.dart';
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
  late final TextEditingController _geminiKeyController;
  String? _geminiKeyMessage;

  @override
  void initState() {
    super.initState();
    // The field always starts empty: the saved key is never shown
    // back (only its masked form, last 4 characters, is displayed).
    _geminiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    super.dispose();
  }

  /// Save the pasted Gemini key (or clear it). Updates the AI
  /// service right away so AI Dost uses it without a restart.
  void _saveGeminiKey() {
    final key = _geminiKeyController.text.trim();
    final settings = context.read<SettingsProvider>();
    settings.setGeminiApiKey(key);
    GeminiService.setRuntimeKey(key);
    _geminiKeyController.clear();
    setState(() {
      _geminiKeyMessage = key.isEmpty
          ? 'Key removed — AI Dost is back to offline answers.'
          : 'Key saved on this phone only — Gemini is connected.';
    });
  }

  /// Language picker for the extra (third) Quran translation.
  /// 'None' keeps Urdu + English.
  void _showExtraTranslationDialog() {
    final settings = context.read<SettingsProvider>();
    final current = settings.extraTranslation;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extra translation language'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView.builder(
            itemCount: TranslationTextService.all.length + 1,
            itemBuilder: (c, i) {
              if (i == 0) {
                return ListTile(
                  title: const Text('None'),
                  subtitle: const Text('Urdu + English only'),
                  trailing: current == null
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    settings.setExtraTranslationId('');
                    Navigator.pop(ctx);
                  },
                );
              }
              final e = TranslationTextService.all[i - 1];
              return ListTile(
                title: Text(e.languageName),
                subtitle: Text(e.translator),
                trailing: current?.id == e.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  settings.setExtraTranslationId(e.id);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

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
    // Azan follows the GPS location — nothing to schedule until a
    // location is known.
    final coords = context.read<LocationService>().current;
    if (coords == null) return;
    await NotificationService.rescheduleAll(
      latitude: coords.latitude,
      longitude: coords.longitude,
      method: settings.calculationMethod,
      madhab: settings.madhab,
      notify: settings.notify,
      reminderMinutes: settings.reminderMinutes,
      voiceId: settings.muezzinVoice,
      customTimings: settings.masjidTimings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    // Demo .set-row: 11px vertical padding; the 1px cardLine top
    // border comes from the Divider between tiles.
    const tilePadding =
        EdgeInsets.symmetric(horizontal: 16, vertical: 11);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        const SectionTitle(title: 'Appearance'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: tilePadding,
                title: const Text('Dark mode'),
                value: settings.darkMode,
                onChanged: settings.setDarkMode,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: tilePadding,
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
        Text(
          'When prayer time comes, an Azan notification and sound. '
          'The phone will ask permission the first time you turn it on '
          '(Android 13+ notifications, Android 12+ exact alarms).',
          style: TextStyle(fontSize: 12, color: muted),
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
                  contentPadding: tilePadding,
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
                contentPadding: tilePadding,
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
        const SectionTitle(title: 'Prayer calculation'),
        Text(
          'Calculation method and Asr time affect all prayer times, '
          'the countdown and Azan. Pick the method used where you live.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0;
                  i < SettingsProvider.calculationMethods.length;
                  i++) ...[
                if (i > 0) const Divider(height: 1),
                RadioListTile<String>(
                  contentPadding: tilePadding,
                  title: Text(
                    SettingsProvider.calculationMethods[i].$2,
                  ),
                  subtitle: Text(
                    SettingsProvider.calculationMethods[i].$3,
                  ),
                  value: SettingsProvider.calculationMethods[i].$1,
                  groupValue: settings.calculationMethodId,
                  onChanged: (v) async {
                    if (v == null) return;
                    settings.setCalculationMethod(v);
                    await _reschedule(settings);
                  },
                ),
              ],
              const Divider(height: 1),
              const ListTile(
                contentPadding: tilePadding,
                title: Text('Asr time'),
                subtitle: Text('When does Asr start?'),
              ),
              for (var i = 0;
                  i < SettingsProvider.asrMadhabs.length;
                  i++) ...[
                RadioListTile<String>(
                  contentPadding: tilePadding,
                  title: Text(SettingsProvider.asrMadhabs[i].$2),
                  subtitle: Text(SettingsProvider.asrMadhabs[i].$3),
                  value: SettingsProvider.asrMadhabs[i].$1,
                  groupValue: settings.madhabId,
                  onChanged: (v) async {
                    if (v == null) return;
                    settings.setMadhab(v);
                    await _reschedule(settings);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'Hijri date adjustment'),
        Text(
          'The Hijri date comes from the phone\'s Islamic calendar. '
          'Moon sighting can shift a date by a day — if your mosque\'s '
          'date differs, adjust it here. It changes the date on Home '
          'and in the Hijri calendar.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              RadioListTile<int>(
                contentPadding: tilePadding,
                title: const Text('One day earlier'),
                subtitle: const Text('Show yesterday\'s Hijri date'),
                value: -1,
                groupValue: settings.hijriAdjustment,
                onChanged: (v) {
                  if (v == null) return;
                  settings.setHijriAdjustment(v);
                },
              ),
              const Divider(height: 1),
              RadioListTile<int>(
                contentPadding: tilePadding,
                title: const Text('No adjustment'),
                subtitle: const Text('Use the phone\'s Islamic calendar'),
                value: 0,
                groupValue: settings.hijriAdjustment,
                onChanged: (v) {
                  if (v == null) return;
                  settings.setHijriAdjustment(v);
                },
              ),
              const Divider(height: 1),
              RadioListTile<int>(
                contentPadding: tilePadding,
                title: const Text('One day later'),
                subtitle: const Text('Show tomorrow\'s Hijri date'),
                value: 1,
                groupValue: settings.hijriAdjustment,
                onChanged: (v) {
                  if (v == null) return;
                  settings.setHijriAdjustment(v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'My mosque\'s prayer timings'),
        Text(
          'Set your mosque\'s congregation timings here — the Home countdown '
          'and Azan notifications will use them. If not set, the '
          'calculated (${settings.calculationMethodLabel}) timings are used.',
          style: TextStyle(fontSize: 12, color: muted),
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
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.mosque,
                        color: accent,
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
                              style: TextStyle(
                                fontSize: 12,
                                color: muted,
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
                  contentPadding: tilePadding,
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
              child: const Text('Stop'),
            ),
          ],
        ),
        if (_voiceTestResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _voiceTestResult!,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'Quran audio & translation'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < QuranReciter.all.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                RadioListTile<String>(
                  contentPadding: tilePadding,
                  title: Text(QuranReciter.all[i].label),
                  subtitle: Text(QuranReciter.all[i].note),
                  value: QuranReciter.all[i].edition,
                  groupValue: settings.reciterId,
                  onChanged: (v) {
                    if (v == null) return;
                    settings.setReciterId(v);
                  },
                ),
              ],
              const Divider(height: 1),
              const ListTile(
                contentPadding: tilePadding,
                title: Text('Translation voice'),
                subtitle: Text(
                  'Spoken translation played after each Arabic ayah.',
                ),
              ),
              RadioListTile<String>(
                contentPadding: tilePadding,
                title: const Text('Off'),
                subtitle: const Text('Arabic audio only'),
                value: '',
                groupValue: settings.translationVoiceId,
                onChanged: (v) {
                  if (v == null) return;
                  settings.setTranslationVoiceId(v);
                },
              ),
              for (final v in TranslationVoice.all) ...[
                const Divider(height: 1),
                RadioListTile<String>(
                  contentPadding: tilePadding,
                  title: Text(v.label),
                  value: v.id,
                  groupValue: settings.translationVoiceId,
                  onChanged: (val) {
                    if (val == null) return;
                    settings.setTranslationVoiceId(val);
                  },
                ),
              ],
              const Divider(height: 1),
              const ListTile(
                contentPadding: tilePadding,
                title: Text('Audio mode'),
                subtitle: Text('How ayah audio plays.'),
              ),
              for (final e in const [
                (
                  'arabic',
                  'Arabic only',
                  'Only the Arabic recitation.',
                ),
                (
                  'interleaved',
                  'Arabic, then translation',
                  'Arabic ayah, then its translation.',
                ),
                (
                  'translation',
                  'Translation only',
                  'Only the spoken translation.',
                ),
              ]) ...[
                const Divider(height: 1),
                RadioListTile<String>(
                  contentPadding: tilePadding,
                  title: Text(e.$2),
                  subtitle: Text(e.$3),
                  value: e.$1,
                  groupValue: settings.quranAudioMode,
                  onChanged: (v) {
                    if (v == null) return;
                    settings.setQuranAudioMode(v);
                  },
                ),
              ],
              const Divider(height: 1),
              ListTile(
                contentPadding: tilePadding,
                title: const Text('Extra translation language'),
                subtitle: Text(
                  settings.extraTranslation == null
                      ? 'None — Urdu + English only'
                      : '${settings.extraTranslation!.languageName} — '
                          '${settings.extraTranslation!.translator}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showExtraTranslationDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'AI Friend (Gemini)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      GeminiService.hasKey
                          ? Icons.check_circle
                          : Icons.warning,
                      color: GeminiService.hasKey
                          ? accent
                          : gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GeminiService.hasKey
                                ? 'Gemini is connected'
                                : 'No Gemini key set',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (settings.geminiApiKey.isNotEmpty)
                            Text(
                              'Saved key ends with '
                              '${settings.geminiApiKeyMasked}',
                              style: TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste your own Gemini API key to connect AI Dost. '
                  'It is stored on this phone only and is never '
                  'uploaded. Without a key the bot answers offline. '
                  'Get a key at Google AI Studio (aistudio.google.com).',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _geminiKeyController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API key',
                    hintText: 'Paste your key here',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GoldButton(
                      label: 'Save key',
                      icon: Icons.key,
                      onPressed: _saveGeminiKey,
                    ),
                    if (settings.geminiApiKey.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _geminiKeyController.clear();
                          final s = context.read<SettingsProvider>();
                          s.setGeminiApiKey('');
                          GeminiService.setRuntimeKey('');
                          setState(() {
                            _geminiKeyMessage =
                                'Key removed — AI Dost is back to offline answers.';
                          });
                        },
                        child: const Text('Remove key'),
                      ),
                    ],
                  ],
                ),
                if (_geminiKeyMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _geminiKeyMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle(title: 'Profile'),
        Card(
          child: ListTile(
            contentPadding: tilePadding,
            leading: CircleAvatar(
              backgroundColor:
                  isDark ? AppTheme.emeraldLight : AppTheme.emerald,
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
            contentPadding: tilePadding,
            leading: Icon(Icons.edit, color: accent),
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
        Text(
          'Version 0.1.0 (prototype) • Mohalla • com.mohalla.app',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }
}
