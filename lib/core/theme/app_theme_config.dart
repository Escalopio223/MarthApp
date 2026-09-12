import 'package:flutter/material.dart';

/// Identificadores de los 10 temas core curados en MarthApp (5 oscuros, 5 claros)
enum ThemeId {
  // Temas Oscuros (5)
  midnightSlate,
  obsidianAmethyst,
  carbonEclipse,
  nordicFrost,
  sunsetDusk,

  // Temas Claros (5)
  softClay,
  sageBotanical,
  porcelainChalk,
  lavenderClay,
  terracottaDune,
}

/// Definición inmutable de un tema dentro del sistema de diseño Claymórfico
class AppThemeConfig {
  final ThemeId id;
  final String name;
  final String tag;
  final bool isDark;

  // Paleta de colores base
  final Color bgCanvas;
  final Color bgSurface;
  final Color shadowDark;
  final Color shadowLight;
  final Color accentPrimary;
  final Color accentSecondary;
  final List<Color> actionGradientColors;
  final Color textPrimary;
  final Color textSecondary;
  final Color ctaTextColor;

  const AppThemeConfig({
    required this.id,
    required this.name,
    required this.tag,
    required this.isDark,
    required this.bgCanvas,
    required this.bgSurface,
    required this.shadowDark,
    required this.shadowLight,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.actionGradientColors,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctaTextColor,
  });

  // ===========================================================================
  // 1. Modelado Volumétrico Claymórfico (Superficies & Relieve 3D Ergonómico)
  // ===========================================================================

  /// Micro-gradiente diagonal sutil (135°) para generar curvatura volumétrica 3D en la arcilla.
  /// Simula iluminación cenital-izquierda para un relieve almohadillado táctil.
  LinearGradient claySurfaceGradient({Color? baseColor}) {
    final effectiveColor = baseColor ?? bgSurface;
    final topHighlight = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.07), effectiveColor)
        : Color.alphaBlend(Colors.white.withValues(alpha: 0.45), effectiveColor);
    final bottomShade = isDark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.10), effectiveColor)
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.05), effectiveColor);

    return LinearGradient(
      colors: [topHighlight, bottomShade],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Sistema de dobles sombras contenidas para elevación táctil ("Controlled Clay").
  /// Evita solapamientos en listas densas limitando el blur a 10px.
  List<BoxShadow> clayRaisedShadows({
    Color? baseColor,
    bool isPressed = false,
  }) {
    if (isPressed) {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: isDark ? 0.35 : 0.15),
          offset: const Offset(1, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: isDark ? 0.15 : 0.60),
          offset: const Offset(-1, -1),
          blurRadius: 3,
        ),
      ];
    }

    if (isDark) {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.45),
          offset: const Offset(3, 4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.22),
          offset: const Offset(-2, -2),
          blurRadius: 6,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.32),
          offset: const Offset(3, 5),
          blurRadius: 10,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.90),
          offset: const Offset(-2, -2),
          blurRadius: 6,
        ),
      ];
    }
  }

  /// Sombra incrustada / hendidura cóncava para campos de texto y elementos incrustados
  List<BoxShadow> clayInsetShadows() {
    if (isDark) {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.45),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.15),
          offset: const Offset(-1, -1),
          blurRadius: 3,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.25),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.85),
          offset: const Offset(-1, -1),
          blurRadius: 3,
        ),
      ];
    }
  }

  // ===========================================================================
  // 2. Gradientes de Acción y Bordes Estructurales
  // ===========================================================================

  /// Gradiente dinámico de acción principal a 135°
  LinearGradient get actionGradient => LinearGradient(
        colors: actionGradientColors,
        begin: const Alignment(-0.707, -0.707),
        end: const Alignment(0.707, 0.707),
      );

  /// Borde estructural moderado para delimitar componentes de arcilla
  Color get cardBorderColor =>
      textSecondary.withValues(alpha: isDark ? 0.15 : 0.18);

  // Alias retrocompatibles para migración fluida
  LinearGradient get liquidPrimaryGradient => actionGradient;
  Color get glassBorderColor => cardBorderColor;
  Color get glassSurfaceColor => bgSurface;
  double get glassBlur => 0.0;
  List<BoxShadow> neumorphicRaisedShadows({Color? baseColor}) =>
      clayRaisedShadows(baseColor: baseColor);
  List<BoxShadow> neumorphicInsetShadows() => clayInsetShadows();

  // ===========================================================================
  // 3. ThemeData Dinámico de Flutter (Material 3)
  // ===========================================================================

  ThemeData get themeData {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgCanvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentPrimary,
        onPrimary: ctaTextColor,
        secondary: accentSecondary,
        onSecondary: Colors.white,
        surface: bgSurface,
        onSurface: textPrimary,
        error: const Color(0xFFFF5E7E),
        onError: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Color.alphaBlend(Colors.black.withValues(alpha: 0.18), bgSurface)
            : Color.alphaBlend(shadowDark.withValues(alpha: 0.12), bgSurface),
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.75),
          fontSize: 14,
        ),
        labelStyle: TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cardBorderColor,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cardBorderColor,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: accentPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFF5E7E),
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFF5E7E),
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Catálogo de los 10 temas core curados (5 oscuros y 5 claros)
class AppThemes {
  AppThemes._();

