import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary: Electric Blue — trustworthy, educational
  static const Color primary = Color(0xFF1D4ED8);
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF1E3A8A);

  // Secondary: Amber — energetic, rewarding (XP, streaks)
  static const Color secondary = Color(0xFFD97706);
  static const Color secondaryContainer = Color(0xFFFEF3C7);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF78350F);

  // Tertiary: Emerald — success, correct answers
  static const Color tertiary = Color(0xFF059669);
  static const Color tertiaryContainer = Color(0xFFD1FAE5);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF064E3B);

  // Error
  static const Color error = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF7F1D1D);

  // Surface
  static const Color surface = Color(0xFFFAFAFF);
  static const Color surfaceVariant = Color(0xFFEEF2FF);
  static const Color onSurface = Color(0xFF1E1B4B);
  static const Color onSurfaceVariant = Color(0xFF4B5563);
  static const Color outline = Color(0xFFD1D5DB);
  static const Color outlineVariant = Color(0xFFE5E7EB);

  // Dark mode surfaces
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceVariantDark = Color(0xFF1E293B);
  static const Color onSurfaceDark = Color(0xFFE2E8F0);

  // Microsoft brand (for sign-in button)
  static const Color microsoftBlue = Color(0xFF0078D4);
}
