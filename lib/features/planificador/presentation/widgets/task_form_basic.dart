import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/recurrence_rule.dart';
import '../../domain/models/tarea_model.dart';
import '../../domain/models/task_form_basic_payload.dart';
import 'recurring_rule_form_widget.dart';

enum _QuickDateChoice { hoy, manana, personalizada, sinFecha }

/// Componente modular, desacoplado y reutilizable para el formulario básico de tareas.
/// Soporta tanto creación (`create`) como edición (`edit`), gestionando el estado de carga,
/// prevención de doble submit, validaciones en tiempo real y tipado estricto.
class TaskFormBasic extends StatefulWidget {
  final TaskFormMode mode;
  final TaskFormBasicPayload? initialPayload;
  final TareaModel? initialTarea;
  final List<EnvironmentMemberModel> miembros;
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

  bool _isSubmitting = false;
  String? _validationError;
  String? _submitError;
  bool _showNotesField = false;

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
    _showNotesField = payload.descripcion != null && payload.descripcion!.trim().isNotEmpty;

    _asignadoAId = payload.asignadoA;
    _isRecurring = payload.isRecurring;
    _recurrenceRule = payload.recurrenceRule ??
        RecurrenceRule.weekly(
          daysOfWeek: [DateTime.now().weekday],
        );
    _fechaEjecucion = payload.fechaEjecucion;
    _tieneHora = payload.tieneHora;

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
    final defaultTitle = isCreate ? 'Nueva Tarea' : 'Editar Tarea';
    final effectiveTitle = widget.title ?? defaultTitle;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.cardBorderColor,
          width: 1.0,
        ),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                    color: AppTheme.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Cabecera: Icono, Título y botón cerrar
            _buildHeader(effectiveTitle, isCreate),
            const SizedBox(height: 16),

            // Banner visual de error de validación o submit
            if (_validationError != null || _submitError != null) ...[
              _buildErrorBanner(_validationError ?? _submitError!),
              const SizedBox(height: 14),
            ],

            // 1. Campo de texto principal (Título obligatorio)
            _buildTituloField(),
            const SizedBox(height: 10),

            // Campo opcional expandible para notas/descripción adicional
            _buildNotasSection(),
            const SizedBox(height: 18),

            // 2. Selector de fecha de ejecución y hora opcional
            _buildFechaYHoraSection(),
            const SizedBox(height: 18),

            // 3. Selector de asignación a miembros del entorno
            _buildAsignacionSection(),
            const SizedBox(height: 18),

            // 4. Preparación de recurrencia (isRecurring toggle)
            _buildRecurrenciaSection(),
            const SizedBox(height: 24),

            // 5. Botón de acción principal con protección anti-doble clic
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.actionGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isCreate ? Icons.add_task_rounded : Icons.edit_note_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        if (widget.onCancel != null)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            color: AppTheme.textSecondary,
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
        borderRadius: BorderRadius.circular(14),
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
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.accentCoral,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTituloField() {
    final hasError = _validationError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '¿QUÉ HAY QUE HACER?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: hasError ? AppTheme.accentCoral : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCoral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tituloController,
          autofocus: widget.mode.isCreate,
          enabled: !_isSubmitting,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Ej. Fregar los platos, Comprar café...',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? AppTheme.accentCoral : AppTheme.cardBorderColor,
                width: hasError ? 1.4 : 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? AppTheme.accentCoral : AppTheme.cardBorderColor,
                width: hasError ? 1.4 : 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? AppTheme.accentCoral : AppTheme.primaryLiquid,
                width: 1.6,
              ),
            ),
          ),
          onChanged: _onTituloChanged,
          onSubmitted: (_) => _handleSubmit(),
        ),
      ],
    );
  }

  Widget _buildNotasSection() {
    if (!_showNotesField) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _showNotesField = true);
          },
          icon: Icon(
            Icons.add_comment_outlined,
            size: 15,
            color: AppTheme.secondaryLilac,
          ),
          label: Text(
            'Añadir notas o descripción adicional',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryLilac,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NOTAS / DESCRIPCIÓN (OPCIONAL)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppTheme.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _descripcionController.clear();
                  _showNotesField = false;
                });
              },
              child: Text(
                'Ocultar',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descripcionController,
          enabled: !_isSubmitting,
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Detalles, instrucciones o recordatorios para la tarea...',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppTheme.darkBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppTheme.cardBorderColor,
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
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

  Widget _buildFechaYHoraSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FECHA DE EJECUCIÓN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Selectores de fecha rápida
        Row(
          children: [
            _buildDateChip(
              label: 'Hoy',
              icon: Icons.today_rounded,
              isSelected: _quickDateChoice == _QuickDateChoice.hoy,
              onTap: () => _selectQuickDate(_QuickDateChoice.hoy),
            ),
            const SizedBox(width: 8),
            _buildDateChip(
              label: 'Mañana',
              icon: Icons.event_rounded,
              isSelected: _quickDateChoice == _QuickDateChoice.manana,
              onTap: () => _selectQuickDate(_QuickDateChoice.manana),
            ),
            const SizedBox(width: 8),
            _buildDateChip(
              label: _quickDateChoice == _QuickDateChoice.personalizada && _fechaEjecucion != null
                  ? '${_fechaEjecucion!.day}/${_fechaEjecucion!.month}/${_fechaEjecucion!.year}'
                  : 'Elegir fecha',
              icon: Icons.calendar_month_rounded,
              isSelected: _quickDateChoice == _QuickDateChoice.personalizada,
              onTap: _abrirSelectorFechaPersonalizada,
            ),
            const SizedBox(width: 8),
            _buildDateChip(
              label: 'Sin fecha',
              icon: Icons.inbox_rounded,
              isSelected: _quickDateChoice == _QuickDateChoice.sinFecha,
              onTap: () => _selectQuickDate(_QuickDateChoice.sinFecha),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Selector táctil de hora opcional
        if (_fechaEjecucion != null) _buildHoraSelector(),
      ],
    );
  }

  Widget _buildDateChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: _isSubmitting ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryLiquid.withValues(alpha: 0.16)
                : AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryLiquid
                  : AppTheme.cardBorderColor,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? AppTheme.primaryLiquid
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryLiquid
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoraSelector() {
    final horaTexto = _horaEjecucion != null
        ? '${_horaEjecucion!.hour.toString().padLeft(2, '0')}:${_horaEjecucion!.minute.toString().padLeft(2, '0')}'
        : null;

    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 16,
          color: _tieneHora ? AppTheme.secondaryLilac : AppTheme.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          'Hora opcional:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        if (!_tieneHora)
          GestureDetector(
            onTap: _isSubmitting ? null : _abrirSelectorHora,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.cardBorderColor,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 14,
                    color: AppTheme.secondaryLilac,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Añadir hora',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryLilac,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryLilac.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.secondaryLilac,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _isSubmitting ? null : _abrirSelectorHora,
                  child: Text(
                    horaTexto ?? 'Definida',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryLilac,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _isSubmitting ? null : _limpiarHora,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppTheme.secondaryLilac,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAsignacionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ASIGNAR A',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppTheme.textSecondary,
          ),
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
                icon: Icons.person_outline_rounded,
                isSelected: _asignadoAId == null,
              ),
              const SizedBox(width: 8),

              // Miembros del entorno
              ...widget.miembros.map((m) {
                final isSelected = _asignadoAId == m.userId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondaryAccent.withValues(alpha: 0.18)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.secondaryAccent
                : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppTheme.secondaryAccent
                    : AppTheme.textSecondary,
              )
            else
              UserAvatar(
                avatarData: avatarData ?? const AvatarData.initials(),
                username: nombre,
                size: 18,
              ),
            const SizedBox(width: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.secondaryAccent
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenciaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isRecurring
                  ? AppTheme.primaryLiquid.withValues(alpha: 0.6)
                  : AppTheme.cardBorderColor,
              width: _isRecurring ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isRecurring
                      ? AppTheme.primaryLiquid.withValues(alpha: 0.2)
                      : AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  size: 20,
                  color: _isRecurring ? AppTheme.primaryLiquid : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarea recurrente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isRecurring
                          ? _recurrenceRule.toHumanReadable()
                          : 'Configurar repetición periódica automática',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isRecurring,
                activeTrackColor: AppTheme.primaryLiquid,
                activeThumbColor: Colors.white,
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _isRecurring = val);
                      },
              ),
            ],
          ),
        ),

        // Subformulario inline de configuración de recurrencia
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          child: _isRecurring
              ? Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: RecurringRuleFormWidget(
                    rule: _recurrenceRule,
                    onChanged: (newRule) {
                      setState(() => _recurrenceRule = newRule);
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
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
