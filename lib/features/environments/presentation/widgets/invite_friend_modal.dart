import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../friends/domain/models/profile_model.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/environment_model.dart';
import '../controllers/environment_controller.dart';

/// Estado visual modelado explícitamente para cada amigo en el modal
enum FriendInvitationStatus {
  alreadyMember,
  pending,
  notInvited,
}

/// Modal interactivo con diseño Liquid Theme para invitar amigos a un entorno colaborativo
class InviteFriendModal extends StatefulWidget {
  final EnvironmentModel environment;
  final EnvironmentController environmentController;
  final FriendsController friendsController;
  final List<String> memberUserIds;

  const InviteFriendModal({
    super.key,
    required this.environment,
    required this.environmentController,
    required this.friendsController,
    required this.memberUserIds,
  });

  static Future<void> show(
    BuildContext context, {
    required EnvironmentModel environment,
    required EnvironmentController environmentController,
    required FriendsController friendsController,
    required List<String> memberUserIds,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteFriendModal(
        environment: environment,
        environmentController: environmentController,
        friendsController: friendsController,
        memberUserIds: memberUserIds,
      ),
    );
  }

  @override
  State<InviteFriendModal> createState() => _InviteFriendModalState();
}

class _InviteFriendModalState extends State<InviteFriendModal> {
  final Set<String> _pendingInvitedUserIds = {};
  bool _isLoadingPending = true;
  String? _invitingFriendId;
  String? _localError;
  String? _localSuccess;

  @override
  void initState() {
    super.initState();
    _loadPendingInvitations();
  }

  Future<void> _loadPendingInvitations() async {
    try {
      final ids = await widget.environmentController
          .getPendingInvitedUserIds(widget.environment.id);
      if (mounted) {
        setState(() {
          _pendingInvitedUserIds.addAll(ids);
          _isLoadingPending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPending = false;
        });
      }
    }
  }

  Future<void> _handleInvite(ProfileModel friend) async {
    setState(() {
      _invitingFriendId = friend.id;
      _localError = null;
      _localSuccess = null;
    });

    final success = await widget.environmentController.inviteFriend(
      environmentId: widget.environment.id,
      friendId: friend.id,
    );

    if (mounted) {
      setState(() {
        _invitingFriendId = null;
        if (success) {
          _pendingInvitedUserIds.add(friend.id);
          _localSuccess = 'Invitación enviada a ${friend.username}';
        } else {
          _localError = widget.environmentController.errorMessage ??
              'Error al enviar la invitación';
        }
      });
    }
  }

  FriendInvitationStatus _getStatusForFriend(String friendId) {
    if (widget.memberUserIds.contains(friendId)) {
      return FriendInvitationStatus.alreadyMember;
    }
    if (_pendingInvitedUserIds.contains(friendId)) {
      return FriendInvitationStatus.pending;
    }
    return FriendInvitationStatus.notInvited;
  }

  @override
  Widget build(BuildContext context) {
    final friends = widget.friendsController.friends;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: LiquidTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: LiquidTheme.glassBorderColor.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: LiquidTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LiquidTheme.accentEmerald.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: LiquidTheme.accentEmerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitar a "${widget.environment.name}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selecciona un amigo para colaborar en este espacio',
                      style: TextStyle(
                        color: LiquidTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: LiquidTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Feedback banners
          if (_localError != null) ...[
            LiquidBanner(
              message: _localError!,
              type: BannerType.error,
              onClose: () => setState(() => _localError = null),
            ),
            const SizedBox(height: 10),
          ],
          if (_localSuccess != null) ...[
            LiquidBanner(
              message: _localSuccess!,
              type: BannerType.success,
              onClose: () => setState(() => _localSuccess = null),
            ),
            const SizedBox(height: 10),
          ],

          const Divider(color: Color(0x1FFFFFFF), height: 16),

          // Body: Friends list or empty state
          if (_isLoadingPending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E5FF),
                ),
              ),
            )
          else if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 48,
                    color: LiquidTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tienes amigos confirmados',
                    style: TextStyle(
                      color: LiquidTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Agrega amigos desde la sección Amigos con su código para poder invitarlos a tus entornos de trabajo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LiquidTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: friends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  final status = _getStatusForFriend(friend.id);
                  final isInvitingThis = _invitingFriendId == friend.id;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: LiquidTheme.surfaceDark.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: LiquidTheme.glassBorderColor
                            .withValues(alpha: 0.3),
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
                                  color: LiquidTheme.textPrimary,
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
                                  color: LiquidTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusAction(
                          status: status,
                          isInviting: isInvitingThis,
                          onInvite: () => _handleInvite(friend),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusAction({
    required FriendInvitationStatus status,
    required bool isInviting,
    required VoidCallback onInvite,
  }) {
    if (isInviting) {
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
            color: LiquidTheme.accentEmerald.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: LiquidTheme.accentEmerald.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 14, color: LiquidTheme.accentEmerald),
              const SizedBox(width: 4),
              Text(
                'Miembro',
                style: TextStyle(
                  color: LiquidTheme.accentEmerald,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: LiquidTheme.liquidPrimaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: LiquidTheme.primaryLiquid.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.send_rounded,
                      size: 13, color: Colors.white),
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
