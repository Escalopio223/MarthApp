import 'package:flutter/material.dart';

/// Identificadores de los 10 temas disponibles en MarthApp
enum ThemeId {
  // 5 Temas Oscuros
  midnightBlue,
  cyberEmerald,
  obsidianCrimson,
  deepAmethyst,
  eclipseCarbon,

  // 5 Temas Claros
  frostedGlacier,
  roseQuartz,
  sageBotanical,
  solarAmber,
  pureClay,
}

/// Definición completa de un tema dinámico dentro del sistema de diseño
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
  final List<Color> liquidGradientColors;
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
    required this.liquidGradientColors,
    required this.textPrimary,
    required this.textSecondary,
    required this.ctaTextColor,
  });

  // ===========================================================================
  // 1. Cálculos Dinámicos de Glassmorfismo
  // ===========================================================================

  /// Superficie translúcida de cristal (65%–75% opacidad)
  Color get glassSurfaceColor => bgSurface.withValues(alpha: isDark ? 0.70 : 0.75);

  /// Borde estructural sutil de 1px
  Color get glassBorderColor => textSecondary.withValues(alpha: isDark ? 0.20 : 0.25);

  /// Desenfoque por defecto de 20px
  double get glassBlur => 20.0;

  // ===========================================================================
  // 2. Cálculos Dinámicos de Neumorfismo 'Soft UI'
  // ===========================================================================

  /// Doble sombra neumórfica para elementos elevados.
  /// En temas claros se emplean desenfoques amplios (16px) y opacidades reducidas
  /// para evitar sombras sucias o agresivas.
  List<BoxShadow> neumorphicRaisedShadows({Color? baseColor}) {
    if (isDark) {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.9),
          offset: const Offset(4, 4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.7),
          offset: const Offset(-3, -3),
          blurRadius: 8,
        ),
      ];
    } else {
      // Calibración para temas claros: 8px 8px 16px sombra suave, -8px -8px 16px luz clara
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.55),
          offset: const Offset(8, 8),
          blurRadius: 16,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.95),
          offset: const Offset(-8, -8),
          blurRadius: 16,
        ),
      ];
    }
  }

  /// Doble sombra neumórfica incrustada (Inset)
  List<BoxShadow> neumorphicInsetShadows() {
    if (isDark) {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.8),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.4),
          offset: const Offset(-2, -2),
          blurRadius: 4,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: shadowDark.withValues(alpha: 0.45),
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: shadowLight.withValues(alpha: 0.9),
          offset: const Offset(-4, -4),
          blurRadius: 8,
        ),
      ];
    }
  }

  // ===========================================================================
  // 3. Gradiente Interactivo Líquido (Liquid UI a 135°)
  // ===========================================================================

  LinearGradient get liquidPrimaryGradient => LinearGradient(
        colors: liquidGradientColors,
        begin: const Alignment(-0.707, -0.707), // 135 grados
        end: const Alignment(0.707, 0.707),
      );

  // ===========================================================================
  // 4. Flutter ThemeData Dinámico (Material 3)
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
        fillColor: bgSurface.withValues(alpha: isDark ? 0.65 : 0.85),
        hintStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.75),
          fontSize: 14,
        ),
        labelStyle: TextStyle(color: textSecondary),
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

/// Catálogo de los 10 temas exactos especificados en el sistema de diseño
class AppThemes {
  AppThemes._();

  // ===========================================================================
  // 5 Temas Oscuros
  // ===========================================================================

