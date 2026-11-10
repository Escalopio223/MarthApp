class DishModel {
  final String id;
  final String environmentId;
  final String name;
  final int defaultServings;
  final List<String> ingredients;
  final String? createdBy;
  final DateTime createdAt;

  const DishModel({
    required this.id,
    required this.environmentId,
    required this.name,
    this.defaultServings = 2,
    this.ingredients = const [],
    this.createdBy,
    required this.createdAt,
  });

  factory DishModel.fromJson(Map<String, dynamic> json) {
    List<String> parseIngredients(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return DishModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      defaultServings: (json['default_servings'] as num?)?.toInt() ?? 2,
      ingredients: parseIngredients(json['ingredients']),
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
    String? createdBy,
    DateTime? createdAt,
  }) {
    return DishModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      name: name ?? this.name,
      defaultServings: defaultServings ?? this.defaultServings,
      ingredients: ingredients ?? this.ingredients,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
