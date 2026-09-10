import 'package:flutter/material.dart';
import 'app_theme_config.dart';
import 'theme_controller.dart';

/// Sistema de diseño dinámico para MarthApp:
/// Actúa como fachada reactiva que expone el tema activo de la aplicación
/// manteniendo compatibilidad estática y soporte para InheritedWidget.
class LiquidTheme {
  LiquidTheme._();

  /// Tema actualmente activo en la aplicación (por defecto Midnight Blue)
  static AppThemeConfig current = AppThemes.midnightBlue;

  /// Obtiene el tema activo suscribiéndose reactivamente al contexto del árbol
  static AppThemeConfig of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LiquidThemeScope>();
    return scope?.notifier?.currentTheme ?? current;
  }

  // ===========================================================================
  // 1. Tokens de Color Dinámicos
  // ===========================================================================

  /// Fondo principal (Canvas)
  static Color get darkBackground => current.bgCanvas;

  /// Superficie de componentes base
  static Color get surfaceDark => current.bgSurface;

  /// Sombra neumórfica oscura
  static Color get neumorphicDarkShadow => current.shadowDark;

  /// Brillo neumórfico claro (luz especular)
  static Color get neumorphicLightHighlight => current.shadowLight;

  /// Acento primario (Líquido)
  static Color get primaryLiquid => current.accentPrimary;

  /// Alias retrocompatibles
  static Color get primaryCyan => current.accentPrimary;
  static Color get primaryIndigo => current.accentPrimary;

  /// Acento secundario
  static Color get secondaryLilac => current.accentSecondary;

  /// Texto principal (alto contraste WCAG AA)
  static Color get textPrimary => current.textPrimary;

  /// Texto secundario y bordes estructurales
  static Color get textSecondary => current.textSecondary;
  static Color get structuralBorder => current.textSecondary;

  /// Acentos de estado universales
  static const Color accentEmerald = Color(0xFF50FA7B);
  static const Color accentCoral = Color(0xFFFF5E7E);

  // ===========================================================================
  // 2. Gradientes Líquidos Dinámicos (135°)
  // ===========================================================================

  /// Gradiente interactivo principal del tema activo a 135°
  static LinearGradient get liquidPrimaryGradient =>
      current.liquidPrimaryGradient;

  /// Gradiente esmeralda para estados de éxito
  static const LinearGradient liquidEmeraldGradient = LinearGradient(
    colors: [Color(0xFF3ECF8E), Color(0xFF50FA7B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente púrpura/lila
  static LinearGradient get liquidPurpleGradient => LinearGradient(
    colors: [const Color(0xFF9D65FF), current.accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===========================================================================
  // 3. Sombras Neumórficas Dinámicas ('Soft UI' sutil)
  // ===========================================================================

  /// Doble sombra neumórfica para elementos elevados (calculada según dark/light)
  static List<BoxShadow> neumorphicRaisedShadows({Color? baseColor}) =>
      current.neumorphicRaisedShadows(baseColor: baseColor);

  /// Doble sombra neumórfica para hendiduras / elementos incrustados (Inset)
  static List<BoxShadow> neumorphicInsetShadows() =>
      current.neumorphicInsetShadows();

  // ===========================================================================
  // 4. Parámetros Glassmorphism Dinámicos
  // ===========================================================================

  /// Fondo translúcido con opacidad entre 65% y 75% sobre la superficie del tema
  static Color get glassSurfaceColor => current.glassSurfaceColor;

  /// Borde estructural sutil de 1px
  static Color get glassBorderColor => current.glassBorderColor;

  /// Desenfoque de fondo de 20px
  static double get glassBlur => current.glassBlur;

  // ===========================================================================
  // 5. ThemeData Dinámico de Flutter
  // ===========================================================================

  static ThemeData get themeData => current.themeData;
}

/// Scope de temas para propagar reactivamente los cambios de diseño en el árbol
class LiquidThemeScope extends InheritedNotifier<ThemeController> {
  final ThemeController controller;
  static ThemeController? _fallbackController;

  const LiquidThemeScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LiquidThemeScope>();
    return scope?.notifier;
  }

  static ThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller != null) return controller;
    _fallbackController ??= ThemeController();
    return _fallbackController!;
  }
}
