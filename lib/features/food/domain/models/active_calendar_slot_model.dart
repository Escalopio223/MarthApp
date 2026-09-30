import 'package:flutter/foundation.dart';
import 'recipe_model.dart';
import 'saved_weekly_menu_slot_model.dart';

/// Ranura de comida en el calendario semanal activo del entorno
@immutable
class ActiveCalendarSlotModel {
  final String id;
  final String environmentId;
  final DateTime date;
  final MealType mealType;
  final SlotItemType itemType;
  final String? recipeId;
  final String? customName;
  final RecipeModel? recipe;

  const ActiveCalendarSlotModel({
    required this.id,
    required this.environmentId,
    required this.date,
    required this.mealType,
    required this.itemType,
    this.recipeId,
    this.customName,
    this.recipe,
  });

  String get dateString =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String get displayTitle {
    if (itemType == SlotItemType.recipe && recipe != null) {
      return recipe!.title;
    }
    return customName ?? 'Sin asignar';
  }

  factory ActiveCalendarSlotModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'] as String) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ActiveCalendarSlotModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
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
      'environment_id': environmentId,
      'date': dateString,
      'meal_type': mealType.dbValue,
      'item_type': itemType.dbValue,
      'recipe_id': recipeId,
      'custom_name': customName,
    };
  }

  ActiveCalendarSlotModel copyWith({
    String? id,
    String? environmentId,
    DateTime? date,
    MealType? mealType,
    SlotItemType? itemType,
    String? recipeId,
    String? customName,
    RecipeModel? recipe,
  }) {
    return ActiveCalendarSlotModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      itemType: itemType ?? this.itemType,
      recipeId: recipeId ?? this.recipeId,
      customName: customName ?? this.customName,
      recipe: recipe ?? this.recipe,
    );
  }
}
