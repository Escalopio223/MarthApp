import 'package:flutter/foundation.dart';
import 'recipe_ingredient_model.dart';

/// Modelo de Receta culinaria (Catálogo global o receta casera de un entorno)
@immutable
class RecipeModel {
  final String id;
  final String title;
  final String country;
  final String cuisineType;
  final String? prepOven;
  final String? prepAirfryer;
  final String? prepMicrowave;
  final bool isGlobal;
  final String? environmentId;
  final DateTime createdAt;
  final List<RecipeIngredientModel> ingredients;

  const RecipeModel({
    required this.id,
    required this.title,
    this.country = 'España',
    this.cuisineType = 'Mediterránea',
    this.prepOven,
    this.prepAirfryer,
    this.prepMicrowave,
    this.isGlobal = true,
    this.environmentId,
    required this.createdAt,
    this.ingredients = const [],
  });

  bool get hasAirfryer => prepAirfryer != null && prepAirfryer!.trim().isNotEmpty;
  bool get hasOven => prepOven != null && prepOven!.trim().isNotEmpty;
  bool get hasMicrowave => prepMicrowave != null && prepMicrowave!.trim().isNotEmpty;

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    List<RecipeIngredientModel> parsedIngredients = [];
    if (json['recipe_ingredients'] is List) {
      parsedIngredients = (json['recipe_ingredients'] as List)
          .map((i) => RecipeIngredientModel.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList();
    }

    return RecipeModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Sin título',
      country: json['country'] as String? ?? 'España',
      cuisineType: json['cuisine_type'] as String? ?? 'Mediterránea',
      prepOven: json['prep_oven'] as String?,
      prepAirfryer: json['prep_airfryer'] as String?,
      prepMicrowave: json['prep_microwave'] as String?,
      isGlobal: json['is_global'] as bool? ?? true,
      environmentId: json['environment_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      ingredients: parsedIngredients,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'title': title,
      'country': country,
      'cuisine_type': cuisineType,
      'prep_oven': prepOven,
      'prep_airfryer': prepAirfryer,
      'prep_microwave': prepMicrowave,
      'is_global': isGlobal,
      'environment_id': environmentId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RecipeModel copyWith({
    String? id,
    String? title,
    String? country,
    String? cuisineType,
    String? prepOven,
    String? prepAirfryer,
    String? prepMicrowave,
    bool? isGlobal,
    String? environmentId,
    DateTime? createdAt,
    List<RecipeIngredientModel>? ingredients,
  }) {
    return RecipeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      country: country ?? this.country,
      cuisineType: cuisineType ?? this.cuisineType,
      prepOven: prepOven ?? this.prepOven,
      prepAirfryer: prepAirfryer ?? this.prepAirfryer,
      prepMicrowave: prepMicrowave ?? this.prepMicrowave,
      isGlobal: isGlobal ?? this.isGlobal,
      environmentId: environmentId ?? this.environmentId,
      createdAt: createdAt ?? this.createdAt,
      ingredients: ingredients ?? this.ingredients,
    );
  }
}
