import 'package:flutter/foundation.dart';
import 'food_category_model.dart';

/// Ítem de la lista de la compra del entorno
@immutable
class ShoppingListItemModel {
  final String id;
  final String environmentId;
  final String name;
  final int occurrencesCount;
  final String? categoryId;
  final bool isChecked;
  final bool isManual;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FoodCategoryModel? category;

  const ShoppingListItemModel({
    required this.id,
    required this.environmentId,
    required this.name,
    this.occurrencesCount = 1,
    this.categoryId,
    this.isChecked = false,
    this.isManual = false,
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });

  String get displayName {
    if (name.isEmpty) return 'Elemento';
    return name[0].toUpperCase() + name.substring(1);
  }

  factory ShoppingListItemModel.fromJson(Map<String, dynamic> json) {
    return ShoppingListItemModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      occurrencesCount: (json['occurrences_count'] as num?)?.toInt() ?? 1,
      categoryId: json['category_id'] as String?,
      isChecked: json['is_checked'] as bool? ?? false,
      isManual: json['is_manual'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      category: json['food_categories'] != null
          ? FoodCategoryModel.fromJson(Map<String, dynamic>.from(json['food_categories'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'environment_id': environmentId,
      'name': name.toLowerCase().trim(),
      'occurrences_count': occurrencesCount,
      'category_id': categoryId,
      'is_checked': isChecked,
      'is_manual': isManual,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ShoppingListItemModel copyWith({
    String? id,
    String? environmentId,
    String? name,
    int? occurrencesCount,
    String? categoryId,
    bool? isChecked,
    bool? isManual,
    DateTime? createdAt,
    DateTime? updatedAt,
    FoodCategoryModel? category,
  }) {
    return ShoppingListItemModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      name: name ?? this.name,
      occurrencesCount: occurrencesCount ?? this.occurrencesCount,
      categoryId: categoryId ?? this.categoryId,
      isChecked: isChecked ?? this.isChecked,
      isManual: isManual ?? this.isManual,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }
}
