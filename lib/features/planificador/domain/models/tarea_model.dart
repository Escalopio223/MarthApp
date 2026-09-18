import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'checklist_item_model.dart';
import 'comentario_tarea_model.dart';
import 'recordatorio_tarea_model.dart';

/// Modelo inmutable de una Tarea dentro del Planificador (tabla `planificador_tareas`).
@immutable
class TareaModel {
  final String id;
  final String entornoId;
  final String? proyectoId;
  final String titulo;
  final String? descripcion;
  final DateTime? fechaLimite;
  final String? asignadoA;
  final int tiempoEstimadoMinutos;
  final String estado; // 'pendiente' | 'en_progreso' | 'completada'
  final List<ChecklistItemModel> checklist;
  final List<ComentarioTareaModel> comentarios;
  final List<RecordatorioTareaModel> recordatorios;
  final String? completadaPor;
  final DateTime? completadaAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TareaModel({
    required this.id,
    required this.entornoId,
    this.proyectoId,
    required this.titulo,
    this.descripcion,
    this.fechaLimite,
    this.asignadoA,
    this.tiempoEstimadoMinutos = 15,
    this.estado = 'pendiente',
    this.checklist = const [],
    this.comentarios = const [],
    this.recordatorios = const [],
    this.completadaPor,
    this.completadaAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get estaCompletada => estado == 'completada';
  bool get estaEnProgreso => estado == 'en_progreso';
  bool get estaPendiente => estado == 'pendiente';
  bool get tieneFechaLimite => fechaLimite != null;

  int get checklistItemsTotales => checklist.length;
  int get checklistItemsCompletados =>
      checklist.where((item) => item.completado).length;

  /// Retorna un valor entre 0.0 y 1.0 indicando el progreso
  double get porcentajeProgreso {
    if (estaCompletada) return 1.0;
    if (checklist.isEmpty) {
      return estaEnProgreso ? 0.5 : 0.0;
    }
    return checklistItemsCompletados / checklist.length;
  }

  /// Etiqueta o categoría asociada a la tarea (almacenada limpiamente en descripcion)
  String? get etiqueta {
    if (descripcion == null || descripcion!.trim().isEmpty) return null;
    final d = descripcion!.trim();
    if (d.startsWith('#')) return d.substring(1).trim();
    if (d.startsWith('[tag:') && d.endsWith(']')) {
      return d.substring(5, d.length - 1).trim();
    }
    if (!d.contains('\n') && d.length <= 30) {
      return d;
    }
    return null;
  }

  TareaModel copyWith({
    String? id,
    String? entornoId,
    String? proyectoId,
    String? titulo,
    String? descripcion,
    bool clearDescripcion = false,
    DateTime? fechaLimite,
    bool clearFechaLimite = false,
    String? asignadoA,
    bool clearAsignadoA = false,
    int? tiempoEstimadoMinutos,
    String? estado,
    List<ChecklistItemModel>? checklist,
    List<ComentarioTareaModel>? comentarios,
    List<RecordatorioTareaModel>? recordatorios,
    String? completadaPor,
    DateTime? completadaAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TareaModel(
      id: id ?? this.id,
      entornoId: entornoId ?? this.entornoId,
      proyectoId: proyectoId ?? this.proyectoId,
      titulo: titulo ?? this.titulo,
      descripcion: clearDescripcion ? null : (descripcion ?? this.descripcion),
      fechaLimite: clearFechaLimite ? null : (fechaLimite ?? this.fechaLimite),
      asignadoA: clearAsignadoA ? null : (asignadoA ?? this.asignadoA),
      tiempoEstimadoMinutos:
          tiempoEstimadoMinutos ?? this.tiempoEstimadoMinutos,
      estado: estado ?? this.estado,
      checklist: checklist ?? this.checklist,
      comentarios: comentarios ?? this.comentarios,
      recordatorios: recordatorios ?? this.recordatorios,
      completadaPor: completadaPor ?? this.completadaPor,
      completadaAt: completadaAt ?? this.completadaAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TareaModel.fromJson(Map<String, dynamic> json) {
    // Parseo seguro y resiliente del campo checklist (JSONB)
    List<ChecklistItemModel> parsedChecklist = const [];
    final rawChecklist = json['checklist'];

    try {
      if (rawChecklist is List) {
        parsedChecklist = rawChecklist
            .whereType<Map>()
            .map((e) => ChecklistItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (rawChecklist is String && rawChecklist.isNotEmpty) {
        final decoded = jsonDecode(rawChecklist);
        if (decoded is List) {
          parsedChecklist = decoded
              .whereType<Map>()
              .map((e) => ChecklistItemModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (_) {
      parsedChecklist = const [];
    }

    // Parseo seguro y resiliente del campo comentarios (JSONB)
    List<ComentarioTareaModel> parsedComentarios = const [];
    final rawComentarios = json['comentarios'];

    try {
      if (rawComentarios is List) {
        parsedComentarios = rawComentarios
            .whereType<Map>()
            .map((e) => ComentarioTareaModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (rawComentarios is String && rawComentarios.isNotEmpty) {
        final decoded = jsonDecode(rawComentarios);
        if (decoded is List) {
          parsedComentarios = decoded
              .whereType<Map>()
              .map((e) => ComentarioTareaModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (_) {
      parsedComentarios = const [];
    }

    // Parseo seguro del campo recordatorios
    List<RecordatorioTareaModel> parsedRecordatorios = const [];
    final rawRecordatorios = json['recordatorios'];
    try {
      if (rawRecordatorios is List) {
        parsedRecordatorios = rawRecordatorios
            .whereType<Map>()
            .map((e) => RecordatorioTareaModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      parsedRecordatorios = const [];
    }

    return TareaModel(
      id: json['id'] as String? ?? '',
      entornoId: json['entorno_id'] as String? ?? '',
      proyectoId: json['proyecto_id'] as String?,
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      fechaLimite: json['fecha_limite'] != null
          ? DateTime.tryParse(json['fecha_limite'].toString())?.toLocal()
          : null,
      asignadoA: json['asignado_a'] as String?,
      tiempoEstimadoMinutos: json['tiempo_estimado_minutos'] is int
          ? json['tiempo_estimado_minutos'] as int
          : int.tryParse(json['tiempo_estimado_minutos']?.toString() ?? '') ?? 15,
      estado: json['estado'] as String? ?? 'pendiente',
      checklist: parsedChecklist,
      comentarios: parsedComentarios,
      recordatorios: parsedRecordatorios,
      completadaPor: json['completada_por'] as String?,
      completadaAt: json['completada_at'] != null
          ? DateTime.tryParse(json['completada_at'].toString())?.toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entorno_id': entornoId,
      if (proyectoId != null) 'proyecto_id': proyectoId,
      'titulo': titulo,
      if (descripcion != null) 'descripcion': descripcion,
      if (fechaLimite != null) 'fecha_limite': fechaLimite!.toIso8601String(),
      if (asignadoA != null) 'asignado_a': asignadoA,
      'tiempo_estimado_minutos': tiempoEstimadoMinutos,
      'estado': estado,
      'checklist': checklist.map((item) => item.toJson()).toList(),
      'comentarios': comentarios.map((item) => item.toJson()).toList(),
      'recordatorios': recordatorios.map((item) => item.toJson()).toList(),
      if (completadaPor != null) 'completada_por': completadaPor,
      if (completadaAt != null) 'completada_at': completadaAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TareaModel &&
        other.id == id &&
        other.entornoId == entornoId &&
        other.proyectoId == proyectoId &&
        other.titulo == titulo &&
        other.descripcion == descripcion &&
        other.fechaLimite == fechaLimite &&
        other.asignadoA == asignadoA &&
        other.tiempoEstimadoMinutos == tiempoEstimadoMinutos &&
        other.estado == estado &&
        listEquals(other.checklist, checklist) &&
        listEquals(other.comentarios, comentarios) &&
        listEquals(other.recordatorios, recordatorios) &&
        other.completadaPor == completadaPor &&
        other.completadaAt == completadaAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        entornoId,
        proyectoId,
        titulo,
        descripcion,
        fechaLimite,
        asignadoA,
        tiempoEstimadoMinutos,
        estado,
        Object.hashAll(checklist),
        Object.hashAll(comentarios),
        Object.hashAll(recordatorios),
        completadaPor,
        completadaAt,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'TareaModel(id: $id, titulo: $titulo, tiempoEstimado: ${tiempoEstimadoMinutos}m, estado: $estado, subtareas: ${checklist.length}, comentarios: ${comentarios.length}, recordatorios: ${recordatorios.length})';
}
