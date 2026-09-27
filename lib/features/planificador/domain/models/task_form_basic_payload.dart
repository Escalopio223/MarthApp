import 'package:flutter/foundation.dart';
import 'tarea_model.dart';

/// Modo de visualización y operación del formulario de tareas.
enum TaskFormMode {
  create,
  edit;

  bool get isCreate => this == TaskFormMode.create;
  bool get isEdit => this == TaskFormMode.edit;
}

/// Payload base con tipado estricto para el formulario de tareas (creación y edición).
/// Desacoplado de la persistencia directa para emitir un estado limpio y validado.
@immutable
class TaskFormBasicPayload {
  /// Título obligatorio de la tarea.
  final String titulo;

  /// Descripción o notas opcionales.
  final String? descripcion;

  /// Fecha de ejecución programada (por defecto la fecha actual en modo creación).
  final DateTime? fechaEjecucion;

  /// Indica si el usuario definió una hora específica para la ejecución.
  final bool tieneHora;

  /// ID del miembro del entorno asignado o null para "Sin asignar".
  final String? asignadoA;

  /// Flag booleano de recurrencia que servirá de anclaje para el futuro
  /// motor de reglas periódicas (`feat/tasks-recurring-rules`).
  final bool isRecurring;

  const TaskFormBasicPayload({
    required this.titulo,
    this.descripcion,
    this.fechaEjecucion,
    this.tieneHora = false,
    this.asignadoA,
    this.isRecurring = false,
  });

  /// Factory para inicializar el payload en modo creación con valores predeterminados.
  factory TaskFormBasicPayload.initialForCreate({
    DateTime? defaultDate,
    String? defaultAssigneeId,
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
    );
  }

  /// Factory para inicializar el payload a partir de un [TareaModel] en modo edición.
  factory TaskFormBasicPayload.fromTarea(TareaModel tarea) {
    final tieneHora = tarea.fechaLimite != null &&
        (tarea.fechaLimite!.hour != 0 || tarea.fechaLimite!.minute != 0);

    return TaskFormBasicPayload(
      titulo: tarea.titulo,
      descripcion: tarea.descripcion,
      fechaEjecucion: tarea.fechaLimite,
      tieneHora: tieneHora,
      asignadoA: tarea.asignadoA,
      isRecurring: false, // Base para feat/tasks-recurring-rules
    );
  }

  /// Valida el payload asegurando que los campos requeridos cumplan las reglas de negocio.
  /// Retorna un mensaje explicativo si hay fallos o `null` si es completamente válido.
  String? validate() {
    if (titulo.trim().isEmpty) {
      return 'El título de la tarea es obligatorio.';
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
  }) {
    return TaskFormBasicPayload(
      titulo: titulo ?? this.titulo,
      descripcion: clearDescripcion ? null : (descripcion ?? this.descripcion),
      fechaEjecucion: clearFechaEjecucion ? null : (fechaEjecucion ?? this.fechaEjecucion),
      tieneHora: tieneHora ?? this.tieneHora,
      asignadoA: clearAsignadoA ? null : (asignadoA ?? this.asignadoA),
      isRecurring: isRecurring ?? this.isRecurring,
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
        other.isRecurring == isRecurring;
  }

  @override
  int get hashCode => Object.hash(
        titulo,
        descripcion,
        fechaEjecucion,
        tieneHora,
        asignadoA,
        isRecurring,
      );

  @override
  String toString() {
    return 'TaskFormBasicPayload(titulo: "$titulo", fechaEjecucion: $fechaEjecucion, tieneHora: $tieneHora, asignadoA: $asignadoA, isRecurring: $isRecurring)';
  }
}