  // ===========================================================================
  // 5 Temas Oscuros
  // ===========================================================================

  /// 1. Midnight Slate (Tema Base Oficial / Oscuro Elegante)
  static const AppThemeConfig midnightSlate = AppThemeConfig(
    id: ThemeId.midnightSlate,
    name: 'Midnight Slate',
    tag: 'Oscuro Elegante / Pizarra Azul',
    isDark: true,
    bgCanvas: Color(0xFF10141D),
    bgSurface: Color(0xFF1A202C),
    shadowDark: Color(0xFF0B0F15),
    shadowLight: Color(0xFF2D3748),
    accentPrimary: Color(0xFF38BDF8), // Sky Cyan
    accentSecondary: Color(0xFF818CF8), // Soft Indigo
    actionGradientColors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
    textPrimary: Color(0xFFF1F5F9), // Slate 100 (Ratio > 12:1)
    textSecondary: Color(0xFF94A3B8), // Slate 400 (Ratio > 6:1)
    ctaTextColor: Color(0xFF0F172A),
  );

  /// 2. Obsidian Amethyst (Oscuro con Alta Personalidad)
  static const AppThemeConfig obsidianAmethyst = AppThemeConfig(
    id: ThemeId.obsidianAmethyst,
    name: 'Obsidian Amethyst',
    tag: 'Oscuro Personalidad / Místico',
    isDark: true,
    bgCanvas: Color(0xFF130D1E),
    bgSurface: Color(0xFF1F1530),
    shadowDark: Color(0xFF0A0610),
    shadowLight: Color(0xFF2F204A),
    accentPrimary: Color(0xFFA855F7), // Purple 500
    accentSecondary: Color(0xFFEC4899), // Pink 500
    actionGradientColors: [Color(0xFF7E22CE), Color(0xFF9D174D)], // Contrast > 7:1 con blanco
    textPrimary: Color(0xFFF3EEFA), // Lavanda clara (Ratio > 11:1)
    textSecondary: Color(0xFFA798BA), // (Ratio > 5.5:1)
    ctaTextColor: Colors.white,
  );

  /// 3. Carbon Eclipse (Monocromático Dark / Industrial)
  static const AppThemeConfig carbonEclipse = AppThemeConfig(
    id: ThemeId.carbonEclipse,
    name: 'Carbon Eclipse',
    tag: 'Monocromático Dark / Alto Contraste',
    isDark: true,
    bgCanvas: Color(0xFF121214),
    bgSurface: Color(0xFF1C1D21),
    shadowDark: Color(0xFF0A0A0B),
    shadowLight: Color(0xFF2B2C33),
    accentPrimary: Color(0xFFF8FAFC), // Pure White Platinum
    accentSecondary: Color(0xFF94A3B8), // Steel Slate
    actionGradientColors: [Color(0xFFF8FAFC), Color(0xFFCBD5E1)],
    textPrimary: Color(0xFFF8FAFC), // (Ratio > 15:1)
    textSecondary: Color(0xFF94A3B8), // (Ratio > 6:1)
    ctaTextColor: Color(0xFF0F172A),
  );

