import 'package:flutter/material.dart';

/// Categorías taxonómicas oficiales para ingredientes y listas de compras
enum FoodCategorySlug {
  dairy,
  fruit,
  vegetable,
  meat,
  fish,
  grain,
  bakery,
  snack,
  cleaning;

  static FoodCategorySlug fromString(String slug) {
    return FoodCategorySlug.values.firstWhere(
      (e) => e.name.toLowerCase() == slug.toLowerCase(),
      orElse: () => FoodCategorySlug.vegetable,
    );
  }

  String get displayName {
    switch (this) {
      case FoodCategorySlug.dairy:
        return 'Lácteos y Derivados';
      case FoodCategorySlug.fruit:
        return 'Frutas';
      case FoodCategorySlug.vegetable:
        return 'Verduras y Hortalizas';
      case FoodCategorySlug.meat:
        return 'Carnes y Aves';
      case FoodCategorySlug.fish:
        return 'Pescados y Mariscos';
      case FoodCategorySlug.grain:
        return 'Cereales y Legumbres';
      case FoodCategorySlug.bakery:
        return 'Panadería y Masas';
      case FoodCategorySlug.snack:
        return 'Snacks y Dulces';
      case FoodCategorySlug.cleaning:
        return 'Limpieza y Hogar';
    }
  }

  IconData get iconData {
    switch (this) {
      case FoodCategorySlug.dairy:
        return Icons.local_drink_rounded;
      case FoodCategorySlug.fruit:
        return Icons.eco_rounded;
      case FoodCategorySlug.vegetable:
        return Icons.spa_rounded;
      case FoodCategorySlug.meat:
        return Icons.kebab_dining_rounded;
      case FoodCategorySlug.fish:
        return Icons.set_meal_rounded;
      case FoodCategorySlug.grain:
        return Icons.grain_rounded;
      case FoodCategorySlug.bakery:
        return Icons.bakery_dining_rounded;
      case FoodCategorySlug.snack:
        return Icons.cookie_rounded;
      case FoodCategorySlug.cleaning:
        return Icons.cleaning_services_rounded;
    }
  }

  Color get color {
    switch (this) {
      case FoodCategorySlug.dairy:
        return const Color(0xFF38BDF8); // Celeste
      case FoodCategorySlug.fruit:
        return const Color(0xFFF97316); // Naranja
      case FoodCategorySlug.vegetable:
        return const Color(0xFF10B981); // Verde Esmeralda
      case FoodCategorySlug.meat:
        return const Color(0xFFEF4444); // Rojo Coral
      case FoodCategorySlug.fish:
        return const Color(0xFF06B6D4); // Cian
      case FoodCategorySlug.grain:
        return const Color(0xFFEAB308); // Ámbar / Dorado
      case FoodCategorySlug.bakery:
        return const Color(0xFFD97706); // Caramelo
      case FoodCategorySlug.snack:
        return const Color(0xFFEC4899); // Rosa / Frambuesa
      case FoodCategorySlug.cleaning:
        return const Color(0xFF8B5CF6); // Púrpura
    }
  }
}

/// Modelo de categoría de alimentos
@immutable
class FoodCategoryModel {
  final String id;
  final String name;
  final FoodCategorySlug iconSlug;
  final DateTime createdAt;

  const FoodCategoryModel({
    required this.id,
    required this.name,
    required this.iconSlug,
    required this.createdAt,
  });

  factory FoodCategoryModel.fromJson(Map<String, dynamic> json) {
    return FoodCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      iconSlug: FoodCategorySlug.fromString(json['icon_slug'] as String? ?? 'vegetable'),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_slug': iconSlug.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FoodCategoryModel copyWith({
    String? id,
    String? name,
    FoodCategorySlug? iconSlug,
    DateTime? createdAt,
  }) {
    return FoodCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconSlug: iconSlug ?? this.iconSlug,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
