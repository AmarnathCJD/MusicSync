import 'package:flutter/material.dart';

class AppTones {
  static const Color ink = Color(0xFF111113);
  static const Color surface = Color(0xFF17171A);
  static const Color surfaceRaised = Color(0xFF1D1D21);
  static const Color hairline = Color(0xFF2A2A2F);
  static const Color textPrimary = Color(0xFFE8E6E1);
  static const Color textSecondary = Color(0xFF8E8B85);
  static const Color textMuted = Color(0xFF5E5C58);
  static const Color accent = Color(0xFFC58A5C);
  static const Color accentSoft = Color(0xFF3A2D24);
  static const Color positive = Color(0xFF7FA37A);
  static const Color negative = Color(0xFFB46B6B);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    surface: AppTones.surface,
    onSurface: AppTones.textPrimary,
    primary: AppTones.accent,
    onPrimary: AppTones.ink,
    secondary: AppTones.textSecondary,
    onSecondary: AppTones.ink,
    error: AppTones.negative,
    onError: AppTones.ink,
    outline: AppTones.hairline,
  );

  const textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.2,
      color: AppTones.textPrimary,
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
      color: AppTones.textPrimary,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: AppTones.textSecondary,
      height: 1.3,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppTones.textPrimary,
      height: 1.45,
    ),
    bodyMedium: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: AppTones.textPrimary,
      height: 1.45,
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
      letterSpacing: 0.6,
      color: AppTones.textSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.0,
      color: AppTones.textMuted,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppTones.ink,
    canvasColor: AppTones.ink,
    dividerColor: AppTones.hairline,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    sliderTheme: SliderThemeData(
      activeTrackColor: AppTones.accent,
      inactiveTrackColor: AppTones.hairline,
      thumbColor: AppTones.textPrimary,
      overlayColor: AppTones.accent.withOpacity(0.08),
      trackHeight: 2.0,
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 6,
        elevation: 0,
        pressedElevation: 0,
      ),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppTones.accent
            : AppTones.hairline,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppTones.accent
            : AppTones.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppTones.accentSoft
            : AppTones.surface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(AppTones.textPrimary),
        foregroundColor: const WidgetStatePropertyAll(AppTones.ink),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppTones.textSecondary),
        overlayColor: WidgetStatePropertyAll(AppTones.hairline.withOpacity(0.6)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppTones.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(color: AppTones.textMuted, fontSize: 13.5),
      labelStyle: const TextStyle(color: AppTones.textSecondary, fontSize: 12.5),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppTones.hairline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppTones.accent, width: 1),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppTones.surfaceRaised,
      contentTextStyle: TextStyle(color: AppTones.textPrimary, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppTones.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
