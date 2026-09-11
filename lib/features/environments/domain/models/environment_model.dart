import 'package:flutter/foundation.dart';

/// Modelo inmutable representativo de un entorno de trabajo (Workspace)
@immutable
class EnvironmentModel {
  static const String allId = '__all__';

  final String id;
  final String name;
  final bool isPersonal;
  final String createdBy;
  final DateTime createdAt;
  final String role;
  final int memberCount;

  const EnvironmentModel({
    required this.id,
    required this.name,
    this.isPersonal = false,
    required this.createdBy,
    required this.createdAt,
    this.role = 'member',
    this.memberCount = 1,
  });

  /// Pseudo-entorno global "Todos"
  factory EnvironmentModel.all() {
    return EnvironmentModel(
      id: allId,
      name: 'Todos los entornos',
      isPersonal: false,
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      role: 'member',
      memberCount: 0,
    );
  }

  bool get isAll => id == allId;
  bool get isOwner => role == 'owner';

  factory EnvironmentModel.fromJson(Map<String, dynamic> json, {String? userRole}) {
    return EnvironmentModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sin nombre',
      isPersonal: json['is_personal'] as bool? ?? false,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      role: userRole ?? (json['role'] as String? ?? 'member'),
      memberCount: json['member_count'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_personal': isPersonal,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'role': role,
      'member_count': memberCount,
    };
  }

  EnvironmentModel copyWith({
    String? id,
    String? name,
    bool? isPersonal,
    String? createdBy,
    DateTime? createdAt,
    String? role,
    int? memberCount,
  }) {
    return EnvironmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isPersonal: isPersonal ?? this.isPersonal,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EnvironmentModel(id: $id, name: $name, isPersonal: $isPersonal, role: $role)';
}
