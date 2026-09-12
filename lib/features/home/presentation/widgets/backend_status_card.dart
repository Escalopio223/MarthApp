import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// Tarjeta con información técnica de estado de conexión
class BackendStatusCard extends StatelessWidget {
  final String userEmail;

  const BackendStatusCard({
    super.key,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_rounded,
                  color: AppTheme.accentEmerald, size: 22),
              const SizedBox(width: 10),
              Text(
                'Backend Supabase Conectado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
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
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
