import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../controllers/environment_controller.dart';
import 'create_environment_modal.dart';
import 'environment_selection_list.dart';
import 'manage_environment_modal.dart';

/// Hoja modal para conmutar entornos de trabajo y crear nuevos espacios
class EnvironmentPickerSheet extends StatelessWidget {
  final EnvironmentController controller;
  final FriendsController? friendsController;
  final VoidCallback onSelected;

  const EnvironmentPickerSheet({
    super.key,
    required this.controller,
    this.friendsController,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required EnvironmentController controller,
    FriendsController? friendsController,
    required VoidCallback onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EnvironmentPickerSheet(
        controller: controller,
        friendsController: friendsController,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final environments = controller.environments;
    final isAllSelected = controller.isAllSelected;
    final activeEnv = controller.activeEnvironment;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: LiquidTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: LiquidTheme.glassBorderColor.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador de arrastre
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
              const SizedBox(height: 18),

              // Título y botón de cierre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Entornos de Trabajo',
                    style: TextStyle(
                      color: LiquidTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

              // Opción 1: Vista combinada global "Todos los entornos"
              _buildGlobalOptionTile(
                isSelected: isAllSelected,
                onTap: () {
                  controller.selectAllEnvironments();
                  onSelected();
                },
              ),
              const SizedBox(height: 8),

              const Divider(color: Color(0x1FFFFFFF), height: 20),

              // Lista modular reutilizable de entornos
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: EnvironmentSelectionList(
                  environments: environments,
                  selectedEnvironmentId:
                      !isAllSelected ? activeEnv?.id : null,
                  onSelect: (env) {
                    controller.selectEnvironment(env);
                    onSelected();
                  },
                  onManage: (env) {
                    Navigator.pop(context);
                    ManageEnvironmentModal.show(
                      context,
                      environment: env,
                      environmentController: controller,
                      friendsController: friendsController,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Botón de acción: Crear nuevo entorno
              LiquidButton(
                text: 'Crear Nuevo Entorno',
                icon: Icons.add_circle_outline_rounded,
                gradient: LiquidTheme.liquidPrimaryGradient,
                onPressed: () {
                  Navigator.pop(context);
                  CreateEnvironmentModal.show(
                    context,
                    environmentController: controller,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalOptionTile({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final iconColor = LiquidTheme.secondaryLilac;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? iconColor.withValues(alpha: 0.12)
                : LiquidTheme.surfaceDark.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? iconColor.withValues(alpha: 0.8)
                  : LiquidTheme.glassBorderColor.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Todos los entornos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: LiquidTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Global',
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Visualiza el contenido combinado de todos tus espacios',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: iconColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
