import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // MUST University Brand Colors - Updated with exact green from image
  static const Color primaryGreen = Color(0xFF8BC34A); // The exact green from your image
  static const Color primaryDark = Color(0xFF689F38); // Darker version for depth
  static const Color secondaryOrange = Color(0xFFFFA500); // Bright Orange from image
  static const Color royalBlue = Color(0xFF0033CC); // Original blue color
  static const Color maroon = Color(0xFF800000); // Traditional university color

  // Primary colors (using MUST branding)
  static const Color primary = primaryGreen;
  static const Color primaryBlue = royalBlue;

  // Secondary colors
  static const Color secondary = secondaryOrange;
  static const Color secondaryDark = Color(0xFFFF8C00); // Darker orange
  static const Color accent = secondaryOrange;

  // Semantic Colors
  static const Color success = Color(0xFF32CD32); // Bright Lime Green
  static const Color warning = Color(0xFFFFA500); // Bright Orange
  static const Color error = Color(0xFFE53935); // Red
  static const Color info = Color(0xFF0033CC); // Exact blue from first image

  // Text Colors
  static const Color textPrimary = Color(0xFF212121); // Dark Gray
  static const Color textSecondary = Color(0xFF757575); // Medium Gray
  static const Color textLight = Color(0xFFFFFFFF); // White
  static const Color textDark = Color(0xFF212121);
  static const Color textGray = Color(0xFF757575);

  // Background Colors
  static const Color background = Color(0xFFFAFAFA); // Light Gray
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color card = Color(0xFFFFFFFF); // White
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Border colors
  static const Color borderLight = Color(0xFFE0E0E0); // Light Gray dividers
  static const Color borderMedium = Color(0xFFBDBDBD);

  // Gradients - REMOVED FOR FLAT DESIGN (like MUST website)
  // Using solid colors only for clean, professional appearance
  
  // Support service colors (updated with MUST theme)
  static const Color emergency = error;
  static const Color danger = error;
  static const Color counseling = maroon;
  static const Color legal = royalBlue;
  static const Color medical = primaryGreen;
  static const Color information = info;

  // Icon background colors (updated)
  static const Color iconBlueBg = Color(0xFFE3F2FD);
  static const Color iconGreenBg = Color(0xFFE8F5E8);
  static const Color iconRedBg = Color(0xFFFFEBEE);
  static const Color iconGrayBg = Color(0xFFF5F5F5);
  static const Color iconOrangeBg = Color(0xFFFFF3E0);
  
  // Component specific colors
  static const Color inputFill = Color(0xFFF5F5F5); // Light gray fill for inputs
  static const Color badgeAmber = Color(0xFFFFC107); // Amber for badges
  static const Color avatarOrange = secondaryOrange;
  static const Color onlineGreen = primaryGreen;

  // Dark mode colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF2C2C2C);
  static const Color darkAppBar = Color(0xFF1E1E1E);

  // Legacy MUST colors (for backward compatibility)
  static const Color mustGold = secondaryOrange; // Using bright orange instead of gold
  static const Color mustGoldLight = Color(0xFFFFB347); // Light orange
  static const Color mustBlue = royalBlue;
  static const Color mustBlueMedium = Color(0xFF0044DD); // Medium blue matching the theme
  static const Color mustGreen = primaryGreen;
  static const Color mustGreenLight = Color(0xFF90EE90); // Light lime green
}
