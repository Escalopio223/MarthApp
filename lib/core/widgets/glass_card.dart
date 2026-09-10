import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/liquid_theme.dart';

/// Contenedor Glassmórfico flotante de alta fidelidad:
/// - Fondo translúcido #1A1F26 con opacidad entre 65% y 75%
/// - Desenfoque de fondo de 20px (ImageFilter.blur)
/// - Borde estructural sutil de 1px con efecto de luz especular superior/izquierdo
/// - Esquinas orgánicas amplias (18px - 24px)
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? surfaceColor;
  final Gradient? borderGradient;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.blur = 20.0,
    this.padding = const EdgeInsets.all(24.0),
    this.margin,
    this.surfaceColor,
    this.borderGradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSurface = surfaceColor ?? LiquidTheme.glassSurfaceColor;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveSurface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: LiquidTheme.glassBorderColor, // 1px solid rgba(139, 155, 180, 0.2)
                width: 1.0,
              ),
              boxShadow: [
                // Realce especular superior/izquierdo
                BoxShadow(
                  color: LiquidTheme.neumorphicLightHighlight.withValues(alpha: 0.45),
                  offset: const Offset(-1, -1),
                  blurRadius: 2,
                ),
                // Sombra profunda inferior/derecha
                BoxShadow(
                  color: LiquidTheme.neumorphicDarkShadow.withValues(alpha: 0.75),
                  offset: const Offset(0, 12),
                  blurRadius: 24,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
