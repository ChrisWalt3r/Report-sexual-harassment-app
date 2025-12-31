import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF6200EE);
  static const Color primaryDark = Color(0xFF3700B3);
  static const Color primaryBlue = Color(0xFF1976D2);

  // Secondary colors
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryDark = Color(0xFF018786);
  static const Color accent = Color(0xFFBB86FC);

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F0F0);
  static const Color card = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDark = Color(0xFF212121);
  static const Color textGray = Color(0xFF757575);
  static const Color textLight = Color(0xFFA0A0A0);

  // Status colors
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);

  // Support service colors
  static const Color emergency = Color(0xFFD32F2F);
  static const Color counseling = Color(0xFF7B1FA2);
  static const Color legal = Color(0xFF1976D2);
  static const Color medical = Color(0xFF388E3C);
  static const Color information = Color(0xFF455A64);

  // Icon background colors
  static const Color iconBlueBg = Color(0xFFDBEAFE);
  static const Color iconGreenBg = Color(0xFFD1FAE5);
  static const Color iconRedBg = Color(0xFFFEE2E2);
  static const Color iconGrayBg = Color(0xFFF3F4F6);
  static const Color iconYellowBg = Color(0xFFFEF3C7);
  
  // Accent colors
  static const Color avatarOrange = Color(0xFFFED7AA);
  static const Color onlineGreen = Color(0xFF10B981);
  
  // Aliases for backwards compatibility
  static const Color primary = primaryBlue;
  static const Color textPrimary = textDark;
  static const Color textSecondary = textGray;
}
