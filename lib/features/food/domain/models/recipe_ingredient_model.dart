import 'package:flutter/foundation.dart';
import 'food_category_model.dart';

/// Modelo representativo de un ingrediente de una receta
@immutable
class RecipeIngredientModel {
  final String id;
  final String recipeId;
  final String name;
  final String categoryId;
  final DateTime createdAt;
  final FoodCategoryModel? category;

  const RecipeIngredientModel({
    required this.id,
    required this.recipeId,
    required this.name,
    required this.categoryId,
    required this.createdAt,
    this.category,
  });

  factory RecipeIngredientModel.fromJson(Map<String, dynamic> json) {
    return RecipeIngredientModel(
      id: json['id'] as String? ?? '',
      recipeId: json['recipe_id'] as String? ?? '',
      name: (json['name'] as String? ?? '').toLowerCase().trim(),
      categoryId: json['category_id'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      category: json['food_categories'] != null
          ? FoodCategoryModel.fromJson(json['food_categories'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'recipe_id': recipeId,
      'name': name.toLowerCase().trim(),
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RecipeIngredientModel copyWith({
    String? id,
    String? recipeId,
    String? name,
    String? categoryId,
    DateTime? createdAt,
    FoodCategoryModel? category,
  }) {
    return RecipeIngredientModel(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
    );
  }
}
