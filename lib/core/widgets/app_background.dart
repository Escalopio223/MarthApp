import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Superficie de fondo ambiental limpia y de alto rendimiento:
/// - Fondo base Canvas del tema activo
/// - Iluminación ambiental cenital mediante gradiente radial estático (sin BackdropFilter)
/// - Garantiza 60 FPS estables eliminando filtros GPU costosos
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool useSafeArea;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool safeAreaLeft;
  final bool safeAreaRight;

  const AppBackground({
    super.key,
    required this.child,
    this.useSafeArea = true,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = useSafeArea
        ? SafeArea(
            top: safeAreaTop,
            bottom: safeAreaBottom,
            left: safeAreaLeft,
            right: safeAreaRight,
            child: child,
          )
        : child;

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
      child: content,
    );
  }
}
