import 'package:flutter/foundation.dart';
import 'checklist_item_model.dart';
import 'recurrence_rule.dart';
import 'tarea_model.dart';

/// Modo de visualización y operación del formulario de tareas.
enum TaskFormMode {
  create,
  edit;

  bool get isCreate => this == TaskFormMode.create;
  bool get isEdit => this == TaskFormMode.edit;
}

/// Payload unificado con tipado estricto para el formulario de tareas (básico + avanzado).
/// Desacoplado de la persistencia directa para emitir un estado limpio, enriquecido y validado.
@immutable
class TaskFormBasicPayload {
  // ===========================================================================
  // 1. Campos Básicos
  // ===========================================================================

  /// Título obligatorio de la tarea.
  final String titulo;

  /// Descripción o contexto principal de la tarea.
  final String? descripcion;

  /// Fecha de ejecución programada (por defecto la fecha actual en modo creación).
  final DateTime? fechaEjecucion;

  /// Indica si el usuario definió una hora específica para la ejecución.
  final bool tieneHora;

  /// ID del miembro del entorno asignado o null para "Sin asignar".
  final String? asignadoA;

  /// Flag booleano de recurrencia.
  final bool isRecurring;

  /// Configuración de la regla de recurrencia si [isRecurring] está activo.
  final RecurrenceRule? recurrenceRule;

  // ===========================================================================
  // 2. Campos Avanzados Opcionales (Acordeón)
  // ===========================================================================

  /// Duración o tiempo estimado de la tarea en minutos (ej. 15, 30, 60...).
  final int? tiempoEstimadoMinutos;

  /// ID del proyecto asociado al que pertenece la tarea.
  final String? proyectoId;

  /// Categoría o etiqueta taxonómica (ej. "Limpieza", "Cocina", "Compras").
  final String? etiqueta;

  /// Notas, instrucciones o comentarios extendidos de la tarea.
  final String? notas;

  /// Lista de subtareas o checklist interactivo de la tarea.
  final List<ChecklistItemModel> subtasks;

  /// Indica si la tarea tiene una alerta o recordatorio programado.
  final bool hasReminder;

  /// Minutos previos a la fecha de ejecución para disparar la alerta (ej. 15, 30, 60).
  final int? reminderMinutesBefore;

  /// Fecha y hora exacta de recordatorio personalizado si no es relativa a la fecha de ejecución.
  final DateTime? reminderDateTime;

  const TaskFormBasicPayload({
    required this.titulo,
    this.descripcion,
    this.fechaEjecucion,
    this.tieneHora = false,
    this.asignadoA,
    this.isRecurring = false,
    this.recurrenceRule,
    this.tiempoEstimadoMinutos,
    this.proyectoId,
    this.etiqueta,
    this.notas,
    this.subtasks = const [],
    this.hasReminder = false,
    this.reminderMinutesBefore,
    this.reminderDateTime,
  });

  /// Factory para inicializar el payload en modo creación con valores predeterminados.
  factory TaskFormBasicPayload.initialForCreate({
    DateTime? defaultDate,
    String? defaultAssigneeId,
    String? defaultProyectoId,
  }) {
    final now = DateTime.now();
    final today = defaultDate ?? DateTime(now.year, now.month, now.day);
    return TaskFormBasicPayload(
      titulo: '',
      descripcion: null,
      fechaEjecucion: today,
      tieneHora: false,
      asignadoA: defaultAssigneeId,
      isRecurring: false,
      recurrenceRule: null,
      tiempoEstimadoMinutos: null,
      proyectoId: defaultProyectoId,
      etiqueta: null,
      notas: null,
      subtasks: const [],
      hasReminder: false,
      reminderMinutesBefore: null,
      reminderDateTime: null,
    );
  }

