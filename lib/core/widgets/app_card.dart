import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Tarjeta táctil Claymórfica ergonómica de alto rendimiento (Puffy Clay Card):
/// - Superficie con micro-gradiente volumétrico 3D (iluminación cenital adaptada)
/// - Doble sombra volumétrica (elevación + luz superior) con compresión al tacto
/// - Respuesta háptica instantánea y compresión elástica a 120ms
/// - Cero BackdropFilter: máximo rendimiento de rasterizado (60/120 FPS estables)
class AppCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? surfaceColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(20.0),
    this.margin,
    this.surfaceColor,
    this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
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
    final effectiveSurface = widget.surfaceColor ?? AppTheme.surfaceDark;

    final cardWidget = AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutQuad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: effectiveSurface,
          gradient: AppTheme.claySurfaceGradient(baseColor: effectiveSurface),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: AppTheme.cardBorderColor,
            width: 1.0,
          ),
          boxShadow: AppTheme.clayRaisedShadows(
            baseColor: effectiveSurface,
            isPressed: _isPressed,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
