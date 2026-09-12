import 'package:flutter/foundation.dart';

/// Modelo inmutable de una lista temática compartida dentro de un entorno
@immutable
class LeisureSharedListModel {
  final String id;
  final String environmentId;
  final String createdBy;
  final String title;
  final String? description;
  final DateTime createdAt;
  final int itemsCount;

  const LeisureSharedListModel({
    required this.id,
    required this.environmentId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.createdAt,
    this.itemsCount = 0,
  });

  factory LeisureSharedListModel.fromJson(Map<String, dynamic> json) {
    return LeisureSharedListModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? '',
      title: json['title'] as String? ?? 'Lista sin título',
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      itemsCount: json['items_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'environment_id': environmentId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'items_count': itemsCount,
    };
  }

  LeisureSharedListModel copyWith({
    String? id,
    String? environmentId,
    String? createdBy,
    String? title,
    String? description,
    DateTime? createdAt,
    int? itemsCount,
  }) {
    return LeisureSharedListModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      itemsCount: itemsCount ?? this.itemsCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeisureSharedListModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'LeisureSharedListModel(id: $id, environmentId: $environmentId, title: $title, itemsCount: $itemsCount)';
}
