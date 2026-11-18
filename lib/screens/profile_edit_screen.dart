import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Edit Profile: modern profile editor — photo, display name, gender,
/// birthday (with auto-computed age) and a read-only email row.
/// Everything is stored on the phone only, in SettingsProvider.
/// All strings are English.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameCtrl;
  String _gender = '';
  DateTime? _dob;
  String _photoPath = '';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _nameCtrl = TextEditingController(text: s.profileName);
    _nameCtrl.addListener(() => setState(() {}));
    _gender = s.profileGender;
    _photoPath = s.profilePhotoPath;
    if (s.profileDob.isNotEmpty) {
      _dob = DateTime.tryParse(s.profileDob);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join();
    return letters.toUpperCase();
  }

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context);
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
    );
    if (file != null && mounted) {
      setState(() => _photoPath = file.path);
    }
  }

  void _showPhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.emerald,
                    onPrimary: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.emerald,
                    onPrimary: Colors.white,
                    onSurface: AppTheme.ink,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  void _save() {
    final s = context.read<SettingsProvider>();
    s.setProfile(_nameCtrl.text.trim(), s.profileEmail);
    s.setProfilePhoto(_photoPath);
    s.setProfileGender(_gender);
    s.setProfileDob(_dob == null ? '' : _isoDate(_dob!));
    Navigator.pop(context);
  }

  Widget _genderChip(String value, String label) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppTheme.emerald : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final nameEmpty = _nameCtrl.text.trim().isEmpty;
    final name = _nameCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppTheme.emerald,
                  backgroundImage: _photoPath.isNotEmpty
                      ? FileImage(File(_photoPath))
                      : null,
                  child: _photoPath.isNotEmpty
                      ? null
                      : (name.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 56,
                              color: AppTheme.gold,
                            )
                          : Text(
                              _initials(name),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.gold,
                              ),
                            )),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _showPhotoSheet,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.gold,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Name'),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Gender'),
          Wrap(
            spacing: 10,
            children: [
              _genderChip('male', 'Male'),
              _genderChip('female', 'Female'),
              _genderChip('prefer_not', 'Prefer not to say'),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Date of birth'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(
                _dob == null ? 'Not set' : _formatDate(_dob!),
              ),
              subtitle: _dob == null
                  ? const Text('Tap to choose your birthday')
                  : Text(
                      'Age: ${SettingsProvider.ageFromDob(_isoDate(_dob!))}',
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDob,
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'Email'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: Text(
                settings.profileEmail.isEmpty
                    ? 'Not signed in'
                    : settings.profileEmail,
              ),
              subtitle: const Text(
                'This email comes from your Google sign-in.',
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: GoldButton(
              label: 'Save',
              onPressed: nameEmpty ? null : _save,
            ),
          ),
        ),
      ),
    );
  }
}
