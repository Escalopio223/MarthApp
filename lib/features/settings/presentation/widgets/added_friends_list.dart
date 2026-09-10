import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';

/// Componente para mostrar la lista de amigos añadidos como chips elegantes
class AddedFriendsList extends StatelessWidget {
  final List<String> friends;

  const AddedFriendsList({
    super.key,
    required this.friends,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Divider(color: LiquidTheme.glassBorderColor),
        const SizedBox(height: 12),
        Text(
          'Amigos Añadidos:',
          style: TextStyle(
            color: LiquidTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: friends.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LiquidTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LiquidTheme.primaryLiquid.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person,
                      size: 14, color: LiquidTheme.primaryLiquid),
                  const SizedBox(width: 6),
                  Text(
                    f,
                    style: TextStyle(
                      color: LiquidTheme.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
