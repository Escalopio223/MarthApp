import 'package:flutter/foundation.dart';

/// Elemento individual de una lista de comprobación (checklist) dentro de una tarea.
@immutable
class ChecklistItemModel {
  final String id;
  final String titulo;
  final bool completado;

  const ChecklistItemModel({
    required this.id,
    required this.titulo,
    this.completado = false,
  });

  ChecklistItemModel copyWith({
    String? id,
    String? titulo,
    bool? completado,
  }) {
    return ChecklistItemModel(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      completado: completado ?? this.completado,
    );
  }

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      completado: json['completado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'completado': completado,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChecklistItemModel &&
        other.id == id &&
        other.titulo == titulo &&
        other.completado == completado;
  }

  @override
  int get hashCode => Object.hash(id, titulo, completado);

  @override
  String toString() =>
      'ChecklistItemModel(id: $id, titulo: $titulo, completado: $completado)';
}
