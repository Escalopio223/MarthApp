import 'package:flutter/foundation.dart';
import 'item_reparto_model.dart';

/// Modelo inmutable que representa una sesión de reparto equitativo de tareas (tabla `planificador_repartos_sesiones`).
@immutable
class SesionRepartoModel {
  final String id;
  final String entornoId;
  final DateTime fechaSesion;
  final List<String> usuariosParticipantes;
  final int minutosTotales;
  final List<ItemRepartoModel> items;
  final String estado; // 'borrador' | 'completado'
  final DateTime createdAt;

  const SesionRepartoModel({
    required this.id,
    required this.entornoId,
    required this.fechaSesion,
    required this.usuariosParticipantes,
    this.minutosTotales = 0,
    this.items = const [],
    this.estado = 'completado',
    required this.createdAt,
  });

  SesionRepartoModel copyWith({
    String? id,
    String? entornoId,
    DateTime? fechaSesion,
    List<String>? usuariosParticipantes,
    int? minutosTotales,
    List<ItemRepartoModel>? items,
    String? estado,
    DateTime? createdAt,
  }) {
    return SesionRepartoModel(
      id: id ?? this.id,
      entornoId: entornoId ?? this.entornoId,
      fechaSesion: fechaSesion ?? this.fechaSesion,
      usuariosParticipantes:
          usuariosParticipantes ?? this.usuariosParticipantes,
      minutosTotales: minutosTotales ?? this.minutosTotales,
      items: items ?? this.items,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SesionRepartoModel.fromJson(Map<String, dynamic> json) {
    final rawParticipantes = json['usuarios_participantes'];
    final List<String> participantes = rawParticipantes is List
        ? rawParticipantes.map((e) => e.toString()).toList()
        : const [];

    final rawItems = json['items'];
    final List<ItemRepartoModel> itemsList = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(ItemRepartoModel.fromJson)
            .toList()
        : const [];

    return SesionRepartoModel(
      id: json['id'] as String? ?? '',
      entornoId: json['entorno_id'] as String? ?? '',
      fechaSesion: json['fecha_sesion'] != null
          ? DateTime.tryParse(json['fecha_sesion'].toString()) ?? DateTime.now()
          : DateTime.now(),
      usuariosParticipantes: participantes,
      minutosTotales: json['minutos_totales'] is int
          ? json['minutos_totales'] as int
          : int.tryParse(json['minutos_totales']?.toString() ?? '') ?? 0,
      items: itemsList,
      estado: json['estado'] as String? ?? 'completado',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entorno_id': entornoId,
      'fecha_sesion': fechaSesion.toIso8601String().split('T').first,
      'usuarios_participantes': usuariosParticipantes,
      'minutos_totales': minutosTotales,
      'items': items.map((i) => i.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SesionRepartoModel &&
        other.id == id &&
        other.entornoId == entornoId &&
        other.fechaSesion == fechaSesion &&
        listEquals(other.usuariosParticipantes, usuariosParticipantes) &&
        other.minutosTotales == minutosTotales &&
        listEquals(other.items, items) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        entornoId,
        fechaSesion,
        Object.hashAll(usuariosParticipantes),
        minutosTotales,
        Object.hashAll(items),
        createdAt,
      );

  @override
  String toString() =>
      'SesionRepartoModel(id: $id, entornoId: $entornoId, minutosTotales: $minutosTotales, items: ${items.length})';
}
