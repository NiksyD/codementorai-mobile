import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand Primary Accents (Web Emerald / Mint Green Theme)
  static const Color primary = Color(0xFF3ECF8E);
  static const Color primaryVariant = Color(0xFF059669);
  static const Color accent = Color(0xFF10B981);

  // Dark Theme Tokens (Deep Space Slate & Emerald Mint Accent)
  static const Color darkBackground = Color(0xFF0E1118);
  static const Color darkSurface = Color(0xFF151922);
  static const Color darkSurfaceCard = Color(0xFF1A1F2C);
  static const Color darkBorder = Color(0xFF222733);
  static const Color darkTextPrimary = Color(0xFFF4F5F7);
  static const Color darkTextSecondary = Color(0xFFC4C7C5);

  // Light Theme Tokens (Google Material Light & Emerald Accent)
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFF0F4F9);
  static const Color lightBorder = Color(0xFFE1E7F0);
  static const Color lightTextPrimary = Color(0xFF1F1F1F);
  static const Color lightTextSecondary = Color(0xFF44474F);

  // Functional Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFF3ECF8E), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: <Color>[Color(0xFF1A1F2C), Color(0xFF151922)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF0F4F9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