  /// Factory para inicializar el payload a partir de un [TareaModel] en modo edición.
  factory TaskFormBasicPayload.fromTarea(TareaModel tarea) {
    final tieneHora = tarea.fechaLimite != null &&
        (tarea.fechaLimite!.hour != 0 || tarea.fechaLimite!.minute != 0);

    final etiqueta = tarea.etiqueta;
    String? descripcionTextual = tarea.descripcion;

    if (etiqueta != null && descripcionTextual != null) {
      final clean = descripcionTextual.trim();
      if (clean.toLowerCase() == etiqueta.toLowerCase() ||
          clean.toLowerCase() == '#${etiqueta.toLowerCase()}') {
        descripcionTextual = null;
      } else if (clean.startsWith('[tag:') && clean.contains(']')) {
        final afterTag = clean.substring(clean.indexOf(']') + 1).trim();
        descripcionTextual = afterTag.isNotEmpty ? afterTag : null;
      } else if (clean.startsWith('#$etiqueta ')) {
        final afterTag = clean.substring(etiqueta.length + 2).trim();
        descripcionTextual = afterTag.isNotEmpty ? afterTag : null;
      }
    }

    return TaskFormBasicPayload(
      titulo: tarea.titulo,
      descripcion: descripcionTextual,
      fechaEjecucion: tarea.fechaLimite,
      tieneHora: tieneHora,
      asignadoA: tarea.asignadoA,
      isRecurring: false,
      recurrenceRule: null,
      tiempoEstimadoMinutos:
          tarea.tiempoEstimadoMinutos > 0 ? tarea.tiempoEstimadoMinutos : null,
      proyectoId: tarea.proyectoId,
      etiqueta: etiqueta,
      notas: null,
      subtasks: List<ChecklistItemModel>.from(tarea.checklist),
      hasReminder: tarea.recordatorios.isNotEmpty,
      reminderMinutesBefore: null,
      reminderDateTime: tarea.recordatorios.isNotEmpty
          ? tarea.recordatorios.first.fechaNotificacion
          : null,
    );
  }

  /// Indica si alguna opción avanzada ha sido configurada por el usuario.
  bool get hasAdvancedOptionsConfigured =>
      (tiempoEstimadoMinutos != null && tiempoEstimadoMinutos! > 0) ||
      proyectoId != null ||
      etiqueta != null ||
      (notas != null && notas!.trim().isNotEmpty) ||
      subtasks.isNotEmpty ||
      isRecurring ||
      hasReminder;

  /// Contador de opciones avanzadas activas para mostrar en el badge del acordeón.
  int get advancedOptionsCount {
    int count = 0;
    if (tiempoEstimadoMinutos != null && tiempoEstimadoMinutos! > 0) count++;
    if (proyectoId != null) count++;
    if (etiqueta != null) count++;
    if (notas != null && notas!.trim().isNotEmpty) count++;
    if (subtasks.isNotEmpty) count++;
    if (isRecurring) count++;
    if (hasReminder) count++;
    return count;
  }

  /// Valida el payload asegurando que los campos requeridos cumplan las reglas de negocio.
  /// Retorna un mensaje explicativo si hay fallos o `null` si es completamente válido.
  String? validate() {
    if (titulo.trim().isEmpty) {
      return 'El título de la tarea es obligatorio.';
    }
    if (isRecurring && recurrenceRule != null) {
      final ruleError = recurrenceRule!.validate();
      if (ruleError != null) return ruleError;
    }
    if (tiempoEstimadoMinutos != null && tiempoEstimadoMinutos! < 0) {
      return 'El tiempo estimado no puede ser negativo.';
    }
    return null;
  }

  /// Indica si el payload actual supera todas las validaciones.
  bool get isValid => validate() == null;

