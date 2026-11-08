import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/recordatorio_tarea_model.dart';
import '../../domain/models/recurrence_rule.dart';
import 'recordatorios_selector_widget.dart';
import 'subtask_list.dart';
import 'tiempo_estimado_selector.dart';

/// Niveles de prioridad disponibles para las tareas
enum TaskPriorityLevel {
  baja('Baja', Icons.keyboard_double_arrow_down_rounded, Color(0xFF10B981)),
  media('Media', Icons.drag_handle_rounded, Color(0xFF38BDF8)),
  alta('Alta', Icons.keyboard_double_arrow_up_rounded, Color(0xFFF59E0B)),
  urgente('Urgente', Icons.priority_high_rounded, Color(0xFFEF4444));

  final String label;
  final IconData icon;
  final Color color;

  const TaskPriorityLevel(this.label, this.icon, this.color);
}

/// Modal unificado de creación (Tarea / Evento / Cumpleaños) con estética Flat Design 2.0:
/// - Selector de tipo en cabecera: [ Tarea ] | [ Evento / Cita ]
/// - Selector de tiempo estimado con dropdowns configurables (1-60 y Minutos/Horas).
/// - Prioridad con selector visual por chips / segmented control.
/// - Opciones avanzadas completas:
///   * Prioridad
///   * Recurrencia / Repetición (No se repite, Diaria, Semanal, Mensual, Días específicos)
///   * Taxonomía / Etiquetas temáticas del hogar
///   * Notas / Descripción adicional
///   * Recordatorios y Alertas configurables
///   * Subtareas / Checklist interactivo
/// - Apartado especial para Cumpleaños con lista de regalos Drag & Drop y editable.
class FlatCreateItemSheet extends StatefulWidget {
  final DateTime defaultDate;
  final List<EnvironmentMemberModel> miembros;
  final String? currentUserId;
  final List<ProyectoModel> proyectos;
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
    required this.onCreateTask,
    required this.onCreateEvent,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime defaultDate,
    required List<EnvironmentMemberModel> miembros,
    String? currentUserId,
    List<ProyectoModel> proyectos = const [],
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

  // Estado Tarea: Campos Básicos
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescController = TextEditingController();
  late DateTime _taskDate;
  String? _assignedTo;
  int _selectedMinutes = 15;
  String? _selectedProyectoId;
  String? _taskError;

  // Estado Tarea: Prioridad
  TaskPriorityLevel _selectedPriority = TaskPriorityLevel.media;

  // Estado Tarea: Etiquetas temáticas del hogar
  static const List<String> _etiquetasSugeridas = [
    'Limpieza',
    'Cocina',
    'Compras',
    'Mantenimiento',
    'Mascotas',
    'Organización',
    'Facturas',
  ];
  String? _selectedEtiqueta;
  final TextEditingController _customTagController = TextEditingController();
  bool _isAddingCustomTag = false;

  // Estado Tarea: Recurrencia / Repetición
  // 'none' | 'daily' | 'weekly' | 'monthly' | 'specific_days'
  String _recurrenceMode = 'none';
  int _recurrenceInterval = 1;
  final Set<int> _selectedDaysOfWeek = {}; // 1 = Lun, 7 = Dom

  // Estado Tarea: Checklist & Recordatorios
  List<ChecklistItemModel> _taskChecklist = [];
  List<RecordatorioTareaModel> _taskRecordatorios = [];
  bool _showAdvancedTaskOptions = false;

  // Estado Evento
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

  @override
  void initState() {
    super.initState();
    _taskDate = widget.defaultDate;
    _eventDate = widget.defaultDate;
    _assignedTo = widget.currentUserId;
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskDescController.dispose();
    _customTagController.dispose();
    _eventTitleController.dispose();
    _giftIdeaInputController.dispose();
    super.dispose();
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
      initialTime: _endTime ?? TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute),
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

