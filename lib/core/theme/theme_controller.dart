import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_config.dart';
import 'app_theme.dart';

/// Controlador reactivo del sistema de diseño para alternar temas dinámicamente
/// y persistir la selección en el almacenamiento local.
class ThemeController extends ChangeNotifier {
  static const String _storageKey = 'marthapp_theme_id';

  AppThemeConfig _currentTheme;
  SharedPreferences? _prefs;

  ThemeController({
    AppThemeConfig? initialTheme,
    SharedPreferences? prefs,
  }) : _currentTheme = initialTheme ?? AppThemes.midnightSlate {
    _prefs = prefs;
    // Sincronizar facade estático
    AppTheme.current = _currentTheme;
    _initStorage();
  }

  AppThemeConfig get currentTheme => _currentTheme;
  ThemeId get currentThemeId => _currentTheme.id;
  bool get isDark => _currentTheme.isDark;

  Future<void> _initStorage() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedId = _prefs?.getString(_storageKey);
      if (savedId != null && savedId != _currentTheme.id.name) {
        _currentTheme = AppThemes.fromId(savedId);
        AppTheme.current = _currentTheme;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ThemeController] No se pudo leer el almacenamiento: $e');
    }
  }

  /// Cambia el tema activo, actualiza la fachada global y persiste en SharedPreferences
  Future<void> setTheme(AppThemeConfig newTheme) async {
    if (_currentTheme.id == newTheme.id) return;

    _currentTheme = newTheme;
    AppTheme.current = newTheme;
    notifyListeners();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_storageKey, newTheme.id.name);
    } catch (e) {
      debugPrint('[ThemeController] Error al guardar preferencia de tema: $e');
    }
  }

  /// Cambia de tema mediante su identificador
  Future<void> setThemeById(ThemeId id) async {
    final theme = AppThemes.all.firstWhere(
      (t) => t.id == id,
      orElse: () => AppThemes.midnightSlate,
    );
    await setTheme(theme);
  }
}
