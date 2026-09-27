import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/tarea_model.dart';
import '../../domain/models/task_form_basic_payload.dart';
import 'task_advanced_accordion.dart';

enum _QuickDateChoice { hoy, manana, personalizada, sinFecha }

/// Componente modular, desacoplado y reutilizable para el formulario básico de tareas.
/// Soporta tanto creación (`create`) como edición (`edit`), gestionando el estado de carga,
/// prevención de doble submit, validaciones en tiempo real y tipado estricto.
class TaskFormBasic extends StatefulWidget {
  final TaskFormMode mode;
  final TaskFormBasicPayload? initialPayload;
  final TareaModel? initialTarea;
  final List<EnvironmentMemberModel> miembros;
  final List<ProyectoModel> proyectos;
  final String? usuarioActualId;
  final Future<void> Function(TaskFormBasicPayload payload) onSubmit;
  final VoidCallback? onCancel;
  final String? submitButtonText;
  final String? title;
  final bool isModal;

  const TaskFormBasic({
    super.key,
    this.mode = TaskFormMode.create,
    this.initialPayload,
    this.initialTarea,
    this.miembros = const [],
    this.proyectos = const [],
    this.usuarioActualId,
    required this.onSubmit,
    this.onCancel,
    this.submitButtonText,
    this.title,
    this.isModal = false,
  });

  /// Presenta el formulario dentro de un modal bottom sheet responsive con teclado adaptativo.
  static Future<TaskFormBasicPayload?> showModal(
    BuildContext context, {
    TaskFormMode mode = TaskFormMode.create,
    TaskFormBasicPayload? initialPayload,
    TareaModel? initialTarea,
    required List<EnvironmentMemberModel> miembros,
    List<ProyectoModel> proyectos = const [],
    String? usuarioActualId,
    required Future<void> Function(TaskFormBasicPayload payload) onSubmit,
    String? submitButtonText,
    String? title,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<TaskFormBasicPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: TaskFormBasic(
            mode: mode,
            isModal: true,
            initialPayload: initialPayload,
            initialTarea: initialTarea,
            miembros: miembros,
            proyectos: proyectos,
            usuarioActualId: usuarioActualId,
            submitButtonText: submitButtonText,
            title: title,
            onCancel: () => Navigator.pop(modalContext),
            onSubmit: (payload) async {
              await onSubmit(payload);
              if (modalContext.mounted) {
                Navigator.pop(modalContext, payload);
              }
            },
          ),
        );
      },
    );
  }

  @override
  State<TaskFormBasic> createState() => _TaskFormBasicState();
}

class _TaskFormBasicState extends State<TaskFormBasic> {
  late final TextEditingController _tituloController;
  late final TextEditingController _descripcionController;

  late _QuickDateChoice _quickDateChoice;
  DateTime? _fechaEjecucion;
  bool _tieneHora = false;
  TimeOfDay? _horaEjecucion;

  String? _asignadoAId;
  bool _isRecurring = false;
  late RecurrenceRule _recurrenceRule;

  // Campos avanzados con persistencia al colapsar
  int? _tiempoEstimadoMinutos;
  String? _proyectoId;
  String? _etiqueta;
  late final TextEditingController _notasController;
  List<ChecklistItemModel> _subtasks = [];
  bool _hasReminder = false;
  int? _reminderMinutesBefore = 15;

  bool _isSubmitting = false;
  String? _validationError;
  String? _submitError;

  @override
  void initState() {
    super.initState();

    // 1. Obtener payload base inicial
    final payload = widget.initialPayload ??
        (widget.initialTarea != null
            ? TaskFormBasicPayload.fromTarea(widget.initialTarea!)
            : TaskFormBasicPayload.initialForCreate(
                defaultAssigneeId: widget.usuarioActualId,
              ));

    _tituloController = TextEditingController(text: payload.titulo);
    _descripcionController = TextEditingController(text: payload.descripcion ?? '');

    _asignadoAId = payload.asignadoA;
    _isRecurring = payload.isRecurring;
    _recurrenceRule = payload.recurrenceRule ??
        RecurrenceRule.weekly(
          daysOfWeek: [DateTime.now().weekday],
        );
    _fechaEjecucion = payload.fechaEjecucion;
    _tieneHora = payload.tieneHora;

    // Inicializar campos avanzados desde payload inicial
    _tiempoEstimadoMinutos = payload.tiempoEstimadoMinutos;
    _proyectoId = payload.proyectoId;
    _etiqueta = payload.etiqueta;
    _notasController = TextEditingController(text: payload.notas ?? '');
    _subtasks = List<ChecklistItemModel>.from(payload.subtasks);
    _hasReminder = payload.hasReminder;
    _reminderMinutesBefore = payload.reminderMinutesBefore ?? 15;

    if (_fechaEjecucion != null && _tieneHora) {
      _horaEjecucion = TimeOfDay(
        hour: _fechaEjecucion!.hour,
        minute: _fechaEjecucion!.minute,
      );
    }

    _determinarOpcionFechaInicial();
  }

