import 'package:flutter/material.dart';

/// Design tokens matching the SleepLikeABaby Alarm Pin & Railway branding:
/// Warm Sand Background (#ECE7DE), Obsidian Railway Black (#181818),
/// and Electric Alarm Pin Crimson (#FF3722).
class AppColors {
  AppColors._();

  // Signature Brand Identity Palette
  static const Color brandRed = Color(0xFFFF3722); // Alarm Pin Crimson Red-Orange
  static const Color brandRedDark = Color(0xFFD92714);
  static const Color brandRedLight = Color(0xFFFF6654);
  static const Color brandBlack = Color(0xFF181818); // Railway Obsidian Black
  static const Color brandBlackElevated = Color(0xFF242424);
  static const Color brandSand = Color(0xFFECE7DE); // Warm Sand / Canvas Cream
  static const Color brandSandLight = Color(0xFFF7F5F0);
  static const Color brandSandBorder = Color(0xFFDDD7CC);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFECE7DE); // Warm Sand Canvas
  static const Color surface = Color(0xFFFFFFFF); // Clean Crisp White Cards
  static const Color surfaceVariant = Color(0xFFF7F5F0); // Warm Soft Sand Surface
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFDDD7CC); // Soft Stone Border

  // Functional Primary & Secondary
  static const Color primary = Color(0xFFFF3722); // Alarm Pin Crimson
  static const Color primaryLight = Color(0xFFFF6654);
  static const Color primaryDark = Color(0xFFD92714);
  static const Color secondary = Color(0xFF181818); // Railway Obsidian
  static const Color secondaryLight = Color(0xFF383838);

  // Status & Alarm Accents
  static const Color alarmRed = Color(0xFFFF3722);
  static const Color alarmPulse = Color(0xFFD92714);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF0F9D58);
  static const Color infoBlue = Color(0xFF1A73E8);

  // Google Maps Compatibility Aliases
  static const Color googleBlue = Color(0xFFFF3722); // Mapped to Brand Crimson for cohesive styling
  static const Color googleBlueLight = Color(0xFFFF6654);
  static const Color googleGreen = Color(0xFF0F9D58);
  static const Color googleGreenLight = Color(0xFF81C995);
  static const Color googleRed = Color(0xFFFF3722);
  static const Color googleYellow = Color(0xFFF59E0B);
  static const Color googleRouteBlue = Color(0xFFFF3722); // Crimson route line

  // Typography Colors
  static const Color textPrimary = Color(0xFF181818); // Deep Railway Obsidian
  static const Color textSecondary = Color(0xFF5F5B54); // Warm Slate Charcoal
  static const Color textMuted = Color(0xFF8C867C); // Soft Sandstone
  static const Color textInverse = Color(0xFFFFFFFF); // Pure White on dark/red

  // Map and Geofence Overlays
  static const Color geofenceFill = Color(0x28FF3722); // Soft Crimson Halo
  static const Color geofenceStroke = Color(0xFFFF3722);
  static const Color accuracyCircle = Color(0x22181818); // Soft Obsidian Halo

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFFF3722), Color(0xFFD92714)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alarmGradient = LinearGradient(
    colors: [Color(0xFFFF3722), Color(0xFFB51C0C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F5F0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
