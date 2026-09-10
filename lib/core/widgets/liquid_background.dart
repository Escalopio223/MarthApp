import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/liquid_theme.dart';

/// Fondo dinámico estilo Liquid UI con esferas orgánicas difuminadas
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
        // Base oscura
        Container(
          width: double.infinity,
          height: double.infinity,
          color: LiquidTheme.darkBackground,
        ),

        // Esfera Líquida 1 (Cian / Azul superior izquierda)
        Positioned(
          top: -size.width * 0.2,
          left: -size.width * 0.15,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidTheme.primaryCyan.withValues(alpha: 0.35),
                  LiquidTheme.primaryIndigo.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Esfera Líquida 2 (Púrpura / Rosa inferior derecha)
        Positioned(
          bottom: -size.width * 0.25,
          right: -size.width * 0.2,
          child: Container(
            width: size.width * 0.8,
            height: size.width * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8A2387).withValues(alpha: 0.3),
                  const Color(0xFFE94057).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Esfera Líquida 3 (Esmeralda central)
        Positioned(
          top: size.height * 0.45,
          left: size.width * 0.5,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LiquidTheme.accentEmerald.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Capa de desenfoque general para fusionar los líquidos
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: const SizedBox.expand(),
        ),

        // Contenido principal
        SafeArea(child: child),
      ],
    );
  }
}
