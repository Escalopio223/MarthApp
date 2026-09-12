import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BannerType { error, success, info }

/// Banner reutilizable con estilo Liquid UI y Glassmorfismo para alertas y estados:
/// - Fondo translúcido con tinte armónico sobre superficie oscura #1A1F26
/// - Borde sutil y texto de alto contraste #E6EDF3 cumpliendo WCAG AA
class LiquidBanner extends StatelessWidget {
  final String message;
  final BannerType type;
  final IconData? customIcon;
  final VoidCallback? onClose;

  const LiquidBanner({
    super.key,
    required this.message,
    this.type = BannerType.error,
    this.customIcon,
    this.onClose,
  });

  Color get _accentColor {
    switch (type) {
      case BannerType.error:
        return AppTheme.accentCoral;
      case BannerType.success:
        return AppTheme.accentEmerald;
      case BannerType.info:
        return AppTheme.primaryLiquid;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case BannerType.error:
        return Icons.error_outline_rounded;
      case BannerType.success:
        return Icons.check_circle_outline_rounded;
      case BannerType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(customIcon ?? _defaultIcon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.textPrimary, // #E6EDF3 para máximo contraste WCAG AA
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded,
                  color: AppTheme.textSecondary, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}
