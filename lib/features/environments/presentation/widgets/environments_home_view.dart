import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/models/environment_invitation_model.dart';
import '../../domain/models/environment_model.dart';
import '../controllers/environment_controller.dart';
import 'create_environment_modal.dart';
import 'environment_invitation_tile.dart';
import 'manage_environment_modal.dart';

/// Vista principal enfocada y minimalista para la gestion integral de entornos (Workspaces):
/// - Sin cajas de saludo, ni banner de Mi espacio, ni acceso duplicado a ocio, ni backend card
/// - Bandeja interactiva para responder invitaciones pendientes
/// - Selector y lista de espacios de trabajo con indicador visual del entorno activo
/// - Accion rapida para crear un nuevo entorno
class EnvironmentsHomeView extends StatelessWidget {
  final EnvironmentController environmentController;
  final FriendsController friendsController;
  final ProfileController? profileController;
  final String? userEmail;
  final VoidCallback? onNavigateToLeisure;
  final VoidCallback? onNavigateToPlanificador;
  final VoidCallback? onNavigateToFriends;
  final VoidCallback? onOpenSettings;
  final int rouletteCount;

  const EnvironmentsHomeView({
    super.key,
    required this.environmentController,
    required this.friendsController,
    this.profileController,
    this.userEmail,
    this.onNavigateToLeisure,
    this.onNavigateToPlanificador,
    this.onNavigateToFriends,
    this.onOpenSettings,
    this.rouletteCount = 0,
  });

  static String formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Propietario';
      case 'admin':
        return 'Administrador';
      default:
        return 'Miembro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEnv = environmentController.activeEnvironment;
    final isAll = environmentController.isAllSelected;
    final pendingInvites = environmentController.pendingInvitations;
    final environments = environmentController.environments;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Bandeja de Invitaciones Pendientes (si existen)
              if (pendingInvites.isNotEmpty) ...[
                _buildPendingInvitationsSection(context, pendingInvites),
                const SizedBox(height: 20),
              ],

              // 2. Selector / Lista de Espacios de Trabajo
              _buildWorkspacesSection(context, environments, activeEnv, isAll),
              const SizedBox(height: 20),

              // 3. Módulos del entorno activo
              if (activeEnv != null && !isAll) ...[
                _buildActiveModulesSection(context, activeEnv),
                const SizedBox(height: 20),
              ],

              // 4. Accion de creacion rapida
              AppButton(
                text: 'Crear nuevo entorno',
                icon: Icons.add_rounded,
                gradient: AppTheme.actionGradient,
                onPressed: () => CreateEnvironmentModal.show(
                  context,
                  environmentController: environmentController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveModulesSection(
    BuildContext context,
    EnvironmentModel activeEnv,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MÓDULOS DE ${activeEnv.name.toUpperCase()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Módulo Planificador
            Expanded(
              child: AppCard(
                onTap: onNavigateToPlanificador,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.actionGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Planificador',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Agenda, tareas y reparto',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Módulo Ocio
            Expanded(
              child: AppCard(
                onTap: onNavigateToLeisure,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_activity_rounded,
                        color: AppTheme.secondaryAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ocio & Cultura',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Películas, series y juegos',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingInvitationsSection(
    BuildContext context,
    List<EnvironmentInvitationModel> pendingInvites,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_rounded,
                  color: AppTheme.accentEmerald,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invitaciones Pendientes ()',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingInvites.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final inv = pendingInvites[index];
              return EnvironmentInvitationTile(
                invitation: inv,
                isLoading: environmentController.isActionLoading,
                onAccept: () => environmentController.respondInvitation(
                  invitationId: inv.id,
                  accept: true,
                ),
                onDecline: () => environmentController.respondInvitation(
                  invitationId: inv.id,
                  accept: false,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspacesSection(
    BuildContext context,
    List<EnvironmentModel> environments,
    EnvironmentModel? activeEnv,
    bool isAll,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tus espacios de trabajo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppTheme.primaryLiquid,
              tooltip: 'Crear nuevo entorno',
              onPressed: () => CreateEnvironmentModal.show(
                context,
                environmentController: environmentController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Opcion global: 'Todos'
        _buildEnvironmentSelectTile(
          title: 'Todos los entornos',
          subtitle: 'Vista combinada de todos tus espacios',
          icon: Icons.dashboard_customize_rounded,
          isSelected: isAll,
          onTap: () => environmentController.selectAllEnvironments(),
        ),
        const SizedBox(height: 8),

        // Lista de entornos
        if (environments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No hay entornos cargados aun',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ...environments.map((env) {
            final isSelected = !isAll && activeEnv?.id == env.id;
            final roleStr = formatRole(env.role);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildEnvironmentSelectTile(
                title: env.name,
                subtitle: env.isPersonal
                    ? 'Espacio Personal Privado'
                    : '$roleStr • ${env.memberCount} participante(s)',
                icon: env.iconData,
                customColor: env.colorValue,
                isSelected: isSelected,
                isPersonal: env.isPersonal,
                onTap: () => environmentController.selectEnvironment(env),
                onManage: !env.isPersonal
                    ? () => ManageEnvironmentModal.show(
                        context,
                        environment: env,
                        environmentController: environmentController,
                        friendsController: friendsController,
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEnvironmentSelectTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? customColor,
    bool isPersonal = false,
    VoidCallback? onManage,
  }) {
    final effectiveColor =
        customColor ??
        (isPersonal ? AppTheme.primaryCyan : AppTheme.primaryLiquid);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? effectiveColor.withValues(alpha: 0.12)
                : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? effectiveColor : AppTheme.cardBorderColor,
              width: isSelected ? 1.4 : 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(
                    alpha: isSelected ? 0.24 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: effectiveColor.withValues(
                      alpha: isSelected ? 0.55 : 0.25,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, size: 20, color: effectiveColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected
                            ? effectiveColor
                            : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onManage != null)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  color: AppTheme.textSecondary,
                  tooltip: 'Opciones de entorno',
                  onPressed: onManage,
                ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: effectiveColor,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
