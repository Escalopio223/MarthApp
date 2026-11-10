class DishModel {
  final String id;
  final String environmentId;
  final String name;
  final int defaultServings;
  final List<String> ingredients;
  final String? cuisine;              // ej. "Española", "Italiana", "Turca", "Mexicana", "Asiática", "Internacional"
  final String? servingTemperature;   // "frío" o "caliente"
  final List<String> supportedAppliances; // ['airfryer', 'oven', 'microwave', 'stovetop']
  final int? totalTimeMinutes;
  final bool isGlobal;
  final String? createdBy;
  final DateTime createdAt;

  const DishModel({
    required this.id,
    required this.environmentId,
    required this.name,
    this.defaultServings = 2,
    this.ingredients = const [],
    this.cuisine,
    this.servingTemperature,
    this.supportedAppliances = const [],
    this.totalTimeMinutes,
    this.isGlobal = false,
    this.createdBy,
    required this.createdAt,
  });

  factory DishModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    final rawIngredients = json['shopping_ingredients'] ?? json['ingredients'];

    return DishModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      name: (json['title'] ?? json['name'] ?? '') as String,
      defaultServings: (json['default_servings'] as num?)?.toInt() ?? 2,
      ingredients: parseList(rawIngredients),
      cuisine: json['cuisine'] as String?,
      servingTemperature: json['serving_temperature'] as String?,
      supportedAppliances: parseList(json['supported_appliances']),
      totalTimeMinutes: (json['total_time_minutes'] as num?)?.toInt(),
      isGlobal: json['is_global'] as bool? ?? (json['environment_id'] == null || (json['environment_id'] as String).isEmpty),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'environment_id': environmentId,
      'name': name.trim(),
      'default_servings': defaultServings,
      'ingredients': ingredients.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'cuisine': cuisine,
      'serving_temperature': servingTemperature,
      'supported_appliances': supportedAppliances,
      'total_time_minutes': totalTimeMinutes,
      'created_by': createdBy,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  DishModel copyWith({
    String? id,
    String? environmentId,
    String? name,
    int? defaultServings,
    List<String>? ingredients,
    String? cuisine,
    String? servingTemperature,
    List<String>? supportedAppliances,
    int? totalTimeMinutes,
    bool? isGlobal,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return DishModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      name: name ?? this.name,
      defaultServings: defaultServings ?? this.defaultServings,
      ingredients: ingredients ?? this.ingredients,
      cuisine: cuisine ?? this.cuisine,
      servingTemperature: servingTemperature ?? this.servingTemperature,
      supportedAppliances: supportedAppliances ?? this.supportedAppliances,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      isGlobal: isGlobal ?? this.isGlobal,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
