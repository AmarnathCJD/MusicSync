import 'package:flutter/material.dart';

/// Cinematic, layered dark palette. Tones are deliberately close in luminance
/// so depth comes from subtle tonal shifts rather than borders or shadows.
class AppTones {
  // Background layers (darkest -> lightest)
  static const Color bg0 = Color(0xFF0B0F14); // deepest ambient
  static const Color bg1 = Color(0xFF11161D); // primary canvas
  static const Color bg2 = Color(0xFF161C25); // raised panel
  static const Color bg3 = Color(0xFF1D2530); // hover / active panel
  static const Color bg4 = Color(0xFF252E3B); // control surface

  // Atmospheric bloom (used as faint radial wash in the background)
  static const Color bloom = Color(0xFF1E3346);

  // Hairlines & borders — kept extremely subtle, used sparingly
  static const Color line = Color(0x1AFFFFFF); // 10% white
  static const Color lineSoft = Color(0x0DFFFFFF); // 5% white

  // Text
  static const Color textPrimary = Color(0xFFE6ECF2);
  static const Color textSecondary = Color(0xFF9AA4B2);
  static const Color textMuted = Color(0xFF5E6877);

  // Accent — icy cyan, used very sparingly
  static const Color accent = Color(0xFF7CCBE6);
  static const Color accentDim = Color(0xFF3B6E84);
  static const Color accentGlow = Color(0x337CCBE6);

  // Status
  static const Color positive = Color(0xFF8FCBA8);
  static const Color negative = Color(0xFFD58A8A);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    surface: AppTones.bg1,
    onSurface: AppTones.textPrimary,
    surfaceContainerHighest: AppTones.bg2,
    primary: AppTones.accent,
    onPrimary: AppTones.bg0,
    secondary: AppTones.textSecondary,
    onSecondary: AppTones.bg0,
    error: AppTones.negative,
    onError: AppTones.bg0,
    outline: AppTones.line,
  );

  const textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: AppTones.textPrimary,
      height: 1.2,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppTones.textPrimary,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: AppTones.textPrimary,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: AppTones.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w400,
      color: AppTones.textPrimary,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: AppTones.textSecondary,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: AppTones.textSecondary,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppTones.textPrimary,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
      color: AppTones.textMuted,
    ),
    labelSmall: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
      color: AppTones.textMuted,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppTones.bg0,
    canvasColor: AppTones.bg0,
    dividerColor: AppTones.line,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    sliderTheme: SliderThemeData(
      activeTrackColor: AppTones.accent,
      inactiveTrackColor: AppTones.bg4,
      thumbColor: AppTones.textPrimary,
      overlayColor: AppTones.accentGlow,
      trackHeight: 3.0,
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 7,
        elevation: 0,
        pressedElevation: 0,
      ),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppTones.accent
            : AppTones.line,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppTones.accent
            : AppTones.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppTones.accent.withValues(alpha: 0.18)
            : AppTones.bg3,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(AppTones.accent),
        foregroundColor: const WidgetStatePropertyAll(AppTones.bg0),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppTones.textSecondary),
        overlayColor: WidgetStatePropertyAll(AppTones.bg3.withValues(alpha: 0.6)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppTones.bg2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppTones.textMuted, fontSize: 13.5),
      labelStyle: const TextStyle(color: AppTones.textSecondary, fontSize: 12.5),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTones.line, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTones.accent, width: 1),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppTones.bg3,
      contentTextStyle: const TextStyle(
          color: AppTones.textPrimary, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppTones.bg2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
