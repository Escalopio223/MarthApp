import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../friends/domain/models/profile_model.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';

/// Estado visual modelado explícitamente para cada amigo en el modal de invitación
enum FriendInvitationStatus {
  alreadyMember,
  pending,
  notInvited,
}

/// Componente presentacional puro para renderizar la fila de un amigo y su acción de invitación
class FriendInviteTile extends StatelessWidget {
  final ProfileModel friend;
  final FriendInvitationStatus status;
  final bool isLoading;
  final VoidCallback onInvite;

  const FriendInviteTile({
    super.key,
    required this.friend,
    required this.status,
    this.isLoading = false,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.glassBorderColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          UserAvatar.fromProfile(
            profile: friend,
            size: 38,
            showBorder: true,
            showGlow: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status == FriendInvitationStatus.alreadyMember
                      ? 'Ya participa en el entorno'
                      : (status == FriendInvitationStatus.pending
                          ? 'Esperando respuesta del amigo'
                          : 'Disponible para invitar'),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildAction(),
        ],
      ),
    );
  }

  Widget _buildAction() {
    if (isLoading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(4.0),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF00E5FF),
          ),
        ),
      );
    }

    switch (status) {
      case FriendInvitationStatus.alreadyMember:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentEmerald.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.accentEmerald.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 14, color: AppTheme.accentEmerald),
              const SizedBox(width: 4),
              Text(
                'Miembro',
                style: TextStyle(
                  color: AppTheme.accentEmerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case FriendInvitationStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  size: 14, color: Colors.amber.shade300),
              const SizedBox(width: 4),
              Text(
                'Pendiente',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case FriendInvitationStatus.notInvited:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onInvite,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppTheme.liquidPrimaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  const Text(
                    'Invitar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
