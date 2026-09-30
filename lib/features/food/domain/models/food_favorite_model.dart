import 'package:flutter/foundation.dart';
import 'recipe_model.dart';

/// Tipo de elemento guardado en favoritos
enum FoodFavoriteType {
  recipe,
  ingredient;

  static FoodFavoriteType fromString(String val) {
    return val.toLowerCase() == 'ingredient'
        ? FoodFavoriteType.ingredient
        : FoodFavoriteType.recipe;
  }
}

/// Modelo de favoritos de cocina de un entorno
@immutable
class FoodFavoriteModel {
  final String id;
  final String environmentId;
  final FoodFavoriteType itemType;
  final String? recipeId;
  final String? ingredientName;
  final DateTime createdAt;
  final RecipeModel? recipe;

  const FoodFavoriteModel({
    required this.id,
    required this.environmentId,
    required this.itemType,
    this.recipeId,
    this.ingredientName,
    required this.createdAt,
    this.recipe,
  });

  bool get isRecipe => itemType == FoodFavoriteType.recipe;
  bool get isIngredient => itemType == FoodFavoriteType.ingredient;

  String get displayName {
    if (isRecipe && recipe != null) return recipe!.title;
    if (ingredientName != null && ingredientName!.isNotEmpty) {
      return ingredientName![0].toUpperCase() + ingredientName!.substring(1);
    }
    return 'Elemento favorito';
  }

  factory FoodFavoriteModel.fromJson(Map<String, dynamic> json) {
    return FoodFavoriteModel(
      id: json['id'] as String,
      environmentId: json['environment_id'] as String,
      itemType: FoodFavoriteType.fromString(json['item_type'] as String? ?? 'recipe'),
      recipeId: json['recipe_id'] as String?,
      ingredientName: json['ingredient_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      recipe: json['recipes'] != null
          ? RecipeModel.fromJson(Map<String, dynamic>.from(json['recipes'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'environment_id': environmentId,
      'item_type': itemType.name,
      'recipe_id': recipeId,
      'ingredient_name': ingredientName?.toLowerCase().trim(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  FoodFavoriteModel copyWith({
    String? id,
    String? environmentId,
    FoodFavoriteType? itemType,
    String? recipeId,
    String? ingredientName,
    DateTime? createdAt,
    RecipeModel? recipe,
  }) {
    return FoodFavoriteModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      itemType: itemType ?? this.itemType,
      recipeId: recipeId ?? this.recipeId,
      ingredientName: ingredientName ?? this.ingredientName,
      createdAt: createdAt ?? this.createdAt,
      recipe: recipe ?? this.recipe,
    );
  }
}
