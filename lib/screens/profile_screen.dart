import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'profile_edit_screen.dart';

/// Profile (demo v13): "Your Mohalla account" — avatar, name, email,
/// Edit Profile button, then Quick links: My Mosque, Prayer Tracker,
/// Settings. The edit form itself lives in ProfileEditScreen.
class ProfileScreen extends StatelessWidget {
  final void Function(String key) onOpen;

  const ProfileScreen({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        PressableCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A2E28),
                child: Text(
                  settings.profileName.isEmpty
                      ? 'M'
                      : settings.profileName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                settings.profileName.isEmpty
                    ? 'Guest'
                    : settings.profileName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                settings.profileEmail.isEmpty
                    ? 'No email set'
                    : settings.profileEmail,
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: const Color(0xFF1A2E28),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle(title: 'Quick links'),
        _ProfileLink(
          icon: Icons.mosque,
          title: 'My Mosque',
          subtitle: 'Mosque name & Iqama timings',
          onTap: () => onOpen('settings'),
        ),
        const SizedBox(height: 10),
        _ProfileLink(
          icon: Icons.check_circle,
          title: 'Prayer Tracker',
          subtitle: "Today's prayers & weekly streak",
          onTap: () => onOpen('tracker'),
        ),
        const SizedBox(height: 10),
        _ProfileLink(
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'Azan, appearance & language',
          onTap: () => onOpen('settings'),
        ),
      ],
    );
  }
}

class _ProfileLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    return PressableCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}
