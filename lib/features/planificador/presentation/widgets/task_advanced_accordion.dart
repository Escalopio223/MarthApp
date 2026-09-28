import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/etiqueta_tarea.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/recurrence_rule.dart';
import 'recurring_rule_form_widget.dart';
import 'subtask_list.dart';

/// Componente colapsable / expandible de Opciones Avanzadas para el formulario de tareas.
/// Mantiene la persistencia de todos los inputs y selecciones internas incluso cuando
/// el usuario cierra o colapsa el acordeón.
class TaskAdvancedAccordion extends StatefulWidget {
  final bool initiallyExpanded;
  final int? tiempoEstimadoMinutos;
  final ValueChanged<int?> onTiempoEstimadoChanged;
  final List<ProyectoModel> proyectos;
  final String? proyectoId;
  final ValueChanged<String?> onProyectoChanged;
  final String? etiqueta;
  final ValueChanged<String?> onEtiquetaChanged;
  final TextEditingController notasController;
  final List<ChecklistItemModel> subtasks;
  final ValueChanged<List<ChecklistItemModel>> onSubtasksChanged;
  final bool isRecurring;
  final ValueChanged<bool> onIsRecurringChanged;
  final RecurrenceRule? recurrenceRule;
  final ValueChanged<RecurrenceRule> onRecurrenceRuleChanged;
  final bool hasReminder;
  final ValueChanged<bool> onHasReminderChanged;
  final int? reminderMinutesBefore;
  final ValueChanged<int?> onReminderMinutesChanged;

  const TaskAdvancedAccordion({
    super.key,
    this.initiallyExpanded = false,
    this.tiempoEstimadoMinutos,
    required this.onTiempoEstimadoChanged,
    this.proyectos = const [],
    this.proyectoId,
    required this.onProyectoChanged,
    this.etiqueta,
    required this.onEtiquetaChanged,
    required this.notasController,
    this.subtasks = const [],
    required this.onSubtasksChanged,
    this.isRecurring = false,
    required this.onIsRecurringChanged,
    this.recurrenceRule,
    required this.onRecurrenceRuleChanged,
    this.hasReminder = false,
    required this.onHasReminderChanged,
    this.reminderMinutesBefore,
    required this.onReminderMinutesChanged,
  });

  @override
  State<TaskAdvancedAccordion> createState() => _TaskAdvancedAccordionState();
}