  void _determinarOpcionFechaInicial() {
    if (_fechaEjecucion == null) {
      _quickDateChoice = _QuickDateChoice.sinFecha;
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final f = DateTime(
      _fechaEjecucion!.year,
      _fechaEjecucion!.month,
      _fechaEjecucion!.day,
    );

    if (f.isAtSameMomentAs(today)) {
      _quickDateChoice = _QuickDateChoice.hoy;
    } else if (f.isAtSameMomentAs(tomorrow)) {
      _quickDateChoice = _QuickDateChoice.manana;
    } else {
      _quickDateChoice = _QuickDateChoice.personalizada;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _onTituloChanged(String val) {
    if (_validationError != null && val.trim().isNotEmpty) {
      setState(() => _validationError = null);
    }
    if (_submitError != null) {
      setState(() => _submitError = null);
    }
  }

  void _selectQuickDate(_QuickDateChoice choice) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _quickDateChoice = choice;
      switch (choice) {
        case _QuickDateChoice.hoy:
          _fechaEjecucion = today;
          break;
        case _QuickDateChoice.manana:
          _fechaEjecucion = today.add(const Duration(days: 1));
          break;
        case _QuickDateChoice.sinFecha:
          _fechaEjecucion = null;
          _tieneHora = false;
          _horaEjecucion = null;
          break;
        case _QuickDateChoice.personalizada:
          // Se maneja a través del date picker
          break;
      }
    });
  }

