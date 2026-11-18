import 'package:flutter/material.dart';

/// Mohalla visual identity — demo v13 tokens (emerald / sand / gold).
/// Light tokens from the demo `:root`; dark tokens from the demo `--app-*`
/// set (bg #081713 / surface #0F2A22 / ink #F5EFE3 / gold #D9A441).
/// Dark mode is a full theme, not just inverted colours. Elder mode is a
/// text-scale factor applied in main.dart (1.3x), not a separate theme.
class AppTheme {
  // Emerald — light primary #0B3D2E, dark-mode primary #005A45.
  static const Color emerald = Color(0xFF0B3D2E);
  static const Color emeraldDark = Color(0xFF06231B);
  static const Color emeraldLight = Color(0xFF005A45);
  // Sand — light scaffold #F3EDDC, alt #ECE3CB, card #FBF7EA.
  static const Color sand = Color(0xFFF3EDDC);
  static const Color sandDark = Color(0xFFECE3CB);
  static const Color cardLight = Color(0xFFFBF7EA);
  // Gold — light #A97F14 / #C9A227, dark #D9A441 / #E6C860.
  static const Color gold = Color(0xFFA97F14);
  static const Color goldLight = Color(0xFFC9A227);
  static const Color goldDark = Color(0xFFD9A441);
  static const Color goldDarkLight = Color(0xFFE6C860);
  // Ink / muted.
  static const Color ink = Color(0xFF17352A);
  static const Color mutedLight = Color(0xFF4C6156);
  static const Color nightBg = Color(0xFF081713);
  static const Color nightCard = Color(0xFF0F2A22);
  static const Color nightInk = Color(0xFFF5EFE3);
  static const Color mutedDark = Color(0xFFB9CDBF);
  // Card borders + chips.
  static const Color cardLineLight = Color(0xFFDDD0AB);
  static const Color cardLineDark = Color(0xFF234636);
  static const Color chipLight = Color(0xFFEFE7CF);
  static const Color chipDark = Color(0xFF123528);
  // Arabic gold (Asma / Dua / Tasbih Arabic): #D4AF37 in dark mode,
  // emerald #005A45 on the light card. Toast background #FDF6DA.
  static const Color arabicGold = Color(0xFFD4AF37);
  static const Color arabicGreen = Color(0xFF005A45);
  static const Color toastBg = Color(0xFFFDF6DA);
  // Deep header gradient end (dark) / night alt background.
  static const Color nightAlt = Color(0xFF0A1A14);
  static const Color nightDeep = Color(0xFF00382B);

  /// Demo card: radius 20, soft deep shadow, 14–16 padding.
  static const double cardRadius = 20;
  static const double buttonRadius = 14;
  static const double chipRadius = 999;

  static BoxShadow cardShadow(bool isDark) => BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.26),
        blurRadius: 24,
        offset: const Offset(0, 8),
      );

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: emerald,
      secondary: gold,
      surface: cardLight,
      onPrimary: Color(0xFFF7F1E3),
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
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 3,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: cardLineLight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: cardLineLight,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: const Color(0xFFF7F1E3),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: emerald),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: cardLight,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: cardLineLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chipRadius),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: chipLight,
        selectedColor: goldLight,
        labelStyle: TextStyle(
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: StadiumBorder(
          side: BorderSide(color: cardLineLight, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chipLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: cardLineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: cardLineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: emerald, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: Color(0xFF1A2E28),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: emerald,
        unselectedItemColor: mutedLight,
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
      dialogTheme: DialogThemeData(
        backgroundColor: cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      textTheme: ThemeData.light().textTheme.copyWith(
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
            bodyMedium: const TextStyle(fontSize: 14, color: ink),
            bodySmall: const TextStyle(fontSize: 12, color: mutedLight),
            labelLarge: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: emeraldLight,
      secondary: goldDark,
      surface: nightCard,
      onPrimary: Color(0xFFF7F1E3),
      onSecondary: nightInk,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: nightBg,
      primaryColor: emeraldLight,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: nightBg,
        foregroundColor: nightInk,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: nightInk,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: nightCard,
        elevation: 3,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: cardLineDark, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: cardLineDark,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldLight,
          foregroundColor: const Color(0xFFF7F1E3),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: goldDarkLight),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: nightInk,
          backgroundColor: nightCard,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: cardLineDark, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chipRadius),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: chipDark,
        selectedColor: goldDark,
        labelStyle: TextStyle(
          color: nightInk,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: StadiumBorder(
          side: BorderSide(color: cardLineDark, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chipDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: cardLineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: cardLineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: goldDark, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: goldDark,
        foregroundColor: Color(0xFF1A2E28),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: nightCard,
        selectedItemColor: goldDarkLight,
        unselectedItemColor: mutedDark,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? goldDark : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? goldDark.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: nightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      textTheme: ThemeData.dark().textTheme.copyWith(
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: nightInk,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: nightInk,
            ),
            bodyMedium: const TextStyle(fontSize: 14, color: nightInk),
            bodySmall: const TextStyle(fontSize: 12, color: mutedDark),
            labelLarge: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: nightInk,
            ),
          ).apply(bodyColor: nightInk, displayColor: nightInk),
    );
  }
}

/// The 5 Quran reader themes (background / text / accent).
/// Untouched by the demo v13 pass — the reader keeps its own themes.
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
