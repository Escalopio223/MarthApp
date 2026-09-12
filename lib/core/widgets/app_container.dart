import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Contenedor táctil Claymórfico para micro-componentes, badges y selectores:
/// - Soporte para elevación convexa o incrustación cóncava (isInset)
/// - Doble sombra contenida y micro-borde estructural
/// - Animación elástica suave
class AppContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isInset;
  final Color? baseColor;
  final VoidCallback? onTap;

  const AppContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(14.0),
    this.isInset = false,
    this.baseColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBaseColor = baseColor ?? AppTheme.surfaceDark;
    final effectiveContainerColor = isInset
        ? (AppTheme.isDark
            ? Color.alphaBlend(
                Colors.black.withValues(alpha: 0.20), effectiveBaseColor)
            : Color.alphaBlend(
                AppTheme.shadowDark.withValues(alpha: 0.15), effectiveBaseColor))
        : effectiveBaseColor;

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveContainerColor,
        gradient: isInset
            ? null
            : AppTheme.claySurfaceGradient(baseColor: effectiveBaseColor),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isInset
            ? AppTheme.clayInsetShadows()
            : AppTheme.clayRaisedShadows(baseColor: effectiveBaseColor),
        border: Border.all(
          color: AppTheme.cardBorderColor,
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
