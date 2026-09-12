import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Superficie de fondo ambiental limpia y de alto rendimiento:
/// - Fondo base Canvas del tema activo
/// - Iluminación ambiental cenital mediante gradiente radial estático (sin BackdropFilter)
/// - Garantiza 60 FPS estables eliminando filtros GPU costosos
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.6),
          radius: 1.2,
          colors: [
            Color.alphaBlend(
              AppTheme.primaryAccent.withValues(alpha: AppTheme.current.isDark ? 0.08 : 0.05),
              AppTheme.darkBackground,
            ),
            AppTheme.darkBackground,
          ],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
