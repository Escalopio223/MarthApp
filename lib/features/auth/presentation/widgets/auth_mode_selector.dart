import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

enum AuthMode { login, register }

/// Selector segmentado de modo de autenticación:
/// - Base Neumórfica 'Soft UI' sobre #1A1F26 con sombras suaves
/// - Pestaña activa con gradiente interactivo Liquid UI #7BB6FF -> #BD93F9
/// - Curvas de aceleración elásticas Curves.easeOutCubic
/// - Alto contraste WCAG AA
class AuthModeSelector extends StatelessWidget {
  final AuthMode currentMode;
  final ValueChanged<AuthMode> onModeChanged;

  const AuthModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark, // #1A1F26
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.glassBorderColor,
          width: 0.8,
        ),
        boxShadow: [
          // Sombra oscura inferior
          BoxShadow(
            color: AppTheme.neumorphicDarkShadow.withValues(alpha: 0.8),
            offset: const Offset(2, 2),
            blurRadius: 6,
          ),
          // Realce claro superior
          BoxShadow(
            color: AppTheme.neumorphicLightHighlight.withValues(alpha: 0.5),
            offset: const Offset(-2, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildOption(
              mode: AuthMode.login,
              label: 'Iniciar Sesión',
              isSelected: currentMode == AuthMode.login,
            ),
          ),
          Expanded(
            child: _buildOption(
              mode: AuthMode.register,
              label: 'Crear Cuenta',
              isSelected: currentMode == AuthMode.register,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required AuthMode mode,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.liquidPrimaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF0D1219) // WCAG AA sobre gradiente cian-lila
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
