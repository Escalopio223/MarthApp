import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';

/// Componente presentacional puro para la visualización del espacio personal protegido ("Mi Espacio")
class PersonalEnvironmentView extends StatelessWidget {
  const PersonalEnvironmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LiquidTheme.primaryCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LiquidTheme.primaryCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LiquidTheme.primaryCyan.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.lock_rounded,
              color: LiquidTheme.primaryCyan,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Espacio Personal Protegido',
            style: TextStyle(
              color: LiquidTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este es tu entorno base personal creado por defecto. Es 100% privado e intransferible: no se pueden agregar miembros ni puede ser eliminado.\n\nTodo el contenido creado aquí solo es visible por ti.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: LiquidTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LiquidTheme.glassBorderColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 16,
                  color: LiquidTheme.primaryCyan,
                ),
                const SizedBox(width: 8),
                Text(
                  'Acceso exclusivo para tu usuario',
                  style: TextStyle(
                    color: LiquidTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
