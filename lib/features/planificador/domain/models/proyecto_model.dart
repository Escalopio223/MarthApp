import 'package:flutter/foundation.dart';

/// Modelo inmutable de un Proyecto dentro del Planificador (tabla `planificador_proyectos`).
@immutable
class ProyectoModel {
  final String id;
  final String entornoId;
  final String nombre;
  final String? descripcion;
  final String icono;
  final String colorHex;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProyectoModel({
    required this.id,
    required this.entornoId,
    required this.nombre,
    this.descripcion,
    this.icono = 'folder',
    this.colorHex = '#6366F1',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  ProyectoModel copyWith({
    String? id,
    String? entornoId,
    String? nombre,
    String? descripcion,
    String? icono,
    String? colorHex,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProyectoModel(
      id: id ?? this.id,
      entornoId: entornoId ?? this.entornoId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      icono: icono ?? this.icono,
      colorHex: colorHex ?? this.colorHex,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProyectoModel.fromJson(Map<String, dynamic> json) {
    return ProyectoModel(
      id: json['id'] as String? ?? '',
      entornoId: json['entorno_id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      icono: json['icono'] as String? ?? 'folder',
      colorHex: json['color_hex'] as String? ?? '#6366F1',
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entorno_id': entornoId,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'icono': icono,
      'color_hex': colorHex,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProyectoModel &&
        other.id == id &&
        other.entornoId == entornoId &&
        other.nombre == nombre &&
        other.descripcion == descripcion &&
        other.icono == icono &&
        other.colorHex == colorHex &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        entornoId,
        nombre,
        descripcion,
        icono,
        colorHex,
        createdBy,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'ProyectoModel(id: $id, entornoId: $entornoId, nombre: $nombre, icono: $icono, colorHex: $colorHex)';
}
