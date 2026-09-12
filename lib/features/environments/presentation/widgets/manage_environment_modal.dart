import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../domain/models/environment_member_model.dart';
import '../../domain/models/environment_model.dart';
import '../controllers/environment_controller.dart';
import 'environment_danger_zone.dart';
import 'environment_members_list.dart';
import 'invite_friend_modal.dart';
import 'migrate_content_dialog.dart';
import 'personal_environment_view.dart';

/// Modal orquestador para visualizar y gestionar cualquier entorno (Personal o Colaborativo)
class ManageEnvironmentModal extends StatefulWidget {
  final EnvironmentModel environment;
  final EnvironmentController environmentController;
  final FriendsController? friendsController;

  const ManageEnvironmentModal({
    super.key,
    required this.environment,
    required this.environmentController,
    this.friendsController,
  });

  static Future<void> show(
    BuildContext context, {
    required EnvironmentModel environment,
    required EnvironmentController environmentController,
    FriendsController? friendsController,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManageEnvironmentModal(
        environment: environment,
        environmentController: environmentController,
        friendsController: friendsController,
      ),
    );
  }

  @override
  State<ManageEnvironmentModal> createState() => _ManageEnvironmentModalState();
}

class _ManageEnvironmentModalState extends State<ManageEnvironmentModal> {
  List<EnvironmentMemberModel> _members = [];
  bool _isLoadingMembers = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    if (!widget.environment.isPersonal) {
      _loadMembers();
    } else {
      _isLoadingMembers = false;
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final members =
          await widget.environmentController.getMembers(widget.environment.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar miembros: $e';
        _isLoadingMembers = false;
      });
    }
  }

  Future<void> _openInviteFriends() async {
    if (widget.friendsController == null) return;

    await InviteFriendModal.show(
      context,
      environment: widget.environment,
      environmentController: widget.environmentController,
      friendsController: widget.friendsController!,
      memberUserIds: _members.map((m) => m.userId).toList(),
    );

    if (!mounted) return;
    _loadMembers();
  }

  Future<void> _handleRemoveMember(EnvironmentMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.glassBorderColor),
        ),
        title: Text(
          'Expulsar Miembro',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas expulsar a "${member.username}" de "${widget.environment.name}"?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Expulsar',
              style: TextStyle(
                color: AppTheme.accentCoral,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final ok = await widget.environmentController.removeMember(
      environmentId: widget.environment.id,
      userId: member.userId,
    );

    if (!mounted) return;
    if (ok) {
      setState(() {
        _members.removeWhere((m) => m.userId == member.userId);
        _successMessage = 'Miembro "${member.username}" expulsado';
      });
    } else {
      setState(() {
        _errorMessage = widget.environmentController.errorMessage ??
            'No se pudo expulsar al miembro';
      });
    }
  }

  Future<void> _handleDeleteEnvironment() async {
    if (_members.length > 1) {
      setState(() {
        _errorMessage =
            'No puedes eliminar el entorno porque aún tiene miembros asociados. Debes expulsar a todos los miembros primero.';
      });
      return;
    }

    final personalEnv = widget.environmentController.personalEnvironment;
    final sourceId = widget.environment.id;

    final result = await MigrateContentDialog.show(
      context,
      environmentName: widget.environment.name,
      actionTitle: 'Eliminar Definitivamente',
      onMigrateAndProceed: () async {
        if (personalEnv != null && personalEnv.id != sourceId) {
          final okMigrate =
              await widget.environmentController.migrateAllContent(
            sourceEnvironmentId: sourceId,
            targetEnvironmentId: personalEnv.id,
          );
          if (!okMigrate) return false;
        }
        return widget.environmentController.deleteEnvironment(sourceId);
      },
      onProceedWithoutMigrating: () async {
        return widget.environmentController.deleteEnvironment(sourceId);
      },
    );

    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleLeaveEnvironment() async {
    final personalEnv = widget.environmentController.personalEnvironment;
    final sourceId = widget.environment.id;

    final result = await MigrateContentDialog.show(
      context,
      environmentName: widget.environment.name,
      actionTitle: 'Abandonar Entorno',
      onMigrateAndProceed: () async {
        if (personalEnv != null && personalEnv.id != sourceId) {
          final okMigrate =
              await widget.environmentController.migrateAllContent(
            sourceEnvironmentId: sourceId,
            targetEnvironmentId: personalEnv.id,
          );
          if (!okMigrate) return false;
        }
        return widget.environmentController.leaveEnvironment(sourceId);
      },
      onProceedWithoutMigrating: () async {
        return widget.environmentController.leaveEnvironment(sourceId);
      },
    );

    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.environment;
    final isPersonal = env.isPersonal;
    final isOwner = env.isOwner;

    final iconData = isPersonal
        ? Icons.person_pin_rounded
        : (isOwner ? Icons.groups_rounded : Icons.group_work_rounded);

    final iconColor = isPersonal
        ? AppTheme.primaryCyan
        : (isOwner ? AppTheme.secondaryLilac : AppTheme.accentEmerald);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppTheme.glassBorderColor.withValues(alpha: 0.8),
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
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.2),
                ),
                child: Icon(iconData, color: iconColor, size: 24),
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
                            env.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: iconColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            isPersonal
                                ? 'Personal'
                                : (isOwner ? 'Propietario' : 'Miembro'),
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPersonal
                          ? 'Tu espacio privado por defecto'
                          : 'Espacio de trabajo compartido',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: AppTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Feedback banners
          if (_errorMessage != null) ...[
            LiquidBanner(
              message: _errorMessage!,
              type: BannerType.error,
              onClose: () => setState(() => _errorMessage = null),
            ),
            const SizedBox(height: 10),
          ],
          if (_successMessage != null) ...[
            LiquidBanner(
              message: _successMessage!,
              type: BannerType.success,
              onClose: () => setState(() => _successMessage = null),
            ),
            const SizedBox(height: 10),
          ],

          const Divider(color: Color(0x1FFFFFFF), height: 16),

          // Contenido modular: Personal vs Colaborativo
          if (isPersonal) ...[
            const PersonalEnvironmentView(),
          ] else ...[
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: EnvironmentMembersList(
                      members: _members,
                      isLoading: _isLoadingMembers,
                      isOwner: isOwner,
                      canInviteFriends: widget.friendsController != null,
                      onInviteFriends: _openInviteFriends,
                      onRemoveMember: _handleRemoveMember,
                    ),
                  ),
                  const SizedBox(height: 16),
                  EnvironmentDangerZone(
                    isOwner: isOwner,
                    isActionLoading:
                        widget.environmentController.isActionLoading,
                    onDeleteEnvironment: _handleDeleteEnvironment,
                    onLeaveEnvironment: _handleLeaveEnvironment,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
