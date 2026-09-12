import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botón de acción táctil Claymórfico (3D Soft Button):
/// - Animación elástica de compresión física al presionar
/// - Aislado con RepaintBoundary para no invalidar el árbol de renderizado superior
/// - Doble sombra dinámica (elevada en reposo, comprimida al pulsar)
/// - Contraste garantizado WCAG AA >= 4.5:1
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Gradient? gradient;
  final double height;
  final double borderRadius;
  final Color? textColor;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient,
    this.height = 52.0,
    this.borderRadius = 22.0,
    this.textColor,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final effectiveGradient = widget.gradient ?? AppTheme.actionGradient;

    final effectiveTextColor = widget.textColor ??
        (widget.gradient == null || widget.gradient == AppTheme.actionGradient
            ? AppTheme.current.ctaTextColor
            : AppTheme.textPrimary);

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: widget.height,
          transform: Matrix4.translationValues(
            0,
            _isPressed ? 2.0 : 0,
            0,
          ),
          decoration: BoxDecoration(
            gradient: !isEnabled
                ? LinearGradient(
                    colors: [
                      AppTheme.surfaceDark,
                      AppTheme.surfaceDark.withValues(alpha: 0.7),
                    ],
                  )
                : effectiveGradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: isEnabled
                  ? Colors.white.withValues(alpha: _isPressed ? 0.12 : 0.22)
                  : Colors.transparent,
              width: 1.0,
            ),
            boxShadow: !isEnabled
                ? []
                : (_isPressed
                    ? [
                        BoxShadow(
                          color: AppTheme.shadowDark.withValues(alpha: 0.25),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppTheme.shadowDark.withValues(alpha: 0.38),
                          offset: const Offset(0, 5),
                          blurRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.28),
                          offset: const Offset(0, -1),
                          blurRadius: 2,
                        ),
                      ]),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              onTap: isEnabled ? widget.onPressed : null,
              splashColor: Colors.black.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.12),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            effectiveTextColor,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon,
                                  color: effectiveTextColor, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                widget.text,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: effectiveTextColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
