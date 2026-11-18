import 'package:flutter/material.dart';

/// Mohalla visual identity: emerald / sand / gold, Icon 2 (gold M minarets).
/// Dark mode is a full theme, not just inverted colours. Elder mode is a
/// text-scale factor applied in main.dart (1.3x), not a separate theme.
class AppTheme {
  static const Color emerald = Color(0xFF0B6B4F);
  static const Color emeraldDark = Color(0xFF084E3A);
  static const Color emeraldLight = Color(0xFF12805F);
  static const Color sand = Color(0xFFF5EFE0);
  static const Color sandDark = Color(0xFFEADFC2);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldLight = Color(0xFFE3C565);
  static const Color ink = Color(0xFF1E2A24);
  static const Color nightBg = Color(0xFF0E1B16);
  static const Color nightCard = Color(0xFF16261F);
  static const Color nightInk = Color(0xFFF0EAD8);

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: emerald,
      secondary: gold,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: ink,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: sand,
      primaryColor: emerald,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: emerald,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: ink,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: emerald,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? gold : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? gold.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: emeraldLight,
      secondary: gold,
      surface: nightCard,
      onPrimary: Colors.white,
      onSecondary: ink,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: nightBg,
      primaryColor: emeraldLight,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A2E22),
        foregroundColor: nightInk,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: nightCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: ink,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0A2E22),
        selectedItemColor: goldLight,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: nightInk,
            displayColor: nightInk,
          ),
    );
  }
}

/// The 5 Quran reader themes (background / text / accent).
class ReaderTheme {
  final String id;
  final String labelEnglish;
  final Color background;
  final Color text;
  final Color accent;

  const ReaderTheme({
    required this.id,
    required this.labelEnglish,
    required this.background,
    required this.text,
    required this.accent,
  });

  static const List<ReaderTheme> all = [
    ReaderTheme(
      id: 'paper',
      labelEnglish: 'Paper',
      background: Color(0xFFFFFDF5),
      text: Color(0xFF2B2118),
      accent: AppTheme.emerald,
    ),
    ReaderTheme(
      id: 'sepia',
      labelEnglish: 'Sepia',
      background: Color(0xFFF4ECD8),
      text: Color(0xFF4A3520),
      accent: Color(0xFF8A6D2B),
    ),
    ReaderTheme(
      id: 'emerald',
      labelEnglish: 'Emerald',
      background: Color(0xFFE7F2EC),
      text: Color(0xFF123B2C),
      accent: AppTheme.emerald,
    ),
    ReaderTheme(
      id: 'night',
      labelEnglish: 'Night',
      background: Color(0xFF121212),
      text: Color(0xFFEDE8D6),
      accent: AppTheme.goldLight,
    ),
    ReaderTheme(
      id: 'rose',
      labelEnglish: 'Rose',
      background: Color(0xFFFBEFF0),
      text: Color(0xFF4A2230),
      accent: Color(0xFFA34A68),
    ),
  ];

  static ReaderTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}