class _TaskAdvancedAccordionState extends State<TaskAdvancedAccordion> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }


  int _countConfiguredFields() {
    int count = 0;
    if (widget.tiempoEstimadoMinutos != null && widget.tiempoEstimadoMinutos! > 0) count++;
    if (widget.proyectoId != null) count++;
    if (widget.etiqueta != null) count++;
    if (widget.notasController.text.trim().isNotEmpty) count++;
    if (widget.subtasks.isNotEmpty) count++;
    if (widget.isRecurring) count++;
    if (widget.hasReminder) count++;
    return count;
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _countConfiguredFields();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded || activeCount > 0
              ? AppTheme.secondaryLilac.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera interactiva del acordeón
          _buildAccordionHeader(activeCount),

          // Contenido expandible animado (el estado persiste 100% al colapsar)
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: Colors.white10),
                        const SizedBox(height: 14),

                        // 1. Estimación de Tiempo
                        _buildTiempoEstimadoSection(),
                        const SizedBox(height: 16),

                        // 2. Taxonomía: Proyecto y Categoría / Etiqueta
                        _buildTaxonomiaSection(),
                        const SizedBox(height: 16),

                        // 3. Tarea Recurrente (Repetición periódica automática)
                        _buildRecurrenciaSection(),
                        const SizedBox(height: 16),

                        // 4. Bloque de Notas y Comentarios extendidos
                        _buildNotasSection(),
                        const SizedBox(height: 16),

                        // 5. Subtareas / Checklist interactivo
                        _buildSubtasksSection(),
                        const SizedBox(height: 16),

                        // 6. Recordatorio de alerta
                        _buildRecordatorioSection(),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionHeader(int activeCount) {
    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _isExpanded || activeCount > 0
                    ? AppTheme.secondaryLilac.withValues(alpha: 0.18)
                    : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 16,
                color: _isExpanded || activeCount > 0
                    ? AppTheme.secondaryLilac
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opciones avanzadas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeCount > 0
                        ? '$activeCount ${activeCount == 1 ? "opción configurada" : "opciones configuradas"}'
                        : 'Proyecto, etiquetas, subtareas, repetición...',
                    style: TextStyle(
                      fontSize: 11,
                      color: activeCount > 0
                          ? AppTheme.secondaryLilac
                          : AppTheme.textSecondary.withValues(alpha: 0.65),
                      fontWeight: activeCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (activeCount > 0 && !_isExpanded) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryLilac.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.secondaryLilac.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '+$activeCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryLilac,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Estimación de Tiempo
  // ===========================================================================
  Widget _buildTiempoEstimadoSection() {
    final currentMin = widget.tiempoEstimadoMinutos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 14, color: AppTheme.secondaryLilac),
            const SizedBox(width: 6),
            Text(
              'Estimación de tiempo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            if (currentMin != null && currentMin > 0) ...[
              const Spacer(),
              Text(
                currentMin >= 60
                    ? '${currentMin ~/ 60}h ${currentMin % 60 > 0 ? "${currentMin % 60}m" : ""}'
                    : '$currentMin min',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryLilac,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildTimeChip(label: 'Sin tiempo', minutes: null, isSelected: currentMin == null || currentMin <= 0),
            const SizedBox(width: 6),
            _buildTimeChip(label: '15 min', minutes: 15, isSelected: currentMin == 15),
            const SizedBox(width: 6),
            _buildTimeChip(label: '30 min', minutes: 30, isSelected: currentMin == 30),
            const SizedBox(width: 6),
            _buildTimeChip(label: '45 min', minutes: 45, isSelected: currentMin == 45),
            const SizedBox(width: 6),
            _buildTimeChip(label: '1 hora', minutes: 60, isSelected: currentMin == 60),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeChip({
    required String label,
    required int? minutes,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTiempoEstimadoChanged(minutes);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.secondaryLilac.withValues(alpha: 0.18)
                : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.secondaryLilac : AppTheme.cardBorderColor,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.secondaryLilac : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. Taxonomía: Proyecto y Categoría / Etiqueta
  // ===========================================================================
  Widget _buildTaxonomiaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de Proyecto si existen proyectos
        if (widget.proyectos.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: AppTheme.primaryLiquid),
              const SizedBox(width: 6),
              Text(
                'Proyecto asociado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildProjectChip(
                  nombre: 'Sin proyecto',
                  icono: Icons.folder_off_outlined,
                  color: AppTheme.textSecondary,
                  isSelected: widget.proyectoId == null,
                  onTap: () => widget.onProyectoChanged(null),
                ),
                const SizedBox(width: 8),
                ...widget.proyectos.map((p) {
                  final color = _parseColor(p.colorHex);
                  final isSelected = widget.proyectoId == p.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildProjectChip(
                      nombre: p.nombre,
                      icono: Icons.folder_rounded,
                      color: color,
                      isSelected: isSelected,
                      onTap: () => widget.onProyectoChanged(p.id),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Selector de Categoría / Etiqueta
        Row(
          children: [
            Icon(Icons.label_outlined, size: 14, color: AppTheme.accentEmerald),
            const SizedBox(width: 6),
            Text(
              'Categoría / Etiqueta',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildEtiquetaChip(
                nombre: 'Sin etiqueta',
                icono: Icons.label_off_outlined,
                color: AppTheme.textSecondary,
                isSelected: widget.etiqueta == null,
                onTap: () => widget.onEtiquetaChanged(null),
              ),
              const SizedBox(width: 8),
              ...EtiquetaTarea.etiquetasPredeterminadas.map((e) {
                final isSelected = widget.etiqueta?.toLowerCase() == e.nombre.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildEtiquetaChip(
                    nombre: e.nombre,
                    icono: e.icono,
                    color: e.color,
                    isSelected: isSelected,
                    onTap: () => widget.onEtiquetaChanged(isSelected ? null : e.nombre),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProjectChip({
    required String nombre,
    required IconData icono,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: isSelected ? color : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtiquetaChip({
    required String nombre,
    required IconData icono,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: isSelected ? color : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryLiquid;
    }
  }

  // ===========================================================================
  // 3. Tarea Recurrente (Repetición periódica)
  // ===========================================================================
  Widget _buildRecurrenciaSection() {
    final effectiveRule = widget.recurrenceRule ??
        RecurrenceRule.weekly(daysOfWeek: [DateTime.now().weekday]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isRecurring
                  ? AppTheme.primaryLiquid.withValues(alpha: 0.6)
                  : AppTheme.cardBorderColor,
              width: widget.isRecurring ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: widget.isRecurring
                      ? AppTheme.primaryLiquid.withValues(alpha: 0.2)
                      : AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  size: 18,
                  color: widget.isRecurring ? AppTheme.primaryLiquid : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarea recurrente',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      widget.isRecurring
                          ? effectiveRule.toHumanReadable()
                          : 'Configurar repetición periódica automática',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: widget.isRecurring,
                activeTrackColor: AppTheme.primaryLiquid,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  widget.onIsRecurringChanged(val);
                },
              ),
            ],
          ),
        ),

        // Subformulario desplegable si la recurrencia está activa
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          child: widget.isRecurring
              ? Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: RecurringRuleFormWidget(
                    rule: effectiveRule,
                    onChanged: (rule) {
                      widget.onRecurrenceRuleChanged(rule);
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. Bloque de Notas / Comentarios
  // ===========================================================================
  Widget _buildNotasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes_rounded, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Notas adicionales',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.notasController,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'Añade instrucciones, enlaces, advertencias o detalles clave...',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppTheme.surfaceDark,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.cardBorderColor,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.secondaryLilac,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. Lista interactiva de Subtareas / Checklist con Drag & Drop
  // ===========================================================================
  Widget _buildSubtasksSection() {
    return SubtaskList(
      items: widget.subtasks,
      onChanged: widget.onSubtasksChanged,
    );
  }

  // ===========================================================================
  // 5. Placeholder para Recordatorio
  // ===========================================================================
  Widget _buildRecordatorioSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.hasReminder
              ? AppTheme.accentCoral.withValues(alpha: 0.6)
              : AppTheme.cardBorderColor,
          width: widget.hasReminder ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.hasReminder ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                size: 18,
                color: widget.hasReminder ? AppTheme.accentCoral : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recordatorio de alerta',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      widget.hasReminder
                          ? 'Notificar ${_formatReminderText(widget.reminderMinutesBefore)}'
                          : 'Avisar antes de la fecha programada',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: widget.hasReminder,
                activeTrackColor: AppTheme.accentCoral,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  widget.onHasReminderChanged(val);
                  if (val && widget.reminderMinutesBefore == null) {
                    widget.onReminderMinutesChanged(15);
                  }
                },
              ),
            ],
          ),

          // Opciones de anticipación si el recordatorio está activo
          if (widget.hasReminder) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildReminderChip(label: '15 min antes', minutes: 15),
                const SizedBox(width: 6),
                _buildReminderChip(label: '30 min antes', minutes: 30),
                const SizedBox(width: 6),
                _buildReminderChip(label: '1 h antes', minutes: 60),
                const SizedBox(width: 6),
                _buildReminderChip(label: '1 día antes', minutes: 1440),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderChip({required String label, required int minutes}) {
    final isSelected = widget.reminderMinutesBefore == minutes;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onReminderMinutesChanged(minutes);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentCoral.withValues(alpha: 0.18)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.accentCoral : AppTheme.cardBorderColor,
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.accentCoral : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatReminderText(int? minutes) {
    if (minutes == null || minutes <= 0) return 'al momento';
    if (minutes < 60) return '$minutes minutos antes';
    if (minutes == 60) return '1 hora antes';
    if (minutes == 1440) return '1 día antes';
    return '${minutes ~/ 60} horas antes';
  }
}
