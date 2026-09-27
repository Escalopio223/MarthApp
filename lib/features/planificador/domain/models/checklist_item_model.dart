import 'package:flutter/foundation.dart';

/// Elemento individual de una lista de comprobación (checklist o subtarea) dentro de una tarea.
@immutable
class ChecklistItemModel {
  final String id;
  final String titulo;
  final bool completado;
  final int orden;

  const ChecklistItemModel({
    required this.id,
    required this.titulo,
    this.completado = false,
    this.orden = 0,
  });

  ChecklistItemModel copyWith({
    String? id,
    String? titulo,
    bool? completado,
    int? orden,
  }) {
    return ChecklistItemModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      completado: completado ?? this.completado,
      orden: orden ?? this.orden,
    );
  }

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      completado: json['completado'] as bool? ?? false,
      orden: json['orden'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'completado': completado,
      'orden': orden,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChecklistItemModel &&
        other.id == id &&
        other.titulo == titulo &&
        other.completado == completado &&
        other.orden == orden;
  }

  @override
  int get hashCode => Object.hash(id, titulo, completado, orden);

  @override
  String toString() =>
      'ChecklistItemModel(id: $id, titulo: $titulo, completado: $completado, orden: $orden)';
}
