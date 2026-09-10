import 'package:flutter/material.dart';

/// Sistema de diseño profesional para MarthApp:
/// Modo oscuro híbrido basado en Glassmorfismo, Neumorfismo sutil ('Soft UI') y 'Liquid UI'.
class LiquidTheme {
  LiquidTheme._();

  // ===========================================================================
  // 1. Paleta Cromática Exacta
  // ===========================================================================

  /// Fondo principal (Canvas): #101419 (negro azulado profundo)
  static const Color darkBackground = Color(0xFF101419);

  /// Superficie de componentes base: #1A1F26
  static const Color surfaceDark = Color(0xFF1A1F26);

  /// Sombra oscura neumórfica: #0D1014 (para sombreado inferior/derecho y hendiduras)
  static const Color neumorphicDarkShadow = Color(0xFF0D1014);

  /// Brillo claro neumórfico: #222932 (para realce superior/izquierdo de bordes)
  static const Color neumorphicLightHighlight = Color(0xFF222932);

  /// Acento primario (Líquido): #7BB6FF (azul cian brillante)
  static const Color primaryLiquid = Color(0xFF7BB6FF);

  /// Alias retrocompatible para el acento primario
  static const Color primaryCyan = primaryLiquid;
  static const Color primaryIndigo = primaryLiquid;

  /// Acento secundario: #BD93F9 (lila suave)
  static const Color secondaryLilac = Color(0xFFBD93F9);

  /// Texto principal: #E6EDF3 (blanco azulado de alto contraste WCAG AA)
  static const Color textPrimary = Color(0xFFE6EDF3);

  /// Texto secundario y bordes estructurales: #8B9BB4
  static const Color textSecondary = Color(0xFF8B9BB4);
  static const Color structuralBorder = Color(0xFF8B9BB4);

  /// Acentos de estado complementarios (WCAG AA)
  static const Color accentEmerald = Color(0xFF50FA7B);
  static const Color accentCoral = Color(0xFFFF5E7E);

  // ===========================================================================
  // 2. Gradientes Líquidos (Liquid UI)
  // ===========================================================================

  /// Gradiente interactivo principal: linear-gradient(135deg, #7BB6FF 0%, #BD93F9 100%)
  static const LinearGradient liquidPrimaryGradient = LinearGradient(
    colors: [primaryLiquid, secondaryLilac],
    begin: Alignment(-0.707, -0.707), // 135 grados
    end: Alignment(0.707, 0.707),
  );

  /// Gradiente esmeralda para estados de éxito
  static const LinearGradient liquidEmeraldGradient = LinearGradient(
    colors: [Color(0xFF3ECF8E), Color(0xFF50FA7B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente púrpura/lila
  static const LinearGradient liquidPurpleGradient = LinearGradient(
    colors: [Color(0xFF9D65FF), secondaryLilac],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===========================================================================
  // 3. Sombras Neumórficas ('Soft UI' sutil sin bordes duros)
  // ===========================================================================

  /// Doble sombra suave para elementos elevados (Soft UI)
  static List<BoxShadow> neumorphicRaisedShadows({
    Color baseColor = surfaceDark,
  }) =>
      [
        BoxShadow(
          color: neumorphicDarkShadow.withValues(alpha: 0.9),
          offset: const Offset(4, 4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: neumorphicLightHighlight.withValues(alpha: 0.7),
          offset: const Offset(-3, -3),
          blurRadius: 8,
        ),
      ];

  /// Doble sombra suave para elementos incrustados / hendiduras (Inset)
  static List<BoxShadow> neumorphicInsetShadows() => [
        BoxShadow(
          color: neumorphicDarkShadow.withValues(alpha: 0.8),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: neumorphicLightHighlight.withValues(alpha: 0.4),
          offset: const Offset(-2, -2),
          blurRadius: 4,
        ),
      ];

  // ===========================================================================
  // 4. Parámetros Glassmorphism
  // ===========================================================================

  /// Opacidad entre 65% y 75% sobre #1A1F26
  static Color get glassSurfaceColor => surfaceDark.withValues(alpha: 0.70);

  /// Borde estructural sutil: 1px solid rgba(139, 155, 180, 0.2)
  static Color get glassBorderColor => structuralBorder.withValues(alpha: 0.20);

  /// Desenfoque por defecto de 20px
  static const double glassBlur = 20.0;

  // ===========================================================================
  // 5. Tema Global Flutter (Material 3 Dark Mode)
  // ===========================================================================

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryLiquid,
        secondary: secondaryLilac,
        surface: surfaceDark,
        error: accentCoral,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark.withValues(alpha: 0.65),
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: glassBorderColor,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: glassBorderColor,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primaryLiquid,
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
