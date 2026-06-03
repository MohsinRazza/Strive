import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ThemePreference { system, light, dark }

enum AccentTheme {
  purple('Purple', Color(0xFF8B5CF6)),
  darkBrown('Dark Brown', Color(0xFF795548)),
  cyan('Cyan', Color(0xFF06B6D4)),
  skyBlue('Sky Blue', Color(0xFF0EA5E9)),
  orangeBeige('Orange Beige', Color(0xFFF97316)); // Accent is orange

  final String label;
  final Color color;
  const AccentTheme(this.label, this.color);
}

class AppColors {
  final Color focusAccent;
  
  // Semantic Design Tokens for Light/Dark Mode
  final Color background;
  final Color card;
  final Color border;
  final Color ring;
  final Color foreground;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color softRedBg;
  final Color softRedBorder;
  final Color softRedText;

  const AppColors({
    required this.focusAccent,
    required this.background,
    required this.card,
    required this.border,
    required this.ring,
    required this.foreground,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.softRedBg,
    required this.softRedBorder,
    required this.softRedText,
  });

  // Factory to generate colors based on mode and accent
  factory AppColors.get({required bool isDark, required AccentTheme accent}) {
    final focusColor = accent.color;
    
    // For Orange Beige, we give the light theme a slight beige tint
    final bool isBeigeLight = accent == AccentTheme.orangeBeige && !isDark;

    if (isDark) {
      return AppColors(
        focusAccent: focusColor,
        background: const Color(0xFF09090B),
        card: const Color(0xFF18181B),
        border: const Color(0xFF27272A),
        ring: const Color(0xFFD4D4D8),
        foreground: const Color(0xFFFAFAFA),
        muted: const Color(0xFFA1A1AA),
        primary: const Color(0xFFFAFAFA),
        onPrimary: const Color(0xFF09090B),
        softRedBg: const Color(0xFF450A0A),
        softRedBorder: const Color(0xFF991B1B),
        softRedText: const Color(0xFFFECACA),
      );
    } else {
      return AppColors(
        focusAccent: focusColor,
        background: isBeigeLight ? const Color(0xFFFDFBF7) : const Color(0xFFFAFAFA),
        card: const Color(0xFFFFFFFF),
        border: isBeigeLight ? const Color(0xFFEFE8DE) : const Color(0xFFE4E4E7),
        ring: const Color(0xFF18181B),
        foreground: const Color(0xFF09090B),
        muted: const Color(0xFF71717A),
        primary: const Color(0xFF18181B),
        onPrimary: const Color(0xFFFFFFFF),
        softRedBg: const Color(0xFFFEF2F2),
        softRedBorder: const Color(0xFFFCA5A5),
        softRedText: const Color(0xFF991B1B),
      );
    }
  }
}

class AppDesign {
  // Border Radius
  static const double borderRadiusInput = 8.0;
  static const double borderRadiusCard = 12.0;

  // Transitions
  static const Duration transitionDuration = Duration(milliseconds: 140);
  static const Curve transitionCurve = Curves.linear;

  // Typography Styles
  static TextStyle getTimerStyle(AppColors colors) {
    return GoogleFonts.outfit(
      fontSize: 56.0,
      fontWeight: FontWeight.w300,
      color: colors.foreground,
      letterSpacing: -2.0,
      fontFeatures: [const FontFeature.tabularFigures()],
    );
  }

  static TextStyle getAppHeaderStyle(AppColors colors) {
    return TextStyle(
      fontSize: 18.0,
      fontWeight: FontWeight.w600,
      color: colors.foreground,
      letterSpacing: -0.5,
    );
  }

  static TextStyle getWidgetHeaderStyle(AppColors colors) {
    return TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      color: colors.muted,
      letterSpacing: -0.2,
    );
  }

  static TextStyle getLogFeedStyle(AppColors colors) {
    return TextStyle(
      fontSize: 13.0,
      fontWeight: FontWeight.normal,
      color: colors.foreground,
    );
  }

  static TextStyle getBodyMutedStyle(AppColors colors) {
    return TextStyle(
      fontSize: 13.0,
      fontWeight: FontWeight.normal,
      color: colors.muted,
    );
  }
}
