import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tarjeta táctil Claymórfica ergonómica de alto rendimiento:
/// - Superficie con micro-gradiente volumétrico 3D (iluminación cenital)
/// - Doble sombra contenida (elevación + luz superior sin solapamientos)
/// - Cero BackdropFilter: máximo rendimiento de rasterizado (60 FPS estables)
/// - Radios de curvatura moderados (18px por defecto)
class AppCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? surfaceColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.padding = const EdgeInsets.all(20.0),
    this.margin,
    this.surfaceColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSurface = surfaceColor ?? AppTheme.surfaceDark;

    final cardWidget = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveSurface,
        gradient: AppTheme.claySurfaceGradient(baseColor: effectiveSurface),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.cardBorderColor,
          width: 1.0,
        ),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: effectiveSurface),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