  Future<void> _abrirSelectorFechaPersonalizada() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final initial = _fechaEjecucion ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryLiquid,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppTheme.surfaceDark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaEjecucion = DateTime(picked.year, picked.month, picked.day);
        _determinarOpcionFechaInicial();
      });
    }
  }

  Future<void> _abrirSelectorHora() async {
    HapticFeedback.selectionClick();
    final initialTime = _horaEjecucion ?? const TimeOfDay(hour: 12, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryLiquid,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.surfaceDark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _horaEjecucion = picked;
        _tieneHora = true;
        // Si no había fecha definida, asignar hoy por defecto
        if (_fechaEjecucion == null) {
          final now = DateTime.now();
          _fechaEjecucion = DateTime(now.year, now.month, now.day);
          _determinarOpcionFechaInicial();
        }
      });
    }
  }

  void _limpiarHora() {
    HapticFeedback.selectionClick();
    setState(() {
      _tieneHora = false;
      _horaEjecucion = null;
    });
  }

  Future<void> _handleSubmit() async {
    // 1. Prevención estricta de envío duplicado
    if (_isSubmitting) return;

    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _validationError = 'El título de la tarea es obligatorio.';
      });
      return;
    }

    setState(() {
      _validationError = null;
      _submitError = null;
      _isSubmitting = true;
    });

    HapticFeedback.mediumImpact();

    // 2. Construir fecha definitiva (combinando fecha y hora opcional)
    DateTime? fechaFinal = _fechaEjecucion;
    if (fechaFinal != null && _tieneHora && _horaEjecucion != null) {
      fechaFinal = DateTime(
        fechaFinal.year,
        fechaFinal.month,
        fechaFinal.day,
        _horaEjecucion!.hour,
        _horaEjecucion!.minute,
      );
    }

    final payload = TaskFormBasicPayload(
      titulo: titulo,
      descripcion: _descripcionController.text.trim().isNotEmpty
          ? _descripcionController.text.trim()
          : null,
      fechaEjecucion: fechaFinal,
      tieneHora: _tieneHora && fechaFinal != null,
      asignadoA: _asignadoAId,
      isRecurring: _isRecurring,
      recurrenceRule: _isRecurring ? _recurrenceRule : null,
      tiempoEstimadoMinutos: _tiempoEstimadoMinutos,
      proyectoId: _proyectoId,
      etiqueta: _etiqueta,
      notas: _notasController.text.trim().isNotEmpty
          ? _notasController.text.trim()
          : null,
      subtasks: _subtasks,
      hasReminder: _hasReminder,
      reminderMinutesBefore: _hasReminder ? _reminderMinutesBefore : null,
    );

    // 3. Validación de contrato del payload
    final contractError = payload.validate();
    if (contractError != null) {
      setState(() {
        _validationError = contractError;
        _isSubmitting = false;
      });
      return;
    }

    // 4. Emisión al componente padre o servicio
    try {
      await widget.onSubmit(payload);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = 'No se pudo guardar la tarea: $e';
          _isSubmitting = false;
        });
      }
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode.isCreate;
    final defaultTitle = isCreate ? 'Nueva tarea' : 'Editar tarea';
    final effectiveTitle = widget.title ?? defaultTitle;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tirador decorativo táctil superior si es modal
            if (widget.isModal) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Cabecera ligera y limpia: Icono minimalista, Título y botón cerrar
            _buildHeader(effectiveTitle, isCreate),
            const SizedBox(height: 14),

            // Banner visual de error de validación o submit
            if (_validationError != null || _submitError != null) ...[
              _buildErrorBanner(_validationError ?? _submitError!),
              const SizedBox(height: 12),
            ],

            // Inputs principales: Nombre de la tarea y Comentario/Descripción
            _buildTituloInput(),
            const SizedBox(height: 10),
            _buildDescripcionInput(),
            const SizedBox(height: 14),

            // Selector compacto de fecha y hora
            _buildFechaYHoraSection(),
            const SizedBox(height: 14),

            // Selector compacto de asignación a miembros del entorno
            _buildAsignacionSection(),
            const SizedBox(height: 14),

            // Opciones avanzadas (Acordeón colapsable con persistencia total de inputs)
            TaskAdvancedAccordion(
              initiallyExpanded: false,
              tiempoEstimadoMinutos: _tiempoEstimadoMinutos,
              onTiempoEstimadoChanged: (val) {
                setState(() => _tiempoEstimadoMinutos = val);
              },
              proyectos: widget.proyectos,
              proyectoId: _proyectoId,
              onProyectoChanged: (val) {
                setState(() => _proyectoId = val);
              },
              etiqueta: _etiqueta,
              onEtiquetaChanged: (val) {
                setState(() => _etiqueta = val);
              },
              notasController: _notasController,
              subtasks: _subtasks,
              onSubtasksChanged: (val) {
                setState(() => _subtasks = val);
              },
              isRecurring: _isRecurring,
              onIsRecurringChanged: (val) {
                setState(() => _isRecurring = val);
              },
              recurrenceRule: _recurrenceRule,
              onRecurrenceRuleChanged: (rule) {
                setState(() => _recurrenceRule = rule);
              },
              hasReminder: _hasReminder,
              onHasReminderChanged: (val) {
                setState(() => _hasReminder = val);
              },
              reminderMinutesBefore: _reminderMinutesBefore,
              onReminderMinutesChanged: (val) {
                setState(() => _reminderMinutesBefore = val);
              },
            ),
            const SizedBox(height: 18),

            // Botón de acción principal
            _buildSubmitButton(isCreate),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, bool isCreate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCreate ? Icons.add_task_rounded : Icons.edit_note_rounded,
                color: AppTheme.primaryLiquid,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        if (widget.onCancel != null)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Cerrar',
            onPressed: _isSubmitting ? null : widget.onCancel,
          ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentCoral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentCoral.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.accentCoral,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.accentCoral,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTituloInput() {
    final hasError = _validationError != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppTheme.accentCoral
              : Colors.white.withValues(alpha: 0.08),
          width: hasError ? 1.4 : 1.0,
        ),
      ),
      child: TextField(
        controller: _tituloController,
        autofocus: widget.mode.isCreate,
        enabled: !_isSubmitting,
        textAlignVertical: TextAlignVertical.center,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: '¿Qué hay que hacer?',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.45),
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: InputBorder.none,
          isDense: false,
        ),
        onChanged: _onTituloChanged,
        onSubmitted: (_) => _handleSubmit(),
      ),
    );
  }

  Widget _buildDescripcionInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: _descripcionController,
        enabled: !_isSubmitting,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          color: AppTheme.textPrimary.withValues(alpha: 0.9),
          fontSize: 14,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: 'Añadir descripción o notas (opcional)...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
            fontSize: 14,
            height: 1.4,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: InputBorder.none,
          isDense: false,
        ),
      ),
    );
  }

  Widget _buildFechaYHoraSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Cuándo',
              style: TextStyle(
                fontSize: 12,
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
              _buildDateChip(
                label: 'Hoy',
                icon: Icons.today_rounded,
                isSelected: _quickDateChoice == _QuickDateChoice.hoy,
                onTap: () => _selectQuickDate(_QuickDateChoice.hoy),
              ),
              const SizedBox(width: 6),
              _buildDateChip(
                label: 'Mañana',
                icon: Icons.event_rounded,
                isSelected: _quickDateChoice == _QuickDateChoice.manana,
                onTap: () => _selectQuickDate(_QuickDateChoice.manana),
              ),
              const SizedBox(width: 6),
              _buildDateChip(
                label: _quickDateChoice == _QuickDateChoice.personalizada && _fechaEjecucion != null
                    ? '${_fechaEjecucion!.day} ${_mesAbrev(_fechaEjecucion!.month)}'
                    : 'Elegir fecha',
                icon: Icons.calendar_month_rounded,
                isSelected: _quickDateChoice == _QuickDateChoice.personalizada,
                onTap: _abrirSelectorFechaPersonalizada,
              ),
              const SizedBox(width: 6),
              _buildDateChip(
                label: 'Sin fecha',
                icon: Icons.inbox_outlined,
                isSelected: _quickDateChoice == _QuickDateChoice.sinFecha,
                onTap: () => _selectQuickDate(_QuickDateChoice.sinFecha),
              ),
              if (_fechaEjecucion != null) ...[
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _buildHoraChip(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHoraChip() {
    final horaTexto = _horaEjecucion != null
        ? '${_horaEjecucion!.hour.toString().padLeft(2, '0')}:${_horaEjecucion!.minute.toString().padLeft(2, '0')}'
        : null;

    if (!_tieneHora) {
      return GestureDetector(
        onTap: _isSubmitting ? null : _abrirSelectorHora,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 13,
                color: AppTheme.secondaryLilac,
              ),
              const SizedBox(width: 5),
              Text(
                '+ Hora',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryLilac,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppTheme.secondaryLilac.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.secondaryLilac.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _isSubmitting ? null : _abrirSelectorHora,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_filled_rounded,
                  size: 13,
                  color: AppTheme.secondaryLilac,
                ),
                const SizedBox(width: 5),
                Text(
                  horaTexto ?? 'Hora',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryLilac,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _isSubmitting ? null : _limpiarHora,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryLilac.withValues(alpha: 0.2),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 11,
                color: AppTheme.secondaryLilac,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isSubmitting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLiquid.withValues(alpha: 0.16)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryLiquid
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAsignacionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 13,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Asignar a',
              style: TextStyle(
                fontSize: 12,
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
              // Opción "Sin asignar"
              _buildMemberChip(
                userId: null,
                nombre: 'Sin asignar',
                icon: Icons.person_off_outlined,
                isSelected: _asignadoAId == null,
              ),
              const SizedBox(width: 6),

              // Miembros del entorno
              ...widget.miembros.map((m) {
                final isSelected = _asignadoAId == m.userId;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: _buildMemberChip(
                    userId: m.userId,
                    nombre: m.username,
                    avatarData: m.avatarData,
                    isSelected: isSelected,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberChip({
    required String? userId,
    required String nombre,
    AvatarData? avatarData,
    IconData? icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: _isSubmitting
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _asignadoAId = userId);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondaryLilac.withValues(alpha: 0.18)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? AppTheme.secondaryLilac
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? AppTheme.secondaryLilac
                    : AppTheme.textSecondary.withValues(alpha: 0.8),
              )
            else
              UserAvatar(
                avatarData: avatarData ?? const AvatarData.initials(),
                username: nombre,
                size: 16,
              ),
            const SizedBox(width: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.secondaryLilac
                    : AppTheme.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mesAbrev(int mes) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    if (mes >= 1 && mes <= 12) return meses[mes - 1];
    return '';
  }

  Widget _buildSubmitButton(bool isCreate) {
    final defaultLabel = isCreate ? 'Crear tarea' : 'Guardar cambios';
    final label = widget.submitButtonText ?? defaultLabel;

    return AppButton(
      text: label,
      isLoading: _isSubmitting,
      icon: isCreate ? Icons.add_rounded : Icons.check_rounded,
      onPressed: _isSubmitting ? null : _handleSubmit,
    );
  }
}
