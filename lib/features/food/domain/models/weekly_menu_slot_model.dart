import 'dish_model.dart';

enum MealType {
  lunch,
  dinner;

  String get dbValue => name;

  String get label {
    switch (this) {
      case MealType.lunch:
        return 'Almuerzo';
      case MealType.dinner:
        return 'Cena';
    }
  }

  String get iconEmoji {
    switch (this) {
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
    }
  }

  static MealType fromDb(String value) {
    if (value == 'dinner') return MealType.dinner;
    return MealType.lunch;
  }
}

class WeeklyMenuSlotModel {
  final String id;
  final String environmentId;
  final DateTime slotDate;
  final MealType mealType;
  final String? dishId;
  final String? customDishName;
  final String? servingsNote;
  final DishModel? dish;
  final String? createdBy;
  final DateTime createdAt;

  const WeeklyMenuSlotModel({
    required this.id,
    required this.environmentId,
    required this.slotDate,
    required this.mealType,
    this.dishId,
    this.customDishName,
    this.servingsNote,
    this.dish,
    this.createdBy,
    required this.createdAt,
  });

  String get displayName {
    if (dish != null && dish!.name.isNotEmpty) {
      return dish!.name;
    }
    if (customDishName != null && customDishName!.trim().isNotEmpty) {
      return customDishName!.trim();
    }
    return '';
  }

  bool get isEmpty => displayName.isEmpty;

  factory WeeklyMenuSlotModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw) {
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DishModel? parseDish(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return DishModel.fromJson(raw);
      }
      return null;
    }

    return WeeklyMenuSlotModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      slotDate: parseDate(json['slot_date']),
      mealType: MealType.fromDb(json['meal_type'] as String? ?? 'lunch'),
      dishId: json['dish_id'] as String?,
      customDishName: json['custom_dish_name'] as String?,
      servingsNote: json['servings_note'] as String?,
      dish: parseDish(json['dishes']),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final dateStr =
        '${slotDate.year.toString().padLeft(4, '0')}-${slotDate.month.toString().padLeft(2, '0')}-${slotDate.day.toString().padLeft(2, '0')}';
    final map = <String, dynamic>{
      'environment_id': environmentId,
      'slot_date': dateStr,
      'meal_type': mealType.dbValue,
      'dish_id': dishId,
      'custom_dish_name': customDishName,
      'servings_note': servingsNote,
      'created_by': createdBy,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  WeeklyMenuSlotModel copyWith({
    String? id,
    String? environmentId,
    DateTime? slotDate,
    MealType? mealType,
    String? dishId,
    String? customDishName,
    String? servingsNote,
    DishModel? dish,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return WeeklyMenuSlotModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      slotDate: slotDate ?? this.slotDate,
      mealType: mealType ?? this.mealType,
      dishId: dishId ?? this.dishId,
      customDishName: customDishName ?? this.customDishName,
      servingsNote: servingsNote ?? this.servingsNote,
      dish: dish ?? this.dish,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

