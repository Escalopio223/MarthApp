import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/neumorphic_container.dart';

/// Tarjeta neumórfica con información técnica de estado de conexión
class BackendStatusCard extends StatelessWidget {
  final String userEmail;

  const BackendStatusCard({
    super.key,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      borderRadius: 22,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_rounded,
                  color: LiquidTheme.accentEmerald, size: 22),
              const SizedBox(width: 10),
              Text(
                'Backend Supabase Conectado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: LiquidTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Proyecto: cntspvnxrmqchvtcdiwv\n'
            'SDK: supabase_flutter v2.17.2\n'
            'Usuario: $userEmail',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: LiquidTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
