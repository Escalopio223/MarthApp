import 'package:flutter/material.dart';

/// Sistema de diseño Liquid UI con soporte para Glassmorfismo y Neumorfismo
class LiquidTheme {
  LiquidTheme._();

  // Paleta de colores Liquid
  static const Color darkBackground = Color(0xFF090D16);
  static const Color surfaceDark = Color(0xFF131B2A);
  static const Color primaryCyan = Color(0xFF00F2FE);
  static const Color primaryIndigo = Color(0xFF4FACFE);
  static const Color accentEmerald = Color(0xFF3ECF8E);
  static const Color accentCoral = Color(0xFFFF5E7E);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  // Gradientes Liquid
  static const LinearGradient liquidPrimaryGradient = LinearGradient(
    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liquidEmeraldGradient = LinearGradient(
    colors: [Color(0xFF0BA360), Color(0xFF3ECF8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liquidPurpleGradient = LinearGradient(
    colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Sombras Neumórficas
  static List<BoxShadow> neumorphicRaisedShadows({
    Color baseColor = surfaceDark,
  }) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          offset: const Offset(4, 4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.06),
          offset: const Offset(-3, -3),
          blurRadius: 8,
        ),
      ];

  static List<BoxShadow> neumorphicInsetShadows() => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.04),
          offset: const Offset(-2, -2),
          blurRadius: 4,
        ),
      ];

  // Tema global de Flutter
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: accentEmerald,
        surface: surfaceDark,
        error: accentCoral,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primaryCyan,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: accentCoral,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: accentCoral,
            width: 2,
          ),
        ),
      ),
    );
  }
}