  /// 4. Nordic Frost (Oscuro Glacial / Teal & Cian)
  static const AppThemeConfig nordicFrost = AppThemeConfig(
    id: ThemeId.nordicFrost,
    name: 'Nordic Frost',
    tag: 'Oscuro Glacial / Teal & Cian',
    isDark: true,
    bgCanvas: Color(0xFF0B131E),
    bgSurface: Color(0xFF14202E),
    shadowDark: Color(0xFF060B12),
    shadowLight: Color(0xFF223247),
    accentPrimary: Color(0xFF14B8A6), // Teal 500
    accentSecondary: Color(0xFF06B6D4), // Cyan 500
    actionGradientColors: [Color(0xFF0F766E), Color(0xFF0E7490)], // Teal & Cyan intensos (> 5:1 con blanco)
    textPrimary: Color(0xFFF1F5F9), // Slate 100 (Ratio > 14:1)
    textSecondary: Color(0xFF94A3B8), // Slate 400 (Ratio > 6:1)
    ctaTextColor: Colors.white,
  );

  /// 5. Sunset Dusk (Oscuro Crepúsculo / Ámbar & Rosa)
  static const AppThemeConfig sunsetDusk = AppThemeConfig(
    id: ThemeId.sunsetDusk,
    name: 'Sunset Dusk',
    tag: 'Oscuro Crepúsculo / Ámbar & Rosa',
    isDark: true,
    bgCanvas: Color(0xFF161016),
    bgSurface: Color(0xFF241822),
    shadowDark: Color(0xFF0D080D),
    shadowLight: Color(0xFF382635),
    accentPrimary: Color(0xFFF97316), // Amber Orange
    accentSecondary: Color(0xFFFB7185), // Neon Rose
    actionGradientColors: [Color(0xFFC2410C), Color(0xFFBE123C)], // Atardecer (> 5.5:1 con blanco)
    textPrimary: Color(0xFFFFF1F2), // Rose 50 (Ratio > 15:1)
    textSecondary: Color(0xFFBDA1B4), // (Ratio > 6:1)
    ctaTextColor: Colors.white,
  );

  // ===========================================================================
  // 5 Temas Claros
  // ===========================================================================

