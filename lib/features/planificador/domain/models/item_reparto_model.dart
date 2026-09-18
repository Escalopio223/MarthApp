import 'package:flutter/foundation.dart';

/// Modelo inmutable que representa la asignación individual de una tarea en una sesión de reparto (tabla `planificador_repartos_items`).
@immutable
class ItemRepartoModel {
  final String id;
  final String sesionId;
  final String tareaId;
  final String usuarioAsignadoInicial;
  final String usuarioAsignadoFinal;
  final int tiempoMinutos;
  final String? tituloTarea; // Informativo para la UI

  const ItemRepartoModel({
    required this.id,
    required this.sesionId,
    required this.tareaId,
    required this.usuarioAsignadoInicial,
    required this.usuarioAsignadoFinal,
    required this.tiempoMinutos,
    this.tituloTarea,
  });

  ItemRepartoModel copyWith({
    String? id,
    String? sesionId,
    String? tareaId,
    String? usuarioAsignadoInicial,
    String? usuarioAsignadoFinal,
    int? tiempoMinutos,
    String? tituloTarea,
  }) {
    return ItemRepartoModel(
      id: id ?? this.id,
      sesionId: sesionId ?? this.sesionId,
      tareaId: tareaId ?? this.tareaId,
      usuarioAsignadoInicial:
          usuarioAsignadoInicial ?? this.usuarioAsignadoInicial,
      usuarioAsignadoFinal:
          usuarioAsignadoFinal ?? this.usuarioAsignadoFinal,
      tiempoMinutos: tiempoMinutos ?? this.tiempoMinutos,
      tituloTarea: tituloTarea ?? this.tituloTarea,
    );
  }

  factory ItemRepartoModel.fromJson(Map<String, dynamic> json) {
    return ItemRepartoModel(
      id: json['id'] as String? ?? '',
      sesionId: json['sesion_id'] as String? ?? '',
      tareaId: json['tarea_id'] as String? ?? '',
      usuarioAsignadoInicial:
          json['usuario_asignado_inicial'] as String? ?? '',
      usuarioAsignadoFinal:
          json['usuario_asignado_final'] as String? ?? '',
      tiempoMinutos: json['tiempo_minutos'] is int
          ? json['tiempo_minutos'] as int
          : int.tryParse(json['tiempo_minutos']?.toString() ?? '') ?? 0,
      tituloTarea: json['titulo_tarea'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sesion_id': sesionId,
      'tarea_id': tareaId,
      'usuario_asignado_inicial': usuarioAsignadoInicial,
      'usuario_asignado_final': usuarioAsignadoFinal,
      'tiempo_minutos': tiempoMinutos,
      if (tituloTarea != null) 'titulo_tarea': tituloTarea,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemRepartoModel &&
        other.id == id &&
        other.sesionId == sesionId &&
        other.tareaId == tareaId &&
        other.usuarioAsignadoInicial == usuarioAsignadoInicial &&
        other.usuarioAsignadoFinal == usuarioAsignadoFinal &&
        other.tiempoMinutos == tiempoMinutos;
  }

  @override
  int get hashCode => Object.hash(
        id,
        sesionId,
        tareaId,
        usuarioAsignadoInicial,
        usuarioAsignadoFinal,
        tiempoMinutos,
      );

  @override
  String toString() =>
      'ItemRepartoModel(id: $id, tareaId: $tareaId, asignado: $usuarioAsignadoFinal, minutos: $tiempoMinutos)';
}
