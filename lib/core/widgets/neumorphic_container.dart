import 'package:flutter/material.dart';
import '../theme/liquid_theme.dart';

/// Contenedor táctil Neumórfico ('Soft UI'):
/// - Superficie base #1A1F26
/// - Doble sombra suave con exterior oscura (#0D1014) y realce claro (#222932)
/// - Borde ultra sutil integrado y transición elástica cubic-bezier
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isInset;
  final Color baseColor;
  final VoidCallback? onTap;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.padding = const EdgeInsets.all(16.0),
    this.isInset = false,
    this.baseColor = LiquidTheme.surfaceDark, // #1A1F26
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isInset
            ? LiquidTheme.neumorphicInsetShadows()
            : LiquidTheme.neumorphicRaisedShadows(baseColor: baseColor),
        border: Border.all(
          color: LiquidTheme.glassBorderColor,
          width: 0.8,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}
