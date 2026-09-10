import 'package:flutter/material.dart';
import '../theme/liquid_theme.dart';

enum BannerType { error, success, info }

/// Banner reutilizable con estilo Liquid UI y Glassmorfismo para alertas y estados
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

  Color get _baseColor {
    switch (type) {
      case BannerType.error:
        return LiquidTheme.accentCoral;
      case BannerType.success:
        return LiquidTheme.accentEmerald;
      case BannerType.info:
        return LiquidTheme.primaryCyan;
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
    final color = _baseColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(customIcon ?? _defaultIcon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded, color: color, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}
