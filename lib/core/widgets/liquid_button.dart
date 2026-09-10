import 'package:flutter/material.dart';
import '../theme/liquid_theme.dart';

/// Botón de acción principal (CTA) con degradado interactivo Liquid UI:
/// - Gradiente #7BB6FF -> #BD93F9 a 135°
/// - Resplandor líquido reactivo
/// - Transiciones suaves con curvas elásticas Curves.easeOutCubic
/// - Alto contraste WCAG AA para máxima legibilidad
class LiquidButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Gradient? gradient;
  final double height;
  final double borderRadius;
  final Color? textColor;

  const LiquidButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient,
    this.height = 54.0,
    this.borderRadius = 18.0,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final effectiveGradient = gradient ?? LiquidTheme.liquidPrimaryGradient;

    // Asegurar ratio de contraste WCAG AA sobre el degradado
    final effectiveTextColor = textColor ??
        (gradient == null || gradient == LiquidTheme.liquidPrimaryGradient
            ? LiquidTheme.current.ctaTextColor
            : LiquidTheme.textPrimary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        gradient: !isEnabled
            ? LinearGradient(
                colors: [
                  LiquidTheme.surfaceDark,
                  LiquidTheme.surfaceDark.withValues(alpha: 0.7),
                ],
              )
            : effectiveGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: !isEnabled
            ? []
            : [
                BoxShadow(
                  color: LiquidTheme.primaryLiquid.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: isEnabled ? onPressed : null,
          splashColor: Colors.black.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.15),
          child: Center(
            child: isLoading
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
                        if (icon != null) ...[
                          Icon(icon, color: effectiveTextColor, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            text,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: effectiveTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
