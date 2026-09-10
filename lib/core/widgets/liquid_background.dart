import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/liquid_theme.dart';

/// Fondo ambiental dinámico estilo 'Liquid UI':
/// - Canvas principal #101419 (negro azulado profundo)
/// - Esferas orgánicas fluidas difuminadas en tonos #7BB6FF (azul cian) y #BD93F9 (lila suave)
/// - Capa de fusión con desenfoque de alto radio
class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 1. Canvas base: #101419 (negro azulado profundo)
        Container(
          width: double.infinity,
          height: double.infinity,
          color: LiquidTheme.darkBackground,
        ),

        // 2. Esfera líquida superior-izquierda (Acento primario: #7BB6FF)
        Positioned(
          top: -size.width * 0.25,
          left: -size.width * 0.2,
          child: Container(
            width: size.width * 0.75,
            height: size.width * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidTheme.primaryLiquid.withValues(alpha: 0.28),
                  LiquidTheme.primaryLiquid.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 3. Esfera líquida inferior-derecha (Acento secundario: #BD93F9)
        Positioned(
          bottom: -size.width * 0.28,
          right: -size.width * 0.22,
          child: Container(
            width: size.width * 0.85,
            height: size.width * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidTheme.secondaryLilac.withValues(alpha: 0.24),
                  LiquidTheme.secondaryLilac.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 4. Esfera ambiental intermedia para profundidad visual
        Positioned(
          top: size.height * 0.45,
          left: size.width * 0.4,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidTheme.primaryLiquid.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 5. Capa difusora de alta dispersión para una estética suave
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: const SizedBox.expand(),
        ),

        // 6. Contenido interactivo seguro
        SafeArea(child: child),
      ],
    );
  }
}
