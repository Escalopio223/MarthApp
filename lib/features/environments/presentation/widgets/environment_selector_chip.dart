import 'package:flutter/material.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../controllers/environment_controller.dart';
import 'create_environment_modal.dart';

/// Chip selector interactivo para la TopBar / AppBar
/// Permite conmutar fluidamente entre entornos y el modo global "Todos"
class EnvironmentSelectorChip extends StatelessWidget {
  final EnvironmentController environmentController;
  final VoidCallback? onEnvironmentChanged;

  const EnvironmentSelectorChip({
    super.key,
    required this.environmentController,
    this.onEnvironmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: environmentController,
      builder: (context, _) {
        final isAll = environmentController.isAllSelected;
        final active = environmentController.activeEnvironment;

        final displayName = isAll
            ? 'Todos'
            : (active?.name ?? 'Mi Espacio');

        final iconData = isAll
            ? Icons.dashboard_customize_rounded
            : (active?.isPersonal == true
                ? Icons.person_pin_rounded
                : Icons.groups_rounded);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showEnvironmentPickerSheet(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: LiquidTheme.surfaceDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isAll
                      ? LiquidTheme.secondaryLilac.withValues(alpha: 0.6)
                      : (active?.isPersonal == true
                          ? LiquidTheme.primaryCyan.withValues(alpha: 0.6)
                          : LiquidTheme.accentEmerald.withValues(alpha: 0.6)),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isAll
                            ? LiquidTheme.secondaryLilac
                            : LiquidTheme.primaryCyan)
                        .withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 16,
                    color: isAll
                        ? LiquidTheme.secondaryLilac
                        : (active?.isPersonal == true
                            ? LiquidTheme.primaryCyan
                            : LiquidTheme.accentEmerald),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: LiquidTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEnvironmentPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EnvironmentPickerSheet(
        controller: environmentController,
        onSelected: () {
          Navigator.pop(context);
          onEnvironmentChanged?.call();
        },
      ),
    );
  }
}

class _EnvironmentPickerSheet extends StatelessWidget {
  final EnvironmentController controller;
  final VoidCallback onSelected;

  const _EnvironmentPickerSheet({
    required this.controller,
    required this.onSelected,
  });

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

              // Opción 1: Vista combinada "Todos"
              _buildOptionTile(
                icon: Icons.dashboard_customize_rounded,
                iconColor: LiquidTheme.secondaryLilac,
                title: 'Todos los entornos',
                subtitle: 'Visualiza el contenido combinado de todos tus espacios',
                isSelected: isAllSelected,
                badgeText: 'Global',
                onTap: () {
                  controller.selectAllEnvironments();
                  onSelected();
                },
              ),
              const SizedBox(height: 8),

              const Divider(color: Color(0x1FFFFFFF), height: 20),

              // Lista de entornos individuales
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: environments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final env = environments[index];
                    final isSelected = !isAllSelected && activeEnv?.id == env.id;

                    return _buildOptionTile(
                      icon: env.isPersonal
                          ? Icons.person_pin_rounded
                          : Icons.groups_rounded,
                      iconColor: env.isPersonal
                          ? LiquidTheme.primaryCyan
                          : LiquidTheme.accentEmerald,
                      title: env.name,
                      subtitle: env.isPersonal
                          ? 'Tu espacio personal privado'
                          : (env.isOwner
                              ? 'Propietario • Espacio compartido'
                              : 'Miembro • Espacio compartido'),
                      isSelected: isSelected,
                      badgeText: env.isPersonal ? 'Personal' : (env.isOwner ? 'Owner' : 'Miembro'),
                      onTap: () {
                        controller.selectEnvironment(env);
                        onSelected();
                      },
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

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    String? badgeText,
    required VoidCallback onTap,
  }) {
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
                child: Icon(icon, color: iconColor, size: 20),
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: LiquidTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
