import 'package:flutter/foundation.dart';
import 'recipe_model.dart';

/// Tipo de comida para ranuras semanales y calendario activo
enum MealType {
  breakfast,
  midMorning,
  lunch,
  snack,
  dinner;

  static MealType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'mid_morning':
      case 'midmorning':
        return MealType.midMorning;
      case 'lunch':
        return MealType.lunch;
      case 'snack':
        return MealType.snack;
      case 'dinner':
        return MealType.dinner;
      default:
        return MealType.lunch;
    }
  }

  String get dbValue {
    switch (this) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.midMorning:
        return 'mid_morning';
      case MealType.lunch:
        return 'lunch';
      case MealType.snack:
        return 'snack';
      case MealType.dinner:
        return 'dinner';
    }
  }

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Desayuno';
      case MealType.midMorning:
        return 'Media Mañana';
      case MealType.lunch:
        return 'Comida';
      case MealType.snack:
        return 'Merienda';
      case MealType.dinner:
        return 'Cena';
    }
  }
}

/// Tipo de elemento en la ranura
enum SlotItemType {
  recipe,
  singleIngredient;

  static SlotItemType fromString(String val) {
    return val.toLowerCase() == 'single_ingredient'
        ? SlotItemType.singleIngredient
        : SlotItemType.recipe;
  }

  String get dbValue => this == SlotItemType.singleIngredient ? 'single_ingredient' : 'recipe';
}

/// Ranura dentro de una plantilla de menú semanal guardado
@immutable
class SavedWeeklyMenuSlotModel {
  final String id;
  final String savedMenuId;
  final int dayOfWeek; // 1 = Lunes, 7 = Domingo
  final MealType mealType;
  final SlotItemType itemType;
  final String? recipeId;
  final String? customName;
  final RecipeModel? recipe;

  const SavedWeeklyMenuSlotModel({
    required this.id,
    required this.savedMenuId,
    required this.dayOfWeek,
    required this.mealType,
    required this.itemType,
    this.recipeId,
    this.customName,
    this.recipe,
  });

  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Día $dayOfWeek';
    }
  }

  String get displayTitle {
    if (itemType == SlotItemType.recipe && recipe != null) {
      return recipe!.title;
    }
    return customName ?? 'Sin asignar';
  }

  factory SavedWeeklyMenuSlotModel.fromJson(Map<String, dynamic> json) {
    return SavedWeeklyMenuSlotModel(
      id: json['id'] as String? ?? '',
      savedMenuId: json['saved_menu_id'] as String? ?? '',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 1,
      mealType: MealType.fromString(json['meal_type'] as String? ?? 'lunch'),
      itemType: SlotItemType.fromString(json['item_type'] as String? ?? 'recipe'),
      recipeId: json['recipe_id'] as String?,
      customName: json['custom_name'] as String?,
      recipe: json['recipes'] != null
          ? RecipeModel.fromJson(Map<String, dynamic>.from(json['recipes'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'saved_menu_id': savedMenuId,
      'day_of_week': dayOfWeek,
      'meal_type': mealType.dbValue,
      'item_type': itemType.dbValue,
      'recipe_id': recipeId,
      'custom_name': customName,
    };
  }

  SavedWeeklyMenuSlotModel copyWith({
    String? id,
    String? savedMenuId,
    int? dayOfWeek,
    MealType? mealType,
    SlotItemType? itemType,
    String? recipeId,
    String? customName,
    RecipeModel? recipe,
  }) {
    return SavedWeeklyMenuSlotModel(
      id: id ?? this.id,
      savedMenuId: savedMenuId ?? this.savedMenuId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      mealType: mealType ?? this.mealType,
      itemType: itemType ?? this.itemType,
      recipeId: recipeId ?? this.recipeId,
      customName: customName ?? this.customName,
      recipe: recipe ?? this.recipe,
    );
  }
}
