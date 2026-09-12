import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/friend_request_model.dart';

/// Tarjeta que muestra la bandeja de solicitudes de amistad entrantes
class IncomingRequestsCard extends StatelessWidget {
  final List<FriendRequestModel> requests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  const IncomingRequestsCard({
    super.key,
    required this.requests,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 18.0,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentCoral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.mark_email_unread_rounded,
                  color: AppTheme.accentCoral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Solicitudes Recibidas (${requests.length})',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              final senderName = req.senderProfile?.username ?? 'Usuario';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.glassBorderColor,
                  ),
                ),
                child: Row(
                  children: [
                    if (req.senderProfile != null)
                      UserAvatar.fromProfile(
                        profile: req.senderProfile!,
                        size: 38,
                        showGlow: false,
                        showBorder: true,
                      )
                    else
                      UserAvatar(
                        avatarData: const AvatarData.initials(),
                        username: senderName,
                        size: 38,
                        showGlow: false,
                        showBorder: true,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Quiere ser tu amigo',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.accentEmerald.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppTheme.accentEmerald,
                          size: 18,
                        ),
                      ),
                      tooltip: 'Aceptar',
                      onPressed: () => onAccept(req.id),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCoral.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppTheme.accentCoral,
                          size: 18,
                        ),
                      ),
                      tooltip: 'Rechazar',
                      onPressed: () => onReject(req.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
