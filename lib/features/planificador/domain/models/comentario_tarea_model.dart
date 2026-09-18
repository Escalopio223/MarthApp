import 'package:flutter/foundation.dart';

/// Modelo inmutable de un comentario dentro de una tarea del Planificador.
@immutable
class ComentarioTareaModel {
  final String id;
  final String autorId;
  final String autorNombre;
  final String texto;
  final DateTime createdAt;

  const ComentarioTareaModel({
    required this.id,
    required this.autorId,
    required this.autorNombre,
    required this.texto,
    required this.createdAt,
  });

  ComentarioTareaModel copyWith({
    String? id,
    String? autorId,
    String? autorNombre,
    String? texto,
    DateTime? createdAt,
  }) {
    return ComentarioTareaModel(
      id: id ?? this.id,
      autorId: autorId ?? this.autorId,
      autorNombre: autorNombre ?? this.autorNombre,
      texto: texto ?? this.texto,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ComentarioTareaModel.fromJson(Map<String, dynamic> json) {
    return ComentarioTareaModel(
      id: json['id'] as String? ?? '',
      autorId: json['autor_id'] as String? ??
          json['usuario_id'] as String? ??
          '',
      autorNombre: json['autor_nombre'] as String? ?? 'Usuario',
      texto: json['texto'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'autor_id': autorId,
      'autor_nombre': autorNombre,
      'texto': texto,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComentarioTareaModel &&
        other.id == id &&
        other.autorId == autorId &&
        other.texto == texto &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, autorId, texto, createdAt);

  @override
  String toString() =>
      'ComentarioTareaModel(id: $id, autorNombre: $autorNombre, texto: $texto)';
}
