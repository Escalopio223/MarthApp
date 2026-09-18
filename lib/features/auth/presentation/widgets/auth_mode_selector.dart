import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

enum AuthMode { login, register }

/// Selector segmentado de modo de autenticación:
/// - Bandeja excavada Claymórfica cóncava (clayInsetShadows)
/// - Pestaña activa 'puffy' convexa con feedback háptico táctil
/// - Curvas de aceleración suaves Curves.easeOutQuad (~120ms)
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
    final baseColor = AppTheme.surfaceDark;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.clayInsetShadows(),
        border: Border.all(
          color: AppTheme.isDark
              ? Colors.black.withValues(alpha: 0.25)
              : AppTheme.shadowDark.withValues(alpha: 0.12),
          width: 1.0,
        ),
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
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onModeChanged(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutQuad,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.liquidPrimaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(
                  color: Colors.white.withValues(
                    alpha: AppTheme.isDark ? 0.25 : 0.40,
                  ),
                  width: 1.0,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: AppTheme.isDark ? 0.25 : 0.40,
                    ),
                    offset: const Offset(-1.5, -1.5),
                    blurRadius: 3,
                  ),
                  BoxShadow(
                    color: AppTheme.shadowDark.withValues(alpha: 0.32),
                    blurRadius: 7,
                    offset: const Offset(2, 3),
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
                  ? AppTheme.current.ctaTextColor
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