  /// 6. Soft Clay (Claro Cálido / Cerámico Artesanal)
  static const AppThemeConfig softClay = AppThemeConfig(
    id: ThemeId.softClay,
    name: 'Soft Clay',
    tag: 'Claro Cálido / Terracota',
    isDark: false,
    bgCanvas: Color(0xFFF5F2EE),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFDED8D0),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFFD95D39), // Terracota Clay
    accentSecondary: Color(0xFFF28E2B), // Ocre Cálido
    actionGradientColors: [Color(0xFF9A3412), Color(0xFFC2410C)], // Arcilla horneada (Contrast > 6:1)
    textPrimary: Color(0xFF261E1A), // Espresso (Ratio > 13:1)
    textSecondary: Color(0xFF7A6B63), // (Ratio > 5:1)
    ctaTextColor: Colors.white,
  );

  /// 7. Sage Botanical (Claro Fresco / Botánico)
  static const AppThemeConfig sageBotanical = AppThemeConfig(
    id: ThemeId.sageBotanical,
    name: 'Sage Botanical',
    tag: 'Claro Fresco / Botánico',
    isDark: false,
    bgCanvas: Color(0xFFF0F5F2),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFCFDDD4),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFF15803D), // Forest Green
    accentSecondary: Color(0xFF22C55E), // Fresh Green
    actionGradientColors: [Color(0xFF14532D), Color(0xFF166534)], // Bosque profundo (Contrast > 8:1)
    textPrimary: Color(0xFF0F261B), // Bosque profundo (Ratio > 14:1)
    textSecondary: Color(0xFF537060), // (Ratio > 5.5:1)
    ctaTextColor: Colors.white,
  );

  /// 8. Porcelain Chalk (Monocromático Light / Nórdico)
  static const AppThemeConfig porcelainChalk = AppThemeConfig(
    id: ThemeId.porcelainChalk,
    name: 'Porcelain Chalk',
    tag: 'Monocromático Light / Alto Contraste',
    isDark: false,
    bgCanvas: Color(0xFFF4F5F7),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFD4D7DE),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFF111827), // Tinta Negra
    accentSecondary: Color(0xFF374151), // Grafito
    actionGradientColors: [Color(0xFF111827), Color(0xFF374151)],
    textPrimary: Color(0xFF111827), // (Ratio > 16:1)
    textSecondary: Color(0xFF4B5563), // (Ratio > 6.5:1)
    ctaTextColor: Colors.white,
  );

  /// 9. Lavender Clay (Claro Pastel / Lavanda & Violeta)
  static const AppThemeConfig lavenderClay = AppThemeConfig(
    id: ThemeId.lavenderClay,
    name: 'Lavender Clay',
    tag: 'Claro Pastel / Lavanda & Violeta',
    isDark: false,
    bgCanvas: Color(0xFFF3EEFA),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFDDD2EB),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFF7C3AED), // Violet 600
    accentSecondary: Color(0xFF6366F1), // Indigo 500
    actionGradientColors: [Color(0xFF5B21B6), Color(0xFF4338CA)], // Violeta & Índigo imperial (> 9:1 con blanco)
    textPrimary: Color(0xFF231738), // Violeta profundo (Ratio > 15:1)
    textSecondary: Color(0xFF6E5F80), // (Ratio > 5:1)
    ctaTextColor: Colors.white,
  );

  /// 10. Terracotta Dune (Claro Desértico / Óxido & Arena)
  static const AppThemeConfig terracottaDune = AppThemeConfig(
    id: ThemeId.terracottaDune,
    name: 'Terracotta Dune',
    tag: 'Claro Desértico / Óxido & Arena',
    isDark: false,
    bgCanvas: Color(0xFFFAF5EE),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFE5DDD0),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFFC2410C), // Rust Terracotta
    accentSecondary: Color(0xFFEA580C), // Warm Rust
    actionGradientColors: [Color(0xFF9A3412), Color(0xFFC2410C)], // Duna tostada (> 6:1 con blanco)
    textPrimary: Color(0xFF2B1D16), // Espresso oscuro (Ratio > 14:1)
    textSecondary: Color(0xFF786256), // (Ratio > 5:1)
    ctaTextColor: Colors.white,
  );

  // ===========================================================================
  // Agrupaciones y Consultas
  // ===========================================================================

  static const List<AppThemeConfig> all = [
    midnightSlate,
    obsidianAmethyst,
    carbonEclipse,
    nordicFrost,
    sunsetDusk,
    softClay,
    sageBotanical,
    porcelainChalk,
    lavenderClay,
    terracottaDune,
  ];

  static const List<AppThemeConfig> darkThemes = [
    midnightSlate,
    obsidianAmethyst,
    carbonEclipse,
    nordicFrost,
    sunsetDusk,
  ];

  static const List<AppThemeConfig> lightThemes = [
    softClay,
    sageBotanical,
    porcelainChalk,
    lavenderClay,
    terracottaDune,
  ];

  // Alias retrocompatible para arranque
  static const AppThemeConfig midnightBlue = midnightSlate;

  /// Obtiene un tema por su id con fallback seguro a midnightSlate
  static AppThemeConfig fromId(String? idName) {
    if (idName == null) return midnightSlate;
    return all.firstWhere(
      (theme) => theme.id.name == idName,
      orElse: () => midnightSlate,
    );
  }
}
