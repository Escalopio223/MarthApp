import 'package:flutter/material.dart';
import 'app_theme_config.dart';
import 'theme_controller.dart';

/// Fachada central del sistema de diseño Claymórfico de MarthApp
class AppTheme {
  AppTheme._();

  /// Tema actualmente activo en la aplicación (por defecto Midnight Slate)
  static AppThemeConfig current = AppThemes.midnightSlate;

  /// Obtiene el tema activo suscribiéndose reactivamente al contexto del árbol
  static AppThemeConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    return scope?.notifier?.currentTheme ?? current;
  }

  // ===========================================================================
  // 1. Tokens de Color Dinámicos
  // ===========================================================================

  /// Fondo principal (Canvas)
  static Color get darkBackground => current.bgCanvas;

  /// Superficie de componentes base
  static Color get surfaceDark => current.bgSurface;

  /// Sombra de elevación oscura
  static Color get shadowDark => current.shadowDark;
  static Color get neumorphicDarkShadow => current.shadowDark;

  /// Realce especular superior claro
  static Color get shadowLight => current.shadowLight;
  static Color get neumorphicLightHighlight => current.shadowLight;

  /// Color de texto óptimo para CTA según contraste WCAG AA
  static Color get ctaTextColor => current.ctaTextColor;

  /// Acento primario
  static Color get primaryAccent => current.accentPrimary;

  /// Alias retrocompatibles
  static Color get primaryLiquid => current.accentPrimary;
  static Color get primaryCyan => current.accentPrimary;
  static Color get primaryIndigo => current.accentPrimary;

  /// Acento secundario
  static Color get secondaryAccent => current.accentSecondary;
  static Color get secondaryLilac => current.accentSecondary;

  /// Texto principal (alto contraste WCAG AA)
  static Color get textPrimary => current.textPrimary;

  /// Texto secundario y bordes estructurales
  static Color get textSecondary => current.textSecondary;
  static Color get structuralBorder => current.textSecondary;

  /// Acentos de estado universales
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentCoral = Color(0xFFFF5E7E);

  // ===========================================================================
  // 2. Gradientes y Superficies Claymórficas
  // ===========================================================================

  /// Gradiente dinámico de acción principal a 135°
  static LinearGradient get actionGradient => current.actionGradient;
  static LinearGradient get liquidPrimaryGradient => current.actionGradient;

  /// Gradiente esmeralda para estados de éxito e invitaciones
  static LinearGradient get liquidEmeraldGradient => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Micro-gradiente cenital para dar volumen a tarjetas y componentes
  static LinearGradient claySurfaceGradient({Color? baseColor}) =>
      current.claySurfaceGradient(baseColor: baseColor);

  /// Doble sombra claymórfica contenida (elevación e iluminación cenital)
  static List<BoxShadow> clayRaisedShadows({
    Color? baseColor,
    bool isPressed = false,
  }) =>
      current.clayRaisedShadows(baseColor: baseColor, isPressed: isPressed);

  /// Sombra incrustada cóncava para campos de texto y hendiduras
  static List<BoxShadow> clayInsetShadows() => current.clayInsetShadows();

  /// Borde estructural sutil de la arcilla
  static Color get cardBorderColor => current.cardBorderColor;
  static Color get glassBorderColor => current.cardBorderColor;
  static Color get glassSurfaceColor => current.bgSurface;
  static double get glassBlur => 0.0;

  static List<BoxShadow> neumorphicRaisedShadows({Color? baseColor}) =>
      current.clayRaisedShadows(baseColor: baseColor);
  static List<BoxShadow> neumorphicInsetShadows() => current.clayInsetShadows();

  // ===========================================================================
  // 3. ThemeData Dinámico de Flutter
  // ===========================================================================

  static ThemeData get themeData => current.themeData;
}

/// Scope de temas para propagar reactivamente los cambios de diseño en el árbol
class AppThemeScope extends InheritedNotifier<ThemeController> {
  final ThemeController controller;
  static ThemeController? _fallbackController;

  const AppThemeScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    return scope?.notifier;
  }

  static ThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller != null) return controller;
    _fallbackController ??= ThemeController();
    return _fallbackController!;
  }
}
