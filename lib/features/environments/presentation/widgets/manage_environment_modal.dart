import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/environment_member_model.dart';
import '../../domain/models/environment_model.dart';
import '../controllers/environment_controller.dart';
import 'invite_friend_modal.dart';
import 'migrate_content_dialog.dart';

/// Modal para visualizar y gestionar cualquier entorno (Personal o Colaborativo)
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
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar miembros: $e';
          _isLoadingMembers = false;
        });
      }
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

    if (mounted) {
      _loadMembers();
    }
  }

  Future<void> _handleRemoveMember(EnvironmentMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LiquidTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: LiquidTheme.glassBorderColor),
        ),
        title: Text(
          'Expulsar Miembro',
          style: TextStyle(
            color: LiquidTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas expulsar a "${member.username}" de "${widget.environment.name}"?',
          style: TextStyle(color: LiquidTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: LiquidTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Expulsar',
              style: TextStyle(
                color: LiquidTheme.accentCoral,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await widget.environmentController.removeMember(
        environmentId: widget.environment.id,
        userId: member.userId,
      );
      if (ok && mounted) {
        setState(() {
          _members.removeWhere((m) => m.userId == member.userId);
          _successMessage = 'Miembro "${member.username}" expulsado';
        });
      }
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
          final okMigrate = await widget.environmentController.migrateAllContent(
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

    if (result == true && mounted) {
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
          final okMigrate = await widget.environmentController.migrateAllContent(
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

    if (result == true && mounted) {
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
        ? LiquidTheme.primaryCyan
        : (isOwner ? LiquidTheme.secondaryLilac : LiquidTheme.accentEmerald);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                              color: LiquidTheme.textPrimary,
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

          // Body Content: Personal vs Collaborative
          if (isPersonal) ...[
            _buildPersonalEnvironmentView(),
          ] else ...[
            _buildCollaborativeEnvironmentView(),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalEnvironmentView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LiquidTheme.primaryCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LiquidTheme.primaryCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LiquidTheme.primaryCyan.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.lock_rounded,
              color: LiquidTheme.primaryCyan,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Espacio Personal Protegido',
            style: TextStyle(
              color: LiquidTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este es tu entorno base personal creado por defecto. Es 100% privado e intransferible: no se pueden agregar miembros ni puede ser eliminado.\n\nTodo el contenido creado aquí solo es visible por ti.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LiquidTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: LiquidTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LiquidTheme.glassBorderColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded,
                    size: 16, color: LiquidTheme.primaryCyan),
                const SizedBox(width: 8),
                Text(
                  'Acceso exclusivo para tu usuario',
                  style: TextStyle(
                    color: LiquidTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborativeEnvironmentView() {
    final isOwner = widget.environment.isOwner;

    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header: Miembros del entorno + Botón Invitar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Miembros (${_members.length})',
                style: TextStyle(
                  color: LiquidTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.friendsController != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openInviteFriends,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LiquidTheme.liquidPrimaryGradient,
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

          // Lista de miembros
          if (_isLoadingMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E5FF),
                ),
              ),
            )
          else if (_members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No se encontraron miembros',
                  style: TextStyle(color: LiquidTheme.textSecondary),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final isMemberOwner = member.role == 'owner';

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
                                  color: LiquidTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isMemberOwner ? 'Propietario' : 'Miembro',
                                style: TextStyle(
                                  color: isMemberOwner
                                      ? LiquidTheme.secondaryLilac
                                      : LiquidTheme.accentEmerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner && !isMemberOwner)
                          IconButton(
                            icon: Icon(
                              Icons.person_remove_rounded,
                              size: 18,
                              color: LiquidTheme.accentCoral
                                  .withValues(alpha: 0.8),
                            ),
                            tooltip: 'Expulsar del entorno',
                            onPressed: () => _handleRemoveMember(member),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // Zona de peligro: Eliminar o Abandonar
          if (isOwner) ...[
            LiquidButton(
              text: 'Eliminar Entorno',
              icon: Icons.delete_outline_rounded,
              gradient: LinearGradient(
                colors: [
                  LiquidTheme.accentCoral,
                  Colors.red.shade900,
                ],
              ),
              onPressed: _handleDeleteEnvironment,
            ),
          ] else ...[
            LiquidButton(
              text: 'Abandonar Entorno',
              icon: Icons.exit_to_app_rounded,
              gradient: LinearGradient(
                colors: [
                  LiquidTheme.accentCoral,
                  Colors.red.shade900,
                ],
              ),
              onPressed: _handleLeaveEnvironment,
            ),
          ],
        ],
      ),
    );
  }
}
