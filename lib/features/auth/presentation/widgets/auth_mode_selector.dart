import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';

enum AuthMode { login, register }

/// Selector segmentado de modo de autenticación estilo Liquid UI
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LiquidTheme.liquidPrimaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: LiquidTheme.primaryCyan.withValues(alpha: 0.3),
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
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : LiquidTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
