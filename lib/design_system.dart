import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Focus Accent Color (Single color for the focus state & branding)
  static const Color focusAccent = Color(0xFF8B5CF6); // 🟣 Deep Focus Purple

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

  // Light Mode Tokens
  static const AppColors light = AppColors(
    background: Color(0xFFFAFAFA),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE4E4E7),
    ring: Color(0xFF18181B),
    foreground: Color(0xFF09090B),
    muted: Color(0xFF71717A),
    primary: Color(0xFF18181B),
    onPrimary: Color(0xFFFFFFFF),
    softRedBg: Color(0xFFFEF2F2),
    softRedBorder: Color(0xFFFCA5A5),
    softRedText: Color(0xFF991B1B),
  );

  // Dark Mode Tokens
  static const AppColors dark = AppColors(
    background: Color(0xFF09090B),
    card: Color(0xFF18181B),
    border: Color(0xFF27272A),
    ring: Color(0xFFD4D4D8),
    foreground: Color(0xFFFAFAFA),
    muted: Color(0xFFA1A1AA),
    primary: Color(0xFFFAFAFA),
    onPrimary: Color(0xFF09090B),
    softRedBg: Color(0xFF450A0A),
    softRedBorder: Color(0xFF991B1B),
    softRedText: Color(0xFFFECACA),
  );
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
    return GoogleFonts.orbitron(
      fontSize: 56.0,
      fontWeight: FontWeight.bold,
      color: colors.foreground,
      letterSpacing: 2.0,
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
