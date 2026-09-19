import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'checklist_item_model.dart';
import 'recordatorio_tarea_model.dart';

/// Modelo inmutable de un Evento dentro del Planificador (tabla `planificador_eventos`).
/// Soporta eventos generales y cumpleaños con ideas de regalo y checklist de subtareas.
@immutable
class EventoModel {
  final String id;
  final String entornoId;
  final String titulo;
  final String? descripcion;
  final String tipo; // 'cumpleanos' | 'evento_general'
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final bool esTodoElDia;
  final String? rrule;
  final String? personaCumpleanos;
  final String? ideasRegalo;
  final List<ChecklistItemModel> checklist;
  final List<RecordatorioTareaModel> recordatorios;
  final String createdBy;
  final DateTime createdAt;

  const EventoModel({
    required this.id,
    required this.entornoId,
    required this.titulo,
    this.descripcion,
    required this.tipo,
    required this.fechaInicio,
    this.fechaFin,
    this.esTodoElDia = false,
    this.rrule,
    this.personaCumpleanos,
    this.ideasRegalo,
    this.checklist = const [],
    this.recordatorios = const [],
    required this.createdBy,
    required this.createdAt,
  });

  bool get esCumpleanos => tipo == 'cumpleanos';
  bool get esEventoGeneral => tipo == 'evento_general';

  int get checklistItemsTotales => checklist.length;
  int get checklistItemsCompletados =>
      checklist.where((item) => item.completado).length;

  /// Retorna un valor entre 0.0 y 1.0 indicando el progreso de su checklist
  double get porcentajeProgreso {
    if (checklist.isEmpty) return 0.0;
    return checklistItemsCompletados / checklist.length;
  }

  /// Nombre a mostrar para el cumpleaños (o título si no está especificado)
  String get nombrePersonaCumpleanos =>
      personaCumpleanos?.isNotEmpty == true ? personaCumpleanos! : titulo;

  /// Calcula los días restantes para la próxima repetición del cumpleaños
  int? get diasParaCumpleanos {
    if (!esCumpleanos) return null;
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    var proximo = DateTime(now.year, fechaInicio.month, fechaInicio.day);

    if (proximo.isBefore(hoy)) {
      proximo = DateTime(now.year + 1, fechaInicio.month, fechaInicio.day);
    }
    return proximo.difference(hoy).inDays;
  }

  EventoModel copyWith({
    String? id,
    String? entornoId,
    String? titulo,
    String? descripcion,
    String? tipo,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? esTodoElDia,
    String? rrule,
    String? personaCumpleanos,
    String? ideasRegalo,
    List<ChecklistItemModel>? checklist,
    List<RecordatorioTareaModel>? recordatorios,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return EventoModel(
      id: id ?? this.id,
      entornoId: entornoId ?? this.entornoId,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      esTodoElDia: esTodoElDia ?? this.esTodoElDia,
      rrule: rrule ?? this.rrule,
      personaCumpleanos: personaCumpleanos ?? this.personaCumpleanos,
      ideasRegalo: ideasRegalo ?? this.ideasRegalo,
      checklist: checklist ?? this.checklist,
      recordatorios: recordatorios ?? this.recordatorios,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EventoModel.fromJson(Map<String, dynamic> json) {
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

    // Parseo seguro y resiliente del campo recordatorios (JSONB)
    List<RecordatorioTareaModel> parsedRecordatorios = const [];
    final rawRecordatorios = json['recordatorios'];

    try {
      if (rawRecordatorios is List) {
        parsedRecordatorios = rawRecordatorios
            .whereType<Map>()
            .map((e) =>
                RecordatorioTareaModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (rawRecordatorios is String && rawRecordatorios.isNotEmpty) {
        final decoded = jsonDecode(rawRecordatorios);
        if (decoded is List) {
          parsedRecordatorios = decoded
              .whereType<Map>()
              .map((e) =>
                  RecordatorioTareaModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (_) {
      parsedRecordatorios = const [];
    }

    return EventoModel(
      id: json['id'] as String? ?? '',
      entornoId: json['entorno_id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      tipo: json['tipo'] as String? ?? 'evento_general',
      fechaInicio: json['fecha_inicio'] != null
          ? (DateTime.tryParse(json['fecha_inicio'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      fechaFin: json['fecha_fin'] != null
          ? DateTime.tryParse(json['fecha_fin'].toString())?.toLocal()
          : null,
      esTodoElDia: json['es_todo_el_dia'] as bool? ?? false,
      rrule: json['rrule'] as String?,
      personaCumpleanos: json['persona_cumpleanos'] as String?,
      ideasRegalo: json['ideas_regalo'] as String?,
      checklist: parsedChecklist,
      recordatorios: parsedRecordatorios,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entorno_id': entornoId,
      'titulo': titulo,
      if (descripcion != null) 'descripcion': descripcion,
      'tipo': tipo,
      'fecha_inicio': fechaInicio.toIso8601String(),
      if (fechaFin != null) 'fecha_fin': fechaFin!.toIso8601String(),
      'es_todo_el_dia': esTodoElDia,
      if (rrule != null) 'rrule': rrule,
      if (personaCumpleanos != null) 'persona_cumpleanos': personaCumpleanos,
      if (ideasRegalo != null) 'ideas_regalo': ideasRegalo,
      'checklist': checklist.map((item) => item.toJson()).toList(),
      'recordatorios': recordatorios.map((item) => item.toJson()).toList(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventoModel &&
        other.id == id &&
        other.entornoId == entornoId &&
        other.titulo == titulo &&
        other.descripcion == descripcion &&
        other.tipo == tipo &&
        other.fechaInicio == fechaInicio &&
        other.fechaFin == fechaFin &&
        other.esTodoElDia == esTodoElDia &&
        other.rrule == rrule &&
        other.personaCumpleanos == personaCumpleanos &&
        other.ideasRegalo == ideasRegalo &&
        listEquals(other.checklist, checklist) &&
        listEquals(other.recordatorios, recordatorios) &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        entornoId,
        titulo,
        descripcion,
        tipo,
        fechaInicio,
        fechaFin,
        esTodoElDia,
        rrule,
        personaCumpleanos,
        ideasRegalo,
        Object.hashAll(checklist),
        Object.hashAll(recordatorios),
        createdBy,
        createdAt,
      );

  @override
  String toString() =>
      'EventoModel(id: $id, titulo: $titulo, tipo: $tipo, checklist: ${checklist.length} items, recordatorios: ${recordatorios.length} recs)';
}