  /// Crea una copia del payload permitiendo sobreescribir o limpiar propiedades individuales.
  TaskFormBasicPayload copyWith({
    String? titulo,
    String? descripcion,
    bool clearDescripcion = false,
    DateTime? fechaEjecucion,
    bool clearFechaEjecucion = false,
    bool? tieneHora,
    String? asignadoA,
    bool clearAsignadoA = false,
    bool? isRecurring,
    RecurrenceRule? recurrenceRule,
    bool clearRecurrenceRule = false,
    int? tiempoEstimadoMinutos,
    bool clearTiempoEstimado = false,
    String? proyectoId,
    bool clearProyectoId = false,
    String? etiqueta,
    bool clearEtiqueta = false,
    String? notas,
    bool clearNotas = false,
    List<ChecklistItemModel>? subtasks,
    bool? hasReminder,
    int? reminderMinutesBefore,
    bool clearReminderMinutes = false,
    DateTime? reminderDateTime,
    bool clearReminderDateTime = false,
  }) {
    return TaskFormBasicPayload(
      titulo: titulo ?? this.titulo,
      descripcion: clearDescripcion ? null : (descripcion ?? this.descripcion),
      fechaEjecucion: clearFechaEjecucion ? null : (fechaEjecucion ?? this.fechaEjecucion),
      tieneHora: tieneHora ?? this.tieneHora,
      asignadoA: clearAsignadoA ? null : (asignadoA ?? this.asignadoA),
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: clearRecurrenceRule
          ? null
          : (recurrenceRule ?? this.recurrenceRule),
      tiempoEstimadoMinutos: clearTiempoEstimado
          ? null
          : (tiempoEstimadoMinutos ?? this.tiempoEstimadoMinutos),
      proyectoId: clearProyectoId ? null : (proyectoId ?? this.proyectoId),
      etiqueta: clearEtiqueta ? null : (etiqueta ?? this.etiqueta),
      notas: clearNotas ? null : (notas ?? this.notas),
      subtasks: subtasks ?? this.subtasks,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderMinutesBefore: clearReminderMinutes
          ? null
          : (reminderMinutesBefore ?? this.reminderMinutesBefore),
      reminderDateTime: clearReminderDateTime
          ? null
          : (reminderDateTime ?? this.reminderDateTime),
    );
  }

  /// Retorna una representación limpia en Map para serialización o consumo de servicio.
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo.trim(),
      'descripcion': (descripcion != null && descripcion!.trim().isNotEmpty)
          ? descripcion!.trim()
          : null,
      'fecha_ejecucion': fechaEjecucion?.toIso8601String(),
      'tiene_hora': tieneHora,
      'asignado_a': asignadoA,
      'is_recurring': isRecurring,
      'recurrence_rule': recurrenceRule?.toJson(),
      'tiempo_estimado_minutos': tiempoEstimadoMinutos,
      'proyecto_id': proyectoId,
      'etiqueta': etiqueta,
      'notas': (notas != null && notas!.trim().isNotEmpty) ? notas!.trim() : null,
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'has_reminder': hasReminder,
      'reminder_minutes_before': reminderMinutesBefore,
      'reminder_date_time': reminderDateTime?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskFormBasicPayload &&
        other.titulo == titulo &&
        other.descripcion == descripcion &&
        other.fechaEjecucion == fechaEjecucion &&
        other.tieneHora == tieneHora &&
        other.asignadoA == asignadoA &&
        other.isRecurring == isRecurring &&
        other.recurrenceRule == recurrenceRule &&
        other.tiempoEstimadoMinutos == tiempoEstimadoMinutos &&
        other.proyectoId == proyectoId &&
        other.etiqueta == etiqueta &&
        other.notas == notas &&
        listEquals(other.subtasks, subtasks) &&
        other.hasReminder == hasReminder &&
        other.reminderMinutesBefore == reminderMinutesBefore &&
        other.reminderDateTime == reminderDateTime;
  }

  @override
  int get hashCode => Object.hash(
        titulo,
        descripcion,
        fechaEjecucion,
        tieneHora,
        asignadoA,
        isRecurring,
        recurrenceRule,
        tiempoEstimadoMinutos,
        proyectoId,
        etiqueta,
        notas,
        Object.hashAll(subtasks),
        hasReminder,
        reminderMinutesBefore,
        reminderDateTime,
      );

  @override
  String toString() {
    return 'TaskFormBasicPayload(titulo: "$titulo", fechaEjecucion: $fechaEjecucion, tiempoEstimado: $tiempoEstimadoMinutos, proyectoId: $proyectoId, etiqueta: $etiqueta, subtasks: ${subtasks.length}, hasReminder: $hasReminder)';
  }
}
