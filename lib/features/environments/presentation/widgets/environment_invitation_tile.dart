import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/environment_invitation_model.dart';
import 'environment_invitation_details_modal.dart';

/// Tarjeta para renderizar una invitación entrante a un entorno de trabajo
/// Muestra nombre y foto del anfitrión, entorno y los demás integrantes con sus fotos y nombres
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
    final otherMembers = invitation.otherMembers;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => EnvironmentInvitationDetailsModal.show(
          context,
          invitation: invitation,
          onAccept: onAccept,
          onDecline: onDecline,
          isLoading: isLoading,
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.accentEmerald.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera: Foto del anfitrión, Nombre del entorno y subtítulo con nombre
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UserAvatar(
                    avatarData: invitation.senderAvatarData,
                    username: invitation.senderUsername,
                    size: 46,
                    showBorder: true,
                    showGlow: true,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                invitation.environmentName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppTheme.textSecondary.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              'Invitación de @${invitation.senderUsername}',
                              style: TextStyle(
                                color: AppTheme.accentEmerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Anfitrión',
                                style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Sección: Otros integrantes con fotos y nombres (si existen)
              if (otherMembers.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.glassBorderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 13,
                            color: AppTheme.accentEmerald,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Otros integrantes (${otherMembers.length}):',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...otherMembers.take(4).map(
                                (m) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceDark
                                        .withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.glassBorderColor
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UserAvatar(
                                        avatarData: m.avatarData,
                                        username: m.username,
                                        size: 20,
                                        showBorder: false,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        m.username,
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (m.isOwner) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber,
                                          size: 12,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          if (otherMembers.length > 4)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentEmerald
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+${otherMembers.length - 4} más',
                                style: TextStyle(
                                  color: AppTheme.accentEmerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_add_rounded,
                        size: 13,
                        color: AppTheme.accentEmerald.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Serás el primer nuevo integrante en unirte',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botones de acción: Rechazar y Aceptar
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
        ),
      ),
    );
  }
}

