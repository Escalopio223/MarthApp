import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/recordatorio_tarea_model.dart';
import '../../domain/models/tarea_model.dart';
import 'subtask_list.dart';

/// Selector activo en la bandeja inline contextual
enum ActiveTaskSelector {
  none,
  dateAndTime,
  assignee,
  duration,
  project,
  recurrence,
  reminders,
}

/// Smart Canvas BottomSheet para creación y edición de tareas y eventos (estilo Linear / Things 3).
///
/// Arquitectura visual:
/// 1. Cabecera limpia con selector plano Tarea / Evento.
/// 2. Lienzo de texto fluido sin cajas pesadas (título grande 19px + notas integradas 14px).
/// 3. Barra de píldoras de estado horizontal compacta con resumen dinámico.
/// 4. Bandeja contextual inline única desplegada mediante AnimatedSize + AnimatedSwitcher.
/// 5. Módulos bajo demanda para Recurrencia, Recordatorios relativos y Subtareas interactivas.
/// 6. Pie del modal con botón de guardado destacado y opción de eliminación en edición.
class FlatCreateItemSheet extends StatefulWidget {
  final DateTime defaultDate;
  final List<EnvironmentMemberModel> miembros;
  final String? currentUserId;
  final List<ProyectoModel> proyectos;
  final TareaModel? tareaToEdit;
  final VoidCallback? onDeleteTask;
  final Future<void> Function({
    required String titulo,
    DateTime? fechaLimite,
    String? asignadoA,
    int tiempoEstimadoMinutos,
    String? proyectoId,
    String? descripcion,
    List<ChecklistItemModel> checklist,
    List<RecordatorioTareaModel> recordatorios,
  }) onCreateTask;
  final Future<void> Function({
    required String titulo,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    bool esTodoElDia,
    String tipo,
    String? personaCumpleanos,
    String? ideasRegalo,
    List<ChecklistItemModel> checklist,
    List<RecordatorioTareaModel> recordatorios,
  }) onCreateEvent;

  const FlatCreateItemSheet({
    super.key,
    required this.defaultDate,
    required this.miembros,
    this.currentUserId,
    this.proyectos = const [],
    this.tareaToEdit,
    this.onDeleteTask,
    required this.onCreateTask,
    required this.onCreateEvent,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime defaultDate,
    required List<EnvironmentMemberModel> miembros,
    String? currentUserId,
    List<ProyectoModel> proyectos = const [],
    TareaModel? tareaToEdit,
    VoidCallback? onDeleteTask,
    required Future<void> Function({
      required String titulo,
      DateTime? fechaLimite,
      String? asignadoA,
      int tiempoEstimadoMinutos,
      String? proyectoId,
      String? descripcion,
      List<ChecklistItemModel> checklist,
      List<RecordatorioTareaModel> recordatorios,
    }) onCreateTask,
    required Future<void> Function({
      required String titulo,
      required DateTime fechaInicio,
      DateTime? fechaFin,
      bool esTodoElDia,
      String tipo,
      String? personaCumpleanos,
      String? ideasRegalo,
      List<ChecklistItemModel> checklist,
      List<RecordatorioTareaModel> recordatorios,
    }) onCreateEvent,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlatCreateItemSheet(
        defaultDate: defaultDate,
        miembros: miembros,
        currentUserId: currentUserId,
        proyectos: proyectos,
        tareaToEdit: tareaToEdit,
        onDeleteTask: onDeleteTask,
        onCreateTask: onCreateTask,
        onCreateEvent: onCreateEvent,
      ),
    );
  }

  @override
  State<FlatCreateItemSheet> createState() => _FlatCreateItemSheetState();
}

class _FlatCreateItemSheetState extends State<FlatCreateItemSheet> {
  // 0 = Tarea, 1 = Evento
  int _selectedTypeIndex = 0;
  bool _isSubmitting = false;

  // ===========================================================================
  // Estado Tarea: Campos Principales
  // ===========================================================================
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescController = TextEditingController();
  late DateTime _taskDate;
  String? _assignedTo;
  String? _selectedProyectoId;
  String? _taskError;

  // Momento del día: 'anytime' | 'morning' | 'afternoon' | 'night'
  String _selectedTimeOfDay = 'anytime';

