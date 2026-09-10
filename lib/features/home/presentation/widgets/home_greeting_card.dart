import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// Tarjeta principal de bienvenida con estética Glassmorphism
class HomeGreetingCard extends StatelessWidget {
  final String username;

  const HomeGreetingCard({
    super.key,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 24.0,
      borderRadius: 28.0,
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: LiquidTheme.primaryCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: LiquidTheme.primaryCyan.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded,
                    color: LiquidTheme.primaryCyan, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Sesión Activa con Supabase',
                  style: TextStyle(
                    color: LiquidTheme.primaryCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '¡Hola, $username!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: LiquidTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenido a tu panel principal en MarthApp. Tu aplicación conectada a Supabase con estilo Liquid UI.',
            style: TextStyle(
              color: LiquidTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
