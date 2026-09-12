import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/models/environment_invitation_model.dart';

/// Tarjeta para renderizar una invitación entrante a un entorno de trabajo
class EnvironmentInvitationTile extends StatelessWidget {
  final EnvironmentInvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool isLoading;

  const EnvironmentInvitationTile({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accentEmerald.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.liquidEmeraldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.environmentName,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invitación de @${invitation.senderUsername}',
                      style: TextStyle(
                        color: AppTheme.accentEmerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentCoral,
                    side: BorderSide(
                      color: AppTheme.accentCoral.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: isLoading ? null : onDecline,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: 'Aceptar',
                  isLoading: isLoading,
                  icon: Icons.check_rounded,
                  gradient: AppTheme.liquidEmeraldGradient,
                  onPressed: isLoading ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
