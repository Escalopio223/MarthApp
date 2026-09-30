import 'package:flutter/foundation.dart';
import 'saved_weekly_menu_slot_model.dart';

/// Modelo de Menú Semanal guardado en la biblioteca del entorno
@immutable
class SavedWeeklyMenuModel {
  final String id;
  final String environmentId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<SavedWeeklyMenuSlotModel> slots;

  const SavedWeeklyMenuModel({
    required this.id,
    required this.environmentId,
    required this.name,
    this.description,
    required this.createdAt,
    this.slots = const [],
  });

  factory SavedWeeklyMenuModel.fromJson(Map<String, dynamic> json) {
    List<SavedWeeklyMenuSlotModel> parsedSlots = [];
    if (json['saved_weekly_menu_slots'] is List) {
      parsedSlots = (json['saved_weekly_menu_slots'] as List)
          .map((s) => SavedWeeklyMenuSlotModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    }

    return SavedWeeklyMenuModel(
      id: json['id'] as String,
      environmentId: json['environment_id'] as String,
      name: json['name'] as String? ?? 'Menú sin nombre',
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      slots: parsedSlots,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'environment_id': environmentId,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SavedWeeklyMenuModel copyWith({
    String? id,
    String? environmentId,
    String? name,
    String? description,
    DateTime? createdAt,
    List<SavedWeeklyMenuSlotModel>? slots,
  }) {
    return SavedWeeklyMenuModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      slots: slots ?? this.slots,
    );
  }
}