  // Duración estimada: 0, 15, 30, 60
  int _selectedDurationMinutes = 15;

  // ===========================================================================
  // Smart Canvas: Bandeja Contextual Inline y Módulos Bajo Demanda
  // ===========================================================================
  ActiveTaskSelector _activeSelector = ActiveTaskSelector.none;
  bool _showSubtasks = false;

  // Recurrencia: 'none' | 'daily' | 'weekly' | 'monthly'
  String _recurrenceMode = 'none';
  bool _autoRotateAssignee = false;

  // Recordatorios relativos (multiselección): offsets en días [1, 3, 7]
  final Set<int> _selectedReminderOffsets = {};

  // Checklist de subtareas
  List<ChecklistItemModel> _taskChecklist = [];

  // ===========================================================================
  // Estado Evento / Cumpleaños
  // ===========================================================================
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _giftIdeaInputController = TextEditingController();
  late DateTime _eventDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  String _eventType = 'evento_general'; // 'evento_general' | 'cumpleanos'
  int? _reminderMinutesBefore; // null, 15, 60, 1440
  List<String> _ideasRegaloList = [];
  String? _eventError;

  bool get _isEditingTask => widget.tareaToEdit != null;

  @override
  void initState() {
    super.initState();
    _taskDate = widget.tareaToEdit?.fechaLimite ?? widget.defaultDate;
    _eventDate = widget.defaultDate;
    _assignedTo = widget.tareaToEdit?.asignadoA ?? widget.currentUserId;

    if (_isEditingTask) {
      final t = widget.tareaToEdit!;
      _selectedTypeIndex = 0;
      _taskTitleController.text = t.titulo;
      _taskDescController.text = t.notasLimpias ?? '';
      _selectedDurationMinutes = _normalizeDuration(t.tiempoEstimadoMinutos);
      _selectedProyectoId = t.proyectoId;
      _taskChecklist = List.from(t.checklist);

      if (_taskChecklist.isNotEmpty) {
        _showSubtasks = true;
      }

      // Parsear momento del día
      final tod = t.timeOfDay;
      if (tod != null && ['anytime', 'morning', 'afternoon', 'night'].contains(tod)) {
        _selectedTimeOfDay = tod;
      }

      // Parsear recurrencia
      final rrule = t.rruleString;
      if (rrule != null) {
        if (rrule.contains('FREQ=DAILY')) {
          _recurrenceMode = 'daily';
        } else if (rrule.contains('FREQ=WEEKLY')) {
          _recurrenceMode = 'weekly';
        } else if (rrule.contains('FREQ=MONTHLY')) {
          _recurrenceMode = 'monthly';
        }
      }

      _autoRotateAssignee = t.autoRotateAssignee;

      // Parsear recordatorios relativos existentes
      if (t.recordatorios.isNotEmpty && t.fechaLimite != null) {
        final dLimite = DateTime(
          t.fechaLimite!.year,
          t.fechaLimite!.month,
          t.fechaLimite!.day,
        );
        for (final r in t.recordatorios) {
          final dNotif = DateTime(
            r.fechaNotificacion.year,
            r.fechaNotificacion.month,
            r.fechaNotificacion.day,
          );
          final diff = dLimite.difference(dNotif).inDays;
          if (diff == 1 || diff == 3 || diff == 7) {
            _selectedReminderOffsets.add(diff);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskDescController.dispose();
    _eventTitleController.dispose();
    _giftIdeaInputController.dispose();
    super.dispose();
  }

  int _normalizeDuration(int mins) {
    if (mins <= 0) return 0;
    if (mins <= 20) return 15;
    if (mins <= 45) return 30;
    return 60;
  }

  String _formatDateShort(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hoy';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
      return 'Mañana';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _pickDate({required bool forTask}) async {
    final initial = forTask ? _taskDate : _eventDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryAccent,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (forTask) {
          _taskDate = picked;
        } else {
          _eventDate = picked;
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryAccent,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ??
          TimeOfDay(
            hour: (_startTime.hour + 1) % 24,
            minute: _startTime.minute,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryAccent,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String? _buildRecurrencePattern() {
    switch (_recurrenceMode) {
      case 'daily':
        return 'FREQ=DAILY;INTERVAL=1';
      case 'weekly':
        return 'FREQ=WEEKLY;INTERVAL=1';
      case 'monthly':
        return 'FREQ=MONTHLY;INTERVAL=1';
      default:
        return null;
    }
  }

  String? _composeTaskDescription() {
    final buffer = StringBuffer();

    if (_selectedTimeOfDay != 'anytime') {
      buffer.write('[time_of_day:$_selectedTimeOfDay] ');
    }

    final rrule = _buildRecurrencePattern();
    if (rrule != null) {
      buffer.write('[rrule:$rrule] ');
    }

    if (_recurrenceMode != 'none' && _autoRotateAssignee) {
      buffer.write('[auto_rotate:true] ');
    }

    final userNotes = _taskDescController.text.trim();
    if (userNotes.isNotEmpty) {
      buffer.write(userNotes);
    }

    final result = buffer.toString().trim();
    return result.isNotEmpty ? result : null;
  }

  List<RecordatorioTareaModel> _buildRecordatoriosList() {
    final recordatorios = <RecordatorioTareaModel>[];
    final baseDate = DateTime(
      _taskDate.year,
      _taskDate.month,
      _taskDate.day,
      9,
      0,
    );

    final sortedOffsets = _selectedReminderOffsets.toList()..sort();
    for (final daysBefore in sortedOffsets) {
      final notifDate = baseDate.subtract(Duration(days: daysBefore));
      recordatorios.add(
        RecordatorioTareaModel(
          id: 'rec_${daysBefore}_${DateTime.now().millisecondsSinceEpoch}',
          tareaId: widget.tareaToEdit?.id ?? '',
          fechaNotificacion: notifDate,
          horaNotificacion: '09:00',
        ),
      );
    }

    return recordatorios;
  }

  Future<void> _submitTask() async {
    final title = _taskTitleController.text.trim();
    if (title.isEmpty) {
      setState(() => _taskError = 'Por favor escribe el título de la tarea');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _taskError = null;
    });

    try {
      final desc = _composeTaskDescription();
      final recordatorios = _buildRecordatoriosList();

      await widget.onCreateTask(
        titulo: title,
        fechaLimite: _taskDate,
        asignadoA: _assignedTo,
        tiempoEstimadoMinutos: _selectedDurationMinutes,
        proyectoId: _selectedProyectoId,
        descripcion: desc,
        checklist: _taskChecklist,
        recordatorios: recordatorios,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _taskError = 'Error al guardar tarea: $e';
        });
      }
    }
  }

  Future<void> _submitEvent() async {
    final title = _eventTitleController.text.trim();
    if (title.isEmpty) {
      setState(() => _eventError = 'Por favor escribe el título del evento');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _eventError = null;
    });

    try {
      final startDateTime = DateTime(
        _eventDate.year,
        _eventDate.month,
        _eventDate.day,
        _isAllDay ? 0 : _startTime.hour,
        _isAllDay ? 0 : _startTime.minute,
      );

      DateTime? endDateTime;
      if (!_isAllDay && _endTime != null) {
        endDateTime = DateTime(
          _eventDate.year,
          _eventDate.month,
          _eventDate.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      final recordatorios = <RecordatorioTareaModel>[];
      if (_reminderMinutesBefore != null) {
        final notifTime =
            startDateTime.subtract(Duration(minutes: _reminderMinutesBefore!));
        recordatorios.add(
          RecordatorioTareaModel(
            id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
            tareaId: '',
            fechaNotificacion: notifTime,
          ),
        );
      }

      final ideasRegaloStr = _ideasRegaloList.isNotEmpty
          ? _ideasRegaloList.map((idea) => '- $idea').join('\n')
          : null;

      await widget.onCreateEvent(
        titulo: title,
        fechaInicio: startDateTime,
        fechaFin: endDateTime,
        esTodoElDia: _isAllDay,
        tipo: _eventType,
        personaCumpleanos: _eventType == 'cumpleanos' ? title : null,
        ideasRegalo: ideasRegaloStr,
        recordatorios: recordatorios,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _eventError = 'Error al guardar evento: $e';
        });
      }
    }
  }

  void _toggleSelector(ActiveTaskSelector selector) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeSelector = _activeSelector == selector ? ActiveTaskSelector.none : selector;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: AppTheme.cardBorderColor.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Selector plano de tipo [ Tarea ] | [ Evento ] o Cabecera de Edición
              if (!_isEditingTask) ...[
                _buildTypeSelector(),
                const SizedBox(height: 16),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Editar Tarea',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onDeleteTask != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            color: AppTheme.accentCoral,
                            tooltip: 'Eliminar tarea',
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(),
                            onPressed: _confirmDeleteTask,
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Formulario según tipo
              if (_selectedTypeIndex == 0)
                _buildTaskSmartCanvas()
              else
                _buildEventForm(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Selector Plano de Tipo
  // ===========================================================================

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.cardBorderColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeTab(
              title: 'Tarea',
              icon: Icons.check_circle_outline_rounded,
              index: 0,
            ),
          ),
          Expanded(
            child: _buildTypeTab(
              title: 'Evento / Cita',
              icon: Icons.event_rounded,
              index: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _selectedTypeIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTypeIndex = index);
      },
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Smart Canvas: Tarea (Estilo Linear / Things 3)
  // ===========================================================================

  Widget _buildTaskSmartCanvas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Lienzo de texto fluido (Sin cajas pesadas)
        TextField(
          controller: _taskTitleController,
          autofocus: true,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          cursorColor: AppTheme.primaryAccent,
          decoration: InputDecoration(
            hintText: '¿Qué hay que hacer?',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.45),
              fontSize: 19,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
        if (_taskError != null) ...[
          const SizedBox(height: 4),
          Text(
            _taskError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),

        // Textarea integrado para Notas / Descripción adicional
        TextField(
          controller: _taskDescController,
          maxLines: null,
          minLines: 1,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.35,
          ),
          cursorColor: AppTheme.primaryAccent,
          decoration: InputDecoration(
            hintText: 'Añadir notas o detalles...',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.35),
              fontSize: 13.5,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),

        const SizedBox(height: 16),

        // 2. Fila horizontal de Píldoras de Estado (Status Pills)
        _buildStatusPillsRow(),

        // 3. Bandeja Contextual Inline (Single Inline Tray)
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _buildInlineTray(),
          ),
        ),

        const SizedBox(height: 14),

        // 4. Módulo de Subtareas / Checklist interactivo bajo demanda
        if (_showSubtasks) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorderColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 15,
                          color: AppTheme.primaryAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Subtareas (${_taskChecklist.where((i) => i.completado).length}/${_taskChecklist.length})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: AppTheme.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showSubtasks = false);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SubtaskList(
                  items: _taskChecklist,
                  onChanged: (items) {
                    setState(() => _taskChecklist = items);
                  },
                ),
              ],
            ),
          ),
        ],

        // 5. Pie del modal con botón Guardar y Eliminar
        Row(
          children: [
            if (_isEditingTask && widget.onDeleteTask != null) ...[
              OutlinedButton(
                onPressed: _confirmDeleteTask,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: BorderSide(
                    color: AppTheme.accentCoral.withOpacity(0.5),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: AppTheme.accentCoral,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.accentCoral),
                    const SizedBox(width: 6),
                    Text(
                      'Eliminar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentCoral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditingTask ? 'Actualizar Tarea' : 'Guardar Tarea',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Píldoras de Estado (Horizontal Status Pills)
  // ===========================================================================

  Widget _buildStatusPillsRow() {
    // 1. Label de Fecha y Momento
    final dateLabel = _formatDateShort(_taskDate);
    final timeMap = {
      'anytime': 'Cualquier momento',
      'morning': 'Mañana',
      'afternoon': 'Tarde',
      'night': 'Noche',
    };
    final timeLabel = timeMap[_selectedTimeOfDay] ?? 'Cualquier momento';
    final dateAndTimeString = '$dateLabel · $timeLabel';

    // 2. Label de Responsable
    String assigneeLabel = 'Sin asignar';
    if (_assignedTo != null) {
      final found = widget.miembros.where((m) => m.userId == _assignedTo);
      if (found.isNotEmpty) {
        assigneeLabel = found.first.username;
      }
    }

    // 3. Label de Duración
    final durationLabel = _selectedDurationMinutes > 0
        ? '$_selectedDurationMinutes min'
        : 'Sin tiempo';

    // 4. Label de Proyecto
    String projectLabel = 'Sin proyecto';
    if (_selectedProyectoId != null) {
      final found = widget.proyectos.where((p) => p.id == _selectedProyectoId);
      if (found.isNotEmpty) {
        projectLabel = found.first.nombre;
      }
    }

    // 5. Label de Recurrencia
    final recMap = {
      'none': 'No se repite',
      'daily': 'Diaria',
      'weekly': 'Semanal',
      'monthly': 'Mensual',
    };
    final recLabel = recMap[_recurrenceMode] ?? 'No se repite';

    // 6. Label de Recordatorios
    final remLabel = _selectedReminderOffsets.isEmpty
        ? 'Sin avisos'
        : '${_selectedReminderOffsets.length} aviso${_selectedReminderOffsets.length > 1 ? 's' : ''}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Píldora 1: Fecha y Momento
          _buildPillItem(
            label: dateAndTimeString,
            icon: Icons.calendar_today_rounded,
            isActive: _activeSelector == ActiveTaskSelector.dateAndTime,
            isConfigured: !_isToday(_taskDate) || _selectedTimeOfDay != 'anytime',
            onTap: () => _toggleSelector(ActiveTaskSelector.dateAndTime),
          ),
          const SizedBox(width: 6),

          // Píldora 2: Responsable
          _buildPillItem(
            label: assigneeLabel,
            icon: Icons.person_outline_rounded,
            isActive: _activeSelector == ActiveTaskSelector.assignee,
            isConfigured: _assignedTo != null,
            onTap: () => _toggleSelector(ActiveTaskSelector.assignee),
          ),
          const SizedBox(width: 6),

          // Píldora 3: Duración
          _buildPillItem(
            label: durationLabel,
            icon: Icons.bolt_rounded,
            isActive: _activeSelector == ActiveTaskSelector.duration,
            isConfigured: _selectedDurationMinutes > 0,
            onTap: () => _toggleSelector(ActiveTaskSelector.duration),
          ),
          const SizedBox(width: 6),

          // Píldora 4: Proyecto (solo si hay proyectos)
          if (widget.proyectos.isNotEmpty) ...[
            _buildPillItem(
              label: projectLabel,
              icon: Icons.folder_outlined,
              isActive: _activeSelector == ActiveTaskSelector.project,
              isConfigured: _selectedProyectoId != null,
              onTap: () => _toggleSelector(ActiveTaskSelector.project),
            ),
            const SizedBox(width: 6),
          ],

          // Píldora 5: Recurrencia
          _buildPillItem(
            label: recLabel,
            icon: Icons.repeat_rounded,
            isActive: _activeSelector == ActiveTaskSelector.recurrence,
            isConfigured: _recurrenceMode != 'none',
            onTap: () => _toggleSelector(ActiveTaskSelector.recurrence),
          ),
          const SizedBox(width: 6),

          // Píldora 6: Recordatorios relativos
          _buildPillItem(
            label: remLabel,
            icon: _selectedReminderOffsets.isNotEmpty
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            isActive: _activeSelector == ActiveTaskSelector.reminders,
            isConfigured: _selectedReminderOffsets.isNotEmpty,
            onTap: () => _toggleSelector(ActiveTaskSelector.reminders),
          ),
          const SizedBox(width: 6),

          // Píldora 7: Subtareas / Checklist (+ Subtareas)
          _buildPillItem(
            label: _taskChecklist.isNotEmpty ? '${_taskChecklist.length} subtareas' : '+ Subtareas',
            icon: Icons.add_task_rounded,
            isActive: _showSubtasks,
            isConfigured: _taskChecklist.isNotEmpty,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _showSubtasks = !_showSubtasks;
                _activeSelector = ActiveTaskSelector.none;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isConfigured,
    required VoidCallback onTap,
  }) {
    final effectiveColor = isActive
        ? AppTheme.primaryAccent
        : (isConfigured ? AppTheme.primaryAccent.withOpacity(0.9) : AppTheme.textSecondary);

    final bgColor = isActive
        ? AppTheme.primaryAccent.withOpacity(0.2)
        : (isConfigured
            ? AppTheme.primaryAccent.withOpacity(0.1)
            : AppTheme.darkBackground);

    final borderColor = isActive
        ? AppTheme.primaryAccent
        : (isConfigured
            ? AppTheme.primaryAccent.withOpacity(0.35)
            : AppTheme.cardBorderColor.withOpacity(0.18));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: effectiveColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isConfigured || isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? AppTheme.primaryAccent
                    : (isConfigured ? AppTheme.textPrimary : AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Bandeja Contextual Inline (Single Inline Tray)
  // ===========================================================================

  Widget _buildInlineTray() {
    if (_activeSelector == ActiveTaskSelector.none) {
      return const SizedBox.shrink();
    }

    Widget content;
    switch (_activeSelector) {
      case ActiveTaskSelector.dateAndTime:
        content = _buildDateAndTimeTrayContent();
        break;
      case ActiveTaskSelector.assignee:
        content = _buildAssigneeTrayContent();
        break;
      case ActiveTaskSelector.duration:
        content = _buildDurationTrayContent();
        break;
      case ActiveTaskSelector.project:
        content = _buildProjectTrayContent();
        break;
      case ActiveTaskSelector.recurrence:
        content = _buildRecurrenceTrayContent();
        break;
      case ActiveTaskSelector.reminders:
        content = _buildRemindersTrayContent();
        break;
      case ActiveTaskSelector.none:
        content = const SizedBox.shrink();
        break;
    }

    return Container(
      key: ValueKey('inline_tray_${_activeSelector.name}'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryAccent.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: content,
    );
  }

  // Contenido de la bandeja: Fecha y Momento del día
  Widget _buildDateAndTimeTrayContent() {
    final isTodaySelected = _isToday(_taskDate);
    final isTomorrowSelected = _formatDateShort(_taskDate) == 'Mañana';

    final timeOptions = [
      {'key': 'anytime', 'label': 'Cualquier momento', 'icon': Icons.all_inclusive_rounded},
      {'key': 'morning', 'label': 'Mañana', 'icon': Icons.wb_sunny_outlined},
      {'key': 'afternoon', 'label': 'Tarde', 'icon': Icons.wb_twilight_rounded},
      {'key': 'night', 'label': 'Noche', 'icon': Icons.nightlight_outlined},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila 1: Accesos rápidos de fecha
        Row(
          children: [
            _buildTrayChip(
              label: 'Hoy',
              isSelected: isTodaySelected,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _taskDate = DateTime.now());
              },
            ),
            const SizedBox(width: 6),
            _buildTrayChip(
              label: 'Mañana',
              isSelected: isTomorrowSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _taskDate = DateTime.now().add(const Duration(days: 1)));
              },
            ),
            const SizedBox(width: 6),
            _buildTrayChip(
              label: !isTodaySelected && !isTomorrowSelected
                  ? _formatDateShort(_taskDate)
                  : 'Elegir fecha...',
              isSelected: !isTodaySelected && !isTomorrowSelected,
              onTap: () => _pickDate(forTask: true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, thickness: 1, color: Colors.white10),
        const SizedBox(height: 10),

        // Fila 2: Chips de momento del día
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: timeOptions.map((opt) {
              final isSel = _selectedTimeOfDay == opt['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: _buildTrayChip(
                  label: opt['label'] as String,
                  icon: opt['icon'] as IconData,
                  isSelected: isSel,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedTimeOfDay = opt['key'] as String;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Contenido de la bandeja: Responsable asignado
  Widget _buildAssigneeTrayContent() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTrayChip(
            label: 'Sin asignar',
            isSelected: _assignedTo == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _assignedTo = null;
                _activeSelector = ActiveTaskSelector.none;
              });
            },
          ),
          const SizedBox(width: 6),
          ...widget.miembros.map((m) {
            final isSel = _assignedTo == m.userId;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _buildTrayChip(
                label: m.username,
                avatar: m.avatarData != null
                    ? UserAvatar(
                        avatarData: m.avatarData,
                        username: m.username,
                        size: 18,
                        showBorder: false,
                      )
                    : null,
                isSelected: isSel,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _assignedTo = m.userId;
                    _activeSelector = ActiveTaskSelector.none;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // Contenido de la bandeja: Duración estimada
  Widget _buildDurationTrayContent() {
    final options = [
      {'label': 'Rápida (15 min)', 'minutes': 15, 'icon': Icons.bolt_rounded},
      {'label': 'Media (30 min)', 'minutes': 30, 'icon': Icons.hourglass_top_rounded},
      {'label': 'Larga (60 min)', 'minutes': 60, 'icon': Icons.hourglass_full_rounded},
      {'label': 'Sin tiempo (0 min)', 'minutes': 0, 'icon': Icons.timelapse_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final mins = opt['minutes'] as int;
          final isSel = _selectedDurationMinutes == mins;

          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: _buildTrayChip(
              label: opt['label'] as String,
              icon: opt['icon'] as IconData,
              isSelected: isSel,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDurationMinutes = mins;
                  _activeSelector = ActiveTaskSelector.none;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Contenido de la bandeja: Proyectos
  Widget _buildProjectTrayContent() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTrayChip(
            label: 'Sin proyecto',
            isSelected: _selectedProyectoId == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedProyectoId = null;
                _activeSelector = ActiveTaskSelector.none;
              });
            },
          ),
          const SizedBox(width: 6),
          ...widget.proyectos.map((p) {
            final isSel = _selectedProyectoId == p.id;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: _buildTrayChip(
                label: p.nombre,
                isSelected: isSel,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedProyectoId = p.id;
                    _activeSelector = ActiveTaskSelector.none;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // Contenido de la bandeja: Recurrencia
  Widget _buildRecurrenceTrayContent() {
    const recurrenceOptions = [
      {'key': 'none', 'label': 'No se repite'},
      {'key': 'daily', 'label': 'Diaria'},
      {'key': 'weekly', 'label': 'Semanal'},
      {'key': 'monthly', 'label': 'Mensual'},
    ];

    final isRecurring = _recurrenceMode != 'none';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: recurrenceOptions.map((opt) {
              final isSel = _recurrenceMode == opt['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: _buildTrayChip(
                  label: opt['label']!,
                  isSelected: isSel,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _recurrenceMode = opt['key']!;
                      if (_recurrenceMode == 'none') {
                        _autoRotateAssignee = false;
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (isRecurring && widget.miembros.length > 1) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sync_rounded,
                    size: 15,
                    color: _autoRotateAssignee
                        ? AppTheme.primaryAccent
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rotar responsable automáticamente',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _autoRotateAssignee,
                activeColor: AppTheme.primaryAccent,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _autoRotateAssignee = val);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Contenido de la bandeja: Recordatorios
  Widget _buildRemindersTrayContent() {
    final reminderOptions = [
      {'days': 1, 'label': '1 día antes'},
      {'days': 3, 'label': '3 días antes'},
      {'days': 7, 'label': '1 semana antes'},
    ];

    return Row(
      children: reminderOptions.map((opt) {
        final days = opt['days'] as int;
        final isSel = _selectedReminderOffsets.contains(days);

        return Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: _buildTrayChip(
            label: opt['label'] as String,
            icon: isSel
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            isSelected: isSel,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isSel) {
                  _selectedReminderOffsets.remove(days);
                } else {
                  _selectedReminderOffsets.add(days);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrayChip({
    required String label,
    IconData? icon,
    Widget? avatar,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAccent.withOpacity(0.2)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryAccent
                : AppTheme.cardBorderColor.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar,
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? AppTheme.primaryAccent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryAccent : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Confirmación de Eliminación
  // ===========================================================================

  void _confirmDeleteTask() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar Tarea',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar esta tarea?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              widget.onDeleteTask?.call();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Formulario: Evento / Cita / Cumpleaños
  // ===========================================================================

  Widget _buildEventForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tipo de evento (General vs Cumpleaños)
        Row(
          children: [
            Expanded(
              child: _buildChipTag(
                label: 'Cita / Evento General',
                isSelected: _eventType == 'evento_general',
                onTap: () => setState(() => _eventType = 'evento_general'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChipTag(
                label: '🎂 Cumpleaños',
                isSelected: _eventType == 'cumpleanos',
                onTap: () => setState(() => _eventType = 'cumpleanos'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Título del evento
        Text(
          _eventType == 'cumpleanos'
              ? 'Persona que cumple años'
              : 'Título del evento',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _eventTitleController,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: _eventType == 'cumpleanos'
                ? 'Ej. Lucas, Mamá, Juan...'
                : 'Ej. Médico 10:30, Cena familiar...',
            hintStyle:
                TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AppTheme.primaryAccent, width: 1.5),
            ),
          ),
        ),
        if (_eventError != null) ...[
          const SizedBox(height: 6),
          Text(
            _eventError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],

        const SizedBox(height: 14),

        // Fecha y conmutador "Todo el día"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => _pickDate(forTask: false),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.cardBorderColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppTheme.primaryAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDateShort(_eventDate),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'Todo el día',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Switch.adaptive(
                  value: _isAllDay,
                  activeColor: AppTheme.primaryAccent,
                  onChanged: (val) => setState(() => _isAllDay = val),
                ),
              ],
            ),
          ],
        ),

        // Selector de hora si no es todo el día
        if (!_isAllDay) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hora inicio',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickStartTime,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.cardBorderColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _startTime.format(context),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hora fin (opcional)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickEndTime,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.cardBorderColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _endTime?.format(context) ?? '—',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _endTime != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Selector rápido de Recordatorio
        Text(
          'Recordatorio previo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildReminderChip(
                label: 'Sin aviso',
                minutes: null,
              ),
              const SizedBox(width: 6),
              _buildReminderChip(
                label: '15 min antes',
                minutes: 15,
              ),
              const SizedBox(width: 6),
              _buildReminderChip(
                label: '1 hora antes',
                minutes: 60,
              ),
              const SizedBox(width: 6),
              _buildReminderChip(
                label: '1 día antes',
                minutes: 1440,
              ),
            ],
          ),
        ),

        // Apartado especial para Cumpleaños: Ideas de Regalo (Draggable & Editable)
        if (_eventType == 'cumpleanos') ...[
          const SizedBox(height: 18),
          _buildBirthdayGiftIdeasSection(),
        ],

        const SizedBox(height: 24),

        // Botón principal de guardado de evento
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: _eventType == 'cumpleanos'
                  ? AppTheme.accentCoral
                  : AppTheme.primaryAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _eventType == 'cumpleanos'
                        ? 'Guardar Cumpleaños'
                        : 'Guardar Evento',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Ideas de Regalo para Cumpleaños (Draggable & Editable)
  // ===========================================================================

  Widget _buildBirthdayGiftIdeasSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.cardBorderColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                size: 16,
                color: AppTheme.accentCoral,
              ),
              const SizedBox(width: 8),
              Text(
                'Ideas de Regalo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_ideasRegaloList.isNotEmpty)
                Text(
                  '${_ideasRegaloList.length} ideas',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Campo para agregar nueva idea
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _giftIdeaInputController,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ej. Libro de cocina, zapatillas...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppTheme.cardBorderColor.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppTheme.cardBorderColor.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppTheme.accentCoral, width: 1.2),
                    ),
                  ),
                  onSubmitted: (_) => _addGiftIdea(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _addGiftIdea,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCoral.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentCoral, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 16, color: AppTheme.accentCoral),
                      const SizedBox(width: 4),
                      Text(
                        'Añadir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCoral,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_ideasRegaloList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Añade ideas de regalo para recordar qué regalar y ordénalas arrastrando.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ideasRegaloList.length,
              onReorder: (oldIndex, newIndex) {
                HapticFeedback.mediumImpact();
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _ideasRegaloList.removeAt(oldIndex);
                  _ideasRegaloList.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final idea = _ideasRegaloList[index];
                return Container(
                  key: ValueKey('gift_idea_${index}_$idea'),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.cardBorderColor.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: AppTheme.textSecondary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          idea,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _editGiftIdea(index, idea),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _ideasRegaloList.removeAt(index));
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: AppTheme.accentCoral,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _addGiftIdea() {
    final text = _giftIdeaInputController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _ideasRegaloList.add(text);
      _giftIdeaInputController.clear();
    });
  }

  Future<void> _editGiftIdea(int index, String currentText) async {
    final controller = TextEditingController(text: currentText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar idea de regalo',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Idea de regalo...',
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _ideasRegaloList[index] = result.trim();
      });
    }
  }

  Widget _buildChipTag({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAccent.withOpacity(0.15)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryAccent
                : AppTheme.cardBorderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryAccent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderChip({
    required String label,
    required int? minutes,
  }) {
    final isSelected = _reminderMinutesBefore == minutes;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _reminderMinutesBefore = minutes);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAccent.withOpacity(0.15)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryAccent
                : AppTheme.cardBorderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryAccent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