  /// Compone la descripción enriquecida respetando el protocolo de almacenamiento:
  /// Prioridad [p:alta], Etiqueta [tag:Limpieza], Recurrencia [rrule:...] y notas libres.
  String? _composeTaskDescription() {
    final buffer = StringBuffer();

    // Etiqueta
    if (_selectedEtiqueta != null && _selectedEtiqueta!.trim().isNotEmpty) {
      buffer.write('[tag:${_selectedEtiqueta!.trim()}] ');
    }

    // Prioridad
    buffer.write('[priority:${_selectedPriority.name}] ');

    // Recurrencia
    if (_recurrenceMode != 'none') {
      final rrule = _buildRecurrenceRuleString();
      if (rrule != null) {
        buffer.write('[rrule:$rrule] ');
      }
    }

    // Texto descriptivo adicional
    final userNotes = _taskDescController.text.trim();
    if (userNotes.isNotEmpty) {
      buffer.write(userNotes);
    }

    final result = buffer.toString().trim();
    return result.isNotEmpty ? result : null;
  }

  String? _buildRecurrenceRuleString() {
    switch (_recurrenceMode) {
      case 'daily':
        return 'FREQ=DAILY;INTERVAL=$_recurrenceInterval';
      case 'weekly':
        return 'FREQ=WEEKLY;INTERVAL=$_recurrenceInterval';
      case 'monthly':
        return 'FREQ=MONTHLY;INTERVAL=$_recurrenceInterval';
      case 'specific_days':
        if (_selectedDaysOfWeek.isEmpty) {
          return 'FREQ=WEEKLY;INTERVAL=1';
        }
        final days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
        final byDays = _selectedDaysOfWeek.map((d) => days[d - 1]).join(',');
        return 'FREQ=WEEKLY;BYDAY=$byDays';
      default:
        return null;
    }
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
      await widget.onCreateTask(
        titulo: title,
        fechaLimite: _taskDate,
        asignadoA: _assignedTo,
        tiempoEstimadoMinutos: _selectedMinutes,
        proyectoId: _selectedProyectoId,
        descripcion: desc,
        checklist: _taskChecklist,
        recordatorios: _taskRecordatorios,
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
        final notifTime = startDateTime.subtract(Duration(minutes: _reminderMinutesBefore!));
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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

              // Selector plano de tipo [ Tarea ] | [ Evento ]
              _buildTypeSelector(),
              const SizedBox(height: 18),

              // Formulario según tipo
              if (_selectedTypeIndex == 0) _buildTaskForm() else _buildEventForm(),
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
  // Formulario: Tarea
  // ===========================================================================

  Widget _buildTaskForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Text(
          'Título de la tarea',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _taskTitleController,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ej. Limpiar la cocina o fregar platos...',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryAccent, width: 1.5),
            ),
          ),
        ),
        if (_taskError != null) ...[
          const SizedBox(height: 6),
          Text(
            _taskError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],

        const SizedBox(height: 16),

        // Fecha de ejecución
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fecha programada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            InkWell(
              onTap: () => _pickDate(forTask: true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      _formatDateShort(_taskDate),
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
          ],
        ),

        const SizedBox(height: 16),

        // Selector de Responsable (Convivientes)
        Text(
          'Responsable asignado',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _buildAssigneeSelector(),

        const SizedBox(height: 16),

        // Selector de Tiempo Estimado configurable con dos desplegables (número 1-60 y unidad Minutos/Horas)
        TiempoEstimadoSelector(
          initialMinutes: _selectedMinutes,
          onChanged: (mins) {
            setState(() => _selectedMinutes = mins);
          },
        ),

        // Selector de Proyecto opcional
        if (widget.proyectos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Proyecto (opcional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildProjectSelector(),
        ],

        const SizedBox(height: 16),

        // Acordeón / Desplegable Flat 2.0 de Opciones Avanzadas
        _buildAdvancedTaskOptions(),

        const SizedBox(height: 24),

        // Botón principal de guardado
        SizedBox(
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
                : const Text(
                    'Guardar Tarea',
                    style: TextStyle(
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
  // Opciones Avanzadas de Tarea
  // ===========================================================================

  Widget _buildAdvancedTaskOptions() {
    final totalConfigurados = (_selectedEtiqueta != null ? 1 : 0) +
        (_recurrenceMode != 'none' ? 1 : 0) +
        (_selectedPriority != TaskPriorityLevel.media ? 1 : 0) +
        _taskRecordatorios.length +
        _taskChecklist.length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.cardBorderColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showAdvancedTaskOptions = !_showAdvancedTaskOptions);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: AppTheme.primaryAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Opciones avanzadas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (totalConfigurados > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$totalConfigurados config.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryAccent,
                        ),
                      ),
                    ),
                  Icon(
                    _showAdvancedTaskOptions
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvancedTaskOptions) ...[
            const Divider(height: 1, thickness: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Prioridad
                  _buildPrioritySelector(),
                  const SizedBox(height: 16),

                  // 2. Recurrencia / Repetición
                  _buildRecurrenceSelector(),
                  const SizedBox(height: 16),

                  // 3. Taxonomía / Etiquetas del hogar
                  _buildTagsSelector(),
                  const SizedBox(height: 16),

                  // 4. Notas / Descripción adicional
                  Text(
                    'Notas / Descripción adicional',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _taskDescController,
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Detalles u observaciones...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryAccent, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Recordatorios y Alertas configurables
                  RecordatoriosSelectorWidget(
                    recordatoriosIniciales: _taskRecordatorios,
                    fechaLimite: _taskDate,
                    onChanged: (recs) {
                      setState(() => _taskRecordatorios = recs);
                    },
                  ),
                  const SizedBox(height: 16),

                  // 6. Subtareas / Checklist interactivo
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
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. Selector de Prioridad
  // ===========================================================================

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Prioridad',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _selectedPriority.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _selectedPriority.color.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Text(
                _selectedPriority.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _selectedPriority.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.cardBorderColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: TaskPriorityLevel.values.map((priority) {
              final isSelected = _selectedPriority == priority;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPriority = priority);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? priority.color.withOpacity(0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? priority.color
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          priority.icon,
                          size: 13,
                          color: isSelected ? priority.color : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          priority.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? priority.color : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. Selector de Recurrencia / Repetición
  // ===========================================================================

  Widget _buildRecurrenceSelector() {
    const recurrenceOptions = [
      {'key': 'none', 'label': 'No se repite'},
      {'key': 'daily', 'label': 'Diaria'},
      {'key': 'weekly', 'label': 'Semanal'},
      {'key': 'monthly', 'label': 'Mensual'},
      {'key': 'specific_days', 'label': 'Días específicos'},
    ];

    final diasSemanaNombres = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repetición / Recurrencia',
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
            children: recurrenceOptions.map((opt) {
              final isSel = _recurrenceMode == opt['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _recurrenceMode = opt['key']!);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppTheme.primaryAccent.withOpacity(0.18)
                          : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel
                            ? AppTheme.primaryAccent
                            : AppTheme.cardBorderColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      opt['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel ? AppTheme.primaryAccent : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Configuración condicional: Intervalo (Diaria / Semanal / Mensual)
        if (_recurrenceMode == 'daily' ||
            _recurrenceMode == 'weekly' ||
            _recurrenceMode == 'monthly') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.cardBorderColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _recurrenceMode == 'daily'
                      ? 'Repetir cada (días):'
                      : _recurrenceMode == 'weekly'
                          ? 'Repetir cada (semanas):'
                          : 'Repetir cada (meses):',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                      color: _recurrenceInterval > 1
                          ? AppTheme.primaryAccent
                          : AppTheme.textSecondary.withOpacity(0.3),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _recurrenceInterval > 1
                          ? () => setState(() => _recurrenceInterval -= 1)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '$_recurrenceInterval',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      color: AppTheme.primaryAccent,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _recurrenceInterval += 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Configuración condicional: Selección de días específicos
        if (_recurrenceMode == 'specific_days') ...[
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (index) {
              final dayNum = index + 1; // 1 = Lun, 7 = Dom
              final isDaySelected = _selectedDaysOfWeek.contains(dayNum);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isDaySelected) {
                          _selectedDaysOfWeek.remove(dayNum);
                        } else {
                          _selectedDaysOfWeek.add(dayNum);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isDaySelected
                            ? AppTheme.primaryAccent.withOpacity(0.2)
                            : AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDaySelected
                              ? AppTheme.primaryAccent
                              : AppTheme.cardBorderColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          diasSemanaNombres[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isDaySelected ? FontWeight.bold : FontWeight.w600,
                            color: isDaySelected
                                ? AppTheme.primaryAccent
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 3. Selector de Taxonomía / Etiquetas del Hogar
  // ===========================================================================

  Widget _buildTagsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categoría / Etiqueta del hogar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            if (_selectedEtiqueta != null)
              GestureDetector(
                onTap: () => setState(() => _selectedEtiqueta = null),
                child: Text(
                  'Quitar etiqueta',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentCoral,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._etiquetasSugeridas.map((tag) {
                final isSel = _selectedEtiqueta == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: _buildChipTag(
                    label: '#$tag',
                    isSelected: isSel,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedEtiqueta = isSel ? null : tag;
                      });
                    },
                  ),
                );
              }),
              // Botón / Input para tag personalizado
              if (!_isAddingCustomTag)
                InkWell(
                  onTap: () => setState(() => _isAddingCustomTag = true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.cardBorderColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Personalizada...',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 130,
                  height: 32,
                  child: TextField(
                    controller: _customTagController,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Etiqueta...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.5),
                        fontSize: 11,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_rounded, size: 14),
                        color: AppTheme.primaryAccent,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          final val = _customTagController.text.trim().replaceAll('#', '');
                          if (val.isNotEmpty) {
                            setState(() {
                              _selectedEtiqueta = val;
                              _isAddingCustomTag = false;
                              _customTagController.clear();
                            });
                          } else {
                            setState(() => _isAddingCustomTag = false);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      final clean = val.trim().replaceAll('#', '');
                      if (clean.isNotEmpty) {
                        setState(() {
                          _selectedEtiqueta = clean;
                          _isAddingCustomTag = false;
                          _customTagController.clear();
                        });
                      } else {
                        setState(() => _isAddingCustomTag = false);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Opción "Sin asignar"
          _buildAssigneeChip(
            title: 'Sin asignar',
            avatar: null,
            isSelected: _assignedTo == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _assignedTo = null);
            },
          ),
          const SizedBox(width: 8),

          // Convivientes del entorno
          ...widget.miembros.map((m) {
            final isSelected = _assignedTo == m.userId;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildAssigneeChip(
                title: m.username,
                avatar: m.avatarData != null
                    ? UserAvatar(
                        avatarData: m.avatarData,
                        username: m.username,
                        size: 20,
                        showBorder: false,
                      )
                    : null,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _assignedTo = m.userId);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAssigneeChip({
    required String title,
    required Widget? avatar,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryAccent.withOpacity(0.15)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryAccent
                : AppTheme.cardBorderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar,
              const SizedBox(width: 6),
            ] else ...[
              Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: isSelected ? AppTheme.primaryAccent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              title,
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

  Widget _buildProjectSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChipTag(
            label: 'Sin proyecto',
            isSelected: _selectedProyectoId == null,
            onTap: () => setState(() => _selectedProyectoId = null),
          ),
          const SizedBox(width: 8),
          ...widget.proyectos.map((p) {
            final isSel = _selectedProyectoId == p.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildChipTag(
                label: p.nombre,
                isSelected: isSel,
                onTap: () => setState(() => _selectedProyectoId = p.id),
              ),
            );
          }),
        ],
      ),
    );
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
          _eventType == 'cumpleanos' ? 'Persona que cumple años' : 'Título del evento',
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
            hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryAccent, width: 1.5),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    _eventType == 'cumpleanos' ? 'Guardar Cumpleaños' : 'Guardar Evento',
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.cardBorderColor.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.accentCoral, width: 1.2),
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
                      Icon(Icons.add_rounded, size: 16, color: AppTheme.accentCoral),
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

          // Lista reordenable y editable de ideas
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Idea de regalo...',
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
