import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/etiqueta_tarea.dart';
import '../../domain/models/tarea_model.dart';

/// Tarjeta de tarea doméstica con estética Flat Design 2.0:
/// - Checkbox atómico de 1 toque con feedback háptico y animación de tachado.
/// - Título nítido con jerarquía contrastada.
/// - Chip de tiempo estimado (ej. 15m).
/// - Avatar o inicial del conviviente responsable asignado.
/// - Cero sombras pesadas ni volumen neumórfico.
class FlatTaskCard extends StatelessWidget {
  final TareaModel tarea;
  final EnvironmentMemberModel? asignado;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const FlatTaskCard({
    super.key,
    required this.tarea,
    this.asignado,
    required this.onToggle,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = tarea.estaCompletada;
    final etiquetaObj = EtiquetaTarea.buscar(tarea.etiqueta);

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.surfaceDark.withOpacity(0.55)
            : AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? AppTheme.cardBorderColor.withOpacity(0.08)
              : AppTheme.cardBorderColor.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Checkbox plano de 1 toque
                _buildCheckbox(isDone),
                const SizedBox(width: 12),

                // 2. Título, checklist y etiqueta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tarea.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: AppTheme.textSecondary,
                          color: isDone
                              ? AppTheme.textSecondary.withOpacity(0.7)
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (tarea.checklist.isNotEmpty || etiquetaObj != null || tarea.prioridad != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (tarea.prioridad != null) ...[
                              _buildPriorityChip(tarea.prioridad!),
                              const SizedBox(width: 6),
                            ],
                            if (etiquetaObj != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: etiquetaObj.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  etiquetaObj.nombre,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: etiquetaObj.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (tarea.checklist.isNotEmpty) ...[
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 12,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${tarea.checklistItemsCompletados}/${tarea.checklistItemsTotales}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Chip de tiempo estimado (ej. "15m")
                if (tarea.tiempoEstimadoMinutos > 0)
                  _buildTimeChip(tarea.tiempoEstimadoMinutos, isDone),

                const SizedBox(width: 8),

                // 4. Avatar o inicial del responsable asignado
                _buildAssigneeAvatar(asignado, isDone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(bool isDone) {
    return InkWell(
      key: const ValueKey('task_card_checkbox'),
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        if (!isDone) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
        onToggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isDone ? AppTheme.accentEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDone
                ? AppTheme.accentEmerald
                : AppTheme.textSecondary.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: isDone
            ? const Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildPriorityChip(String prioridadKey) {
    Color color;
    String label;
    IconData icon;

    switch (prioridadKey.toLowerCase()) {
      case 'baja':
        color = const Color(0xFF10B981);
        label = 'Baja';
        icon = Icons.keyboard_double_arrow_down_rounded;
        break;
      case 'alta':
        color = const Color(0xFFF59E0B);
        label = 'Alta';
        icon = Icons.keyboard_double_arrow_up_rounded;
        break;
      case 'urgente':
        color = const Color(0xFFEF4444);
        label = 'Urgente';
        icon = Icons.priority_high_rounded;
        break;
      case 'media':
      default:
        color = const Color(0xFF38BDF8);
        label = 'Media';
        icon = Icons.drag_handle_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(int minutes, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.transparent
            : AppTheme.primaryAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDone
              ? AppTheme.cardBorderColor.withOpacity(0.12)
              : AppTheme.primaryAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 11,
            color: isDone
                ? AppTheme.textSecondary
                : AppTheme.primaryAccent,
          ),
          const SizedBox(width: 3),
          Text(
            '${minutes}m',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDone
                  ? AppTheme.textSecondary
                  : AppTheme.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeAvatar(EnvironmentMemberModel? member, bool isDone) {
    if (member == null) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceDark,
          border: Border.all(
            color: AppTheme.cardBorderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: 14,
          color: AppTheme.textSecondary.withOpacity(0.5),
        ),
      );
    }

    final avatarData = member.avatarData;
    if (avatarData != null) {
      return Opacity(
        opacity: isDone ? 0.6 : 1.0,
        child: UserAvatar(
          avatarData: avatarData,
          username: member.username,
          size: 26,
          showBorder: false,
        ),
      );
    }

    final initial = member.username.isNotEmpty
        ? member.username.substring(0, 1).toUpperCase()
        : '?';

    return Opacity(
      opacity: isDone ? 0.6 : 1.0,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryAccent.withOpacity(0.18),
          border: Border.all(
            color: AppTheme.primaryAccent.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryAccent,
            ),
          ),
        ),
      ),
    );
  }
}

