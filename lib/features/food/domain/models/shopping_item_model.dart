class ShoppingItemModel {
  final String id;
  final String environmentId;
  final String name;
  final bool isChecked;
  final String? categoryOrSource;
  final String? dishId;
  final String? createdBy;
  final DateTime createdAt;

  const ShoppingItemModel({
    required this.id,
    required this.environmentId,
    required this.name,
    this.isChecked = false,
    this.categoryOrSource,
    this.dishId,
    this.createdBy,
    required this.createdAt,
  });

  factory ShoppingItemModel.fromJson(Map<String, dynamic> json) {
    return ShoppingItemModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isChecked: json['is_checked'] as bool? ?? false,
      categoryOrSource: json['category_or_source'] as String?,
      dishId: json['dish_id'] as String?,
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
      'is_checked': isChecked,
      'category_or_source': categoryOrSource?.trim(),
      'dish_id': dishId,
      'created_by': createdBy,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  ShoppingItemModel copyWith({
    String? id,
    String? environmentId,
    String? name,
    bool? isChecked,
    String? categoryOrSource,
    String? dishId,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      name: name ?? this.name,
      isChecked: isChecked ?? this.isChecked,
      categoryOrSource: categoryOrSource ?? this.categoryOrSource,
      dishId: dishId ?? this.dishId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

