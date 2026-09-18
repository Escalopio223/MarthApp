import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Contenedor táctil Claymórfico de alto rendimiento (Puffy Clay Container):
/// - Modelado volumétrico 3D adaptado dinámicamente al tema activo
/// - Respuesta física de compresión elástica (~120ms, escala 0.96) al presionar
/// - Vibración háptica instantánea en cada interacción
/// - Soporte para elevación convexa o incrustación cóncava (isInset)
class AppContainer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isInset;
  final Color? baseColor;
  final VoidCallback? onTap;
  final bool isPuffy;
  final BoxBorder? border;

  const AppContainer({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.padding = const EdgeInsets.all(14.0),
    this.isInset = false,
    this.baseColor,
    this.onTap,
    this.isPuffy = true,
    this.border,
  });

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (widget.onTap == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBaseColor = widget.baseColor ?? AppTheme.surfaceDark;
    final effectiveContainerColor = widget.isInset
        ? (AppTheme.isDark
            ? Color.alphaBlend(
                Colors.black.withValues(alpha: 0.25), effectiveBaseColor)
            : Color.alphaBlend(
                AppTheme.shadowDark.withValues(alpha: 0.15), effectiveBaseColor))
        : effectiveBaseColor;

    final gradient = widget.isInset
        ? null
        : AppTheme.claySurfaceGradient(baseColor: effectiveBaseColor);

    final shadows = widget.isInset
        ? AppTheme.clayInsetShadows()
        : AppTheme.clayRaisedShadows(
            baseColor: effectiveBaseColor,
            isPressed: _isPressed,
          );

    final border = widget.border ??
        Border.all(
          color: AppTheme.cardBorderColor,
          width: 0.9,
        );

    final containerWidget = AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutQuad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: effectiveContainerColor,
          gradient: gradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: shadows,
          border: border,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: containerWidget,
      );
    }

    return containerWidget;
  }
}
