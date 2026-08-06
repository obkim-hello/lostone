import 'package:flutter/material.dart';

/// Instagram-inspired design tokens and [ThemeData] for Lostone.
///
/// A clean, flat aesthetic: white surfaces, near-black text, a single blue
/// accent, hairline separators, and a bold typographic hierarchy. Content is
/// the focus; chrome recedes.
abstract final class AppTheme {
  /// Instagram's primary action blue, used for accents and primary buttons.
  static const Color accent = Color(0xFF0095F6);

  /// Near-black used for primary text and icons.
  static const Color ink = Color(0xFF262626);

  /// Muted gray used for secondary text and captions.
  static const Color muted = Color(0xFF8E8E8E);

  /// Hairline separator color between rows and sections.
  static const Color separator = Color(0xFFDBDBDB);

  /// Light fill used for inputs and pressed rows.
  static const Color fill = Color(0xFFFAFAFA);

  /// Screen and surface background.
  static const Color surface = Colors.white;

  /// Destructive action red.
  static const Color danger = Color(0xFFED4956);

  /// Standard horizontal gutter for screen content.
  static const double gutter = 16;

  /// Builds the light [ThemeData] expressing the tokens above.
  static ThemeData light() {
    const ColorScheme scheme = ColorScheme.light(
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      error: danger,
      onError: Colors.white,
    );
    final ThemeData base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      dividerColor: separator,
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 0.5,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accent.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? accent : separator,
        ),
        trackOutlineColor: WidgetStateProperty.all<Color>(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: separator,
        overlayColor: Color(0x1A0095F6),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            titleLarge: const TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            titleMedium: const TextStyle(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            bodyMedium: const TextStyle(color: ink, fontSize: 14),
            bodySmall: const TextStyle(color: muted, fontSize: 13),
          ),
    );
  }
}