  /// 1. Midnight Blue (Tema Base / Oficial)
  static const AppThemeConfig midnightBlue = AppThemeConfig(
    id: ThemeId.midnightBlue,
    name: 'Midnight Blue',
    tag: 'Tema Oficial / Cristal Profundo',
    isDark: true,
    bgCanvas: Color(0xFF101419),
    bgSurface: Color(0xFF1A1F26),
    shadowDark: Color(0xFF0D1014),
    shadowLight: Color(0xFF222932),
    accentPrimary: Color(0xFF7BB6FF),
    accentSecondary: Color(0xFFBD93F9),
    liquidGradientColors: [Color(0xFF7BB6FF), Color(0xFFBD93F9)],
    textPrimary: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B9BB4),
    ctaTextColor: Color(0xFF0D1219),
  );

  /// 2. Cyber Emerald (Esmeralda y Jade tecnológico)
  static const AppThemeConfig cyberEmerald = AppThemeConfig(
    id: ThemeId.cyberEmerald,
    name: 'Cyber Emerald',
    tag: 'Esmeralda / Jade tecnológico',
    isDark: true,
    bgCanvas: Color(0xFF0C1715),
    bgSurface: Color(0xFF142421),
    shadowDark: Color(0xFF060D0B),
    shadowLight: Color(0xFF1E3530),
    accentPrimary: Color(0xFF10B981),
    accentSecondary: Color(0xFF06B6D4),
    liquidGradientColors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFF80A79E),
    ctaTextColor: Color(0xFF041410),
  );

  /// 3. Obsidian Crimson (Garnet / Borgoña sofisticado)
  static const AppThemeConfig obsidianCrimson = AppThemeConfig(
    id: ThemeId.obsidianCrimson,
    name: 'Obsidian Crimson',
    tag: 'Garnet / Borgoña sofisticado',
    isDark: true,
    bgCanvas: Color(0xFF130C0E),
    bgSurface: Color(0xFF1F1317),
    shadowDark: Color(0xFF0A0607),
    shadowLight: Color(0xFF2C1C21),
    accentPrimary: Color(0xFFE11D48),
    accentSecondary: Color(0xFF9F1239),
    liquidGradientColors: [Color(0xFFE11D48), Color(0xFF9F1239)],
    textPrimary: Color(0xFFFDF2F4),
    textSecondary: Color(0xFFA68087),
    ctaTextColor: Colors.white,
  );

  /// 4. Deep Amethyst (Místico / Noche púrpura)
  static const AppThemeConfig deepAmethyst = AppThemeConfig(
    id: ThemeId.deepAmethyst,
    name: 'Deep Amethyst',
    tag: 'Místico / Noche púrpura',
    isDark: true,
    bgCanvas: Color(0xFF100C19),
    bgSurface: Color(0xFF1B152B),
    shadowDark: Color(0xFF09060E),
    shadowLight: Color(0xFF281F3E),
    accentPrimary: Color(0xFFA855F7),
    accentSecondary: Color(0xFFEC4899),
    liquidGradientColors: [Color(0xFFA855F7), Color(0xFFEC4899)],
    textPrimary: Color(0xFFF3EEFA),
    textSecondary: Color(0xFF9B8EA9),
    ctaTextColor: Colors.white,
  );

  /// 5. Eclipse Carbon (Monocromático neutro / Industrial)
  static const AppThemeConfig eclipseCarbon = AppThemeConfig(
    id: ThemeId.eclipseCarbon,
    name: 'Eclipse Carbon',
    tag: 'Monocromático / Industrial',
    isDark: true,
    bgCanvas: Color(0xFF121214),
    bgSurface: Color(0xFF1C1D21),
    shadowDark: Color(0xFF0A0A0B),
    shadowLight: Color(0xFF292A30),
    accentPrimary: Color(0xFFE2E8F0),
    accentSecondary: Color(0xFF94A3B8),
    liquidGradientColors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF64748B),
    ctaTextColor: Color(0xFF121214),
  );

  // ===========================================================================
  // 5 Temas Claros
  // ===========================================================================

  /// 6. Frosted Glacier (Cristal ártico / Limpio)
  static const AppThemeConfig frostedGlacier = AppThemeConfig(
    id: ThemeId.frostedGlacier,
    name: 'Frosted Glacier',
    tag: 'Cristal ártico / Limpio',
    isDark: false,
    bgCanvas: Color(0xFFF0F5FA),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFD2DFEE),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFF0077E6),
    accentSecondary: Color(0xFF00B4D8),
    liquidGradientColors: [Color(0xFF0077E6), Color(0xFF00B4D8)],
    textPrimary: Color(0xFF0F1E2E),
    textSecondary: Color(0xFF5A738E),
    ctaTextColor: Colors.white,
  );

  /// 7. Rose Quartz (Cálido / Elegante)
  static const AppThemeConfig roseQuartz = AppThemeConfig(
    id: ThemeId.roseQuartz,
    name: 'Rose Quartz',
    tag: 'Cálido / Elegante',
    isDark: false,
    bgCanvas: Color(0xFFFAF0F2),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFEED5DB),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFFE63956),
    accentSecondary: Color(0xFFFF758F),
    liquidGradientColors: [Color(0xFFE63956), Color(0xFFFF758F)],
    textPrimary: Color(0xFF2A1216),
    textSecondary: Color(0xFF8C626C),
    ctaTextColor: Colors.white,
  );

  /// 8. Sage Botanical (Natural / Minimalista)
  static const AppThemeConfig sageBotanical = AppThemeConfig(
    id: ThemeId.sageBotanical,
    name: 'Sage Botanical',
    tag: 'Natural / Minimalista',
    isDark: false,
    bgCanvas: Color(0xFFF0F5F2),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFD2E4D9),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFF1B8A5A),
    accentSecondary: Color(0xFF52B788),
    liquidGradientColors: [Color(0xFF1B8A5A), Color(0xFF52B788)],
    textPrimary: Color(0xFF0F261B),
    textSecondary: Color(0xFF597A6A),
    ctaTextColor: Colors.white,
  );

  /// 9. Solar Amber (Energético / Luminoso)
  static const AppThemeConfig solarAmber = AppThemeConfig(
    id: ThemeId.solarAmber,
    name: 'Solar Amber',
    tag: 'Energético / Luminoso',
    isDark: false,
    bgCanvas: Color(0xFFFAF5EE),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFEFE2CE),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFFD97706),
    accentSecondary: Color(0xFFF59E0B),
    liquidGradientColors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    textPrimary: Color(0xFF2B1D09),
    textSecondary: Color(0xFF8A7050),
    ctaTextColor: Colors.white,
  );

  /// 10. Pure Clay (Orgánico / Cerámico contemporáneo)
  static const AppThemeConfig pureClay = AppThemeConfig(
    id: ThemeId.pureClay,
    name: 'Pure Clay',
    tag: 'Orgánico / Cerámico contemporáneo',
    isDark: false,
    bgCanvas: Color(0xFFF5F3F0),
    bgSurface: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFE2DED7),
    shadowLight: Color(0xFFFFFFFF),
    accentPrimary: Color(0xFFD96B43),
    accentSecondary: Color(0xFFE89874),
    liquidGradientColors: [Color(0xFFD96B43), Color(0xFFE89874)],
    textPrimary: Color(0xFF261E1A),
    textSecondary: Color(0xFF806E66),
    ctaTextColor: Colors.white,
  );

  /// Lista con todos los temas disponibles en orden
  static const List<AppThemeConfig> all = [
    midnightBlue,
    cyberEmerald,
    obsidianCrimson,
    deepAmethyst,
    eclipseCarbon,
    frostedGlacier,
    roseQuartz,
    sageBotanical,
    solarAmber,
    pureClay,
  ];

  static const List<AppThemeConfig> darkThemes = [
    midnightBlue,
    cyberEmerald,
    obsidianCrimson,
    deepAmethyst,
    eclipseCarbon,
  ];

  static const List<AppThemeConfig> lightThemes = [
    frostedGlacier,
    roseQuartz,
    sageBotanical,
    solarAmber,
    pureClay,
  ];

  /// Obtiene un tema por su id con fallback seguro al tema por defecto
  static AppThemeConfig fromId(String? idName) {
    if (idName == null) return midnightBlue;
    return all.firstWhere(
      (theme) => theme.id.name == idName,
      orElse: () => midnightBlue,
    );
  }
}
