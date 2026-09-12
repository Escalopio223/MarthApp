import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/environment_member_model.dart';

/// Componente presentacional puro para la lista de miembros de un entorno colaborativo
class EnvironmentMembersList extends StatelessWidget {
  final List<EnvironmentMemberModel> members;
  final bool isLoading;
  final bool isOwner;
  final bool canInviteFriends;
  final VoidCallback? onInviteFriends;
  final ValueChanged<EnvironmentMemberModel>? onRemoveMember;

  const EnvironmentMembersList({
    super.key,
    required this.members,
    this.isLoading = false,
    required this.isOwner,
    this.canInviteFriends = false,
    this.onInviteFriends,
    this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera: Título con contador y botón opcional de invitar amigo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Miembros (${members.length})',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (canInviteFriends && onInviteFriends != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onInviteFriends,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.liquidPrimaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text(
                          'Invitar Amigo',
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
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Cuerpo: Carga, Lista vacía o Listado de miembros
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E5FF),
              ),
            ),
          )
        else if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No se encontraron miembros',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final member = members[index];
                final isMemberOwner = member.role == 'owner';

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          AppTheme.glassBorderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarData: member.avatarData,
                        username: member.username,
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
                              member.username,
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
                              isMemberOwner ? 'Propietario' : 'Miembro',
                              style: TextStyle(
                                color: isMemberOwner
                                    ? AppTheme.secondaryLilac
                                    : AppTheme.accentEmerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner && !isMemberOwner && onRemoveMember != null)
                        IconButton(
                          icon: Icon(
                            Icons.person_remove_rounded,
                            size: 18,
                            color: AppTheme.accentCoral
                                .withValues(alpha: 0.8),
                          ),
                          tooltip: 'Expulsar del entorno',
                          onPressed: () => onRemoveMember!(member),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
