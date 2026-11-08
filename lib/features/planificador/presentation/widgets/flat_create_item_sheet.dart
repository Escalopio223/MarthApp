import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/recordatorio_tarea_model.dart';

/// Modal unificado de creación (Tarea / Evento) con estética Flat Design 2.0:
/// - Selector de tipo en cabecera: [ Tarea ] | [ Evento ]
/// - Formulario dinámico simplificado y de guardado rápido.
/// - Selector rápido de responsable, tiempo estimado y recordatorios sin anidamientos.
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
  }) onCreateTask;
  final Future<void> Function({
    required String titulo,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    bool esTodoElDia,
    String tipo,
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
    }) onCreateTask,
    required Future<void> Function({
      required String titulo,
      required DateTime fechaInicio,
      DateTime? fechaFin,
      bool esTodoElDia,
      String tipo,
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

  // Estado Tarea
  final TextEditingController _taskTitleController = TextEditingController();
  late DateTime _taskDate;
  String? _assignedTo;
  int _selectedMinutes = 15;
  String? _selectedProyectoId;
  String? _taskError;

  // Estado Evento
  final TextEditingController _eventTitleController = TextEditingController();
  late DateTime _eventDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  String _eventType = 'evento_general'; // 'evento_general' | 'cumpleanos'
  int? _reminderMinutesBefore; // null, 15, 60, 1440
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
    _eventTitleController.dispose();
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
      await widget.onCreateTask(
        titulo: title,
        fechaLimite: _taskDate,
        asignadoA: _assignedTo,
        tiempoEstimadoMinutos: _selectedMinutes,
        proyectoId: _selectedProyectoId,
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

      await widget.onCreateEvent(
        titulo: title,
        fechaInicio: startDateTime,
        fechaFin: endDateTime,
        esTodoElDia: _isAllDay,
        tipo: _eventType,
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

        // Selector de Tiempo Estimado (Chips rápidos: 5m, 15m, 30m, 60m)
        Text(
          'Tiempo estimado',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _buildMinutesChips(),

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

  Widget _buildMinutesChips() {
    const minutesList = [5, 15, 30, 60];

    return Row(
      children: minutesList.map((mins) {
        final isSelected = _selectedMinutes == mins;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedMinutes = mins);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                child: Center(
                  child: Text(
                    '${mins}m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryAccent
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
  // Formulario: Evento / Cita
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
          'Título del evento',
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
            hintText: 'Ej. Médico 10:30, Cumpleaños de Lucas...',
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

