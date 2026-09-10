import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// Tarjeta de perfil del usuario en la pantalla de Ajustes
class UserProfileCard extends StatelessWidget {
  final String email;

  const UserProfileCard({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 16.0,
      borderRadius: 22.0,
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LiquidTheme.liquidPrimaryGradient,
              boxShadow: [
                BoxShadow(
                  color: LiquidTheme.primaryCyan.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF0D1219),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta Activa',
                  style: TextStyle(
                    color: LiquidTheme.primaryCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: LiquidTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
