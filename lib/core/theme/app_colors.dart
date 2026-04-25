import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary teal palette
  static const Color primary = Color(0xFF4ECDC4);
  static const Color primaryDark = Color(0xFF38B2A9);
  static const Color primaryLight = Color(0xFF80E8E2);

  // Accent coral/salmon palette
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF9A9A);

  // Background
  static const Color background = Color(0xFFF7FAFA);
  static const Color surface = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF1A2E44);
  static const Color textSecondary = Color(0xFF6B7C93);
  static const Color textLight = Color(0xFFB0BEC5);

  // Chart colors (matching the pie chart in the design)
  static const Color chartTeal = Color(0xFF4ECDC4);
  static const Color chartCoral = Color(0xFFFF6B6B);
  static const Color chartAmber = Color(0xFFFFBE0B);
  static const Color chartGreen = Color(0xFF2D9E6B);

  // Gradient for splash
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4ECDC4), Color(0xFF38B2A9), Color(0xFF2D9E8F)],
  );
}
