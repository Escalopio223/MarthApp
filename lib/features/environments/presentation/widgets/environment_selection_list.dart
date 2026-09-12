import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/environment_model.dart';

/// Componente presentacional reutilizable para renderizar colecciones de entornos
/// Utilizado tanto por EnvironmentPickerSheet (selector global) como por InviteToEnvironmentSheet
class EnvironmentSelectionList extends StatelessWidget {
  final List<EnvironmentModel> environments;
  final String? selectedEnvironmentId;
  final ValueChanged<EnvironmentModel> onSelect;
  final void Function(EnvironmentModel)? onManage;
  final String emptyMessage;

  const EnvironmentSelectionList({
    super.key,
    required this.environments,
    this.selectedEnvironmentId,
    required this.onSelect,
    this.onManage,
    this.emptyMessage = 'No hay entornos disponibles',
  });

  @override
  Widget build(BuildContext context) {
    if (environments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: environments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final env = environments[index];
        final isSelected = selectedEnvironmentId == env.id;

        final iconData = env.isPersonal
            ? Icons.person_pin_rounded
            : Icons.groups_rounded;

        final iconColor = env.isPersonal
            ? AppTheme.primaryCyan
            : AppTheme.accentEmerald;

        final badgeText = env.isPersonal
            ? 'Personal'
            : (env.isOwner ? 'Propietario' : 'Miembro');

        final subtitle = env.isPersonal
            ? 'Tu espacio personal privado'
            : (env.isOwner
                ? 'Propietario • Espacio compartido'
                : 'Miembro • Espacio compartido');

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(env),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? iconColor.withValues(alpha: 0.12)
                    : AppTheme.surfaceDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? iconColor.withValues(alpha: 0.8)
                      : AppTheme.glassBorderColor.withValues(alpha: 0.4),
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
                    child: Icon(iconData, color: iconColor, size: 20),
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
                                env.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
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
                                badgeText,
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
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
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
                  if (onManage != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.tune_rounded,
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        size: 19,
                      ),
                      tooltip: 'Gestionar entorno',
                      onPressed: () => onManage!(env),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
