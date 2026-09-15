import 'package:flutter/material.dart';

/// Helper estético para iconos temáticos y paleta de colores de entornos
class EnvironmentThemeHelper {
  static const Map<String, IconData> availableIcons = {
    'groups': Icons.groups_rounded,
    'home': Icons.home_rounded,
    'work': Icons.work_rounded,
    'movie': Icons.movie_filter_rounded,
    'game': Icons.sports_esports_rounded,
    'book': Icons.auto_stories_rounded,
    'heart': Icons.favorite_rounded,
    'rocket': Icons.rocket_launch_rounded,
    'school': Icons.school_rounded,
    'music': Icons.music_note_rounded,
    'sports': Icons.sports_soccer_rounded,
    'travel': Icons.flight_takeoff_rounded,
    'party': Icons.celebration_rounded,
    'ideas': Icons.lightbulb_rounded,
    'coffee': Icons.coffee_rounded,
    'pets': Icons.pets_rounded,
  };

  static const List<String> availableColors = [
    '#06B6D4', // Cian
    '#10B981', // Esmeralda
    '#6366F1', // Índigo
    '#8B5CF6', // Púrpura
    '#EC4899', // Fucsia
    '#FF5E7E', // Coral
    '#F59E0B', // Ámbar
    '#EF4444', // Rojo
    '#38BDF8', // Azul Cielo
    '#84CC16', // Lima
  ];

  static IconData resolveIcon(String? iconKey, {bool isPersonal = false}) {
    if (iconKey != null && availableIcons.containsKey(iconKey)) {
      return availableIcons[iconKey]!;
    }
    return isPersonal ? Icons.person_pin_rounded : Icons.groups_rounded;
  }

  static Color resolveColor(String? colorHex, {bool isPersonal = false}) {
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        final hex = colorHex.replaceAll('#', '');
        return Color(int.parse('0xFF$hex'));
      } catch (_) {}
    }
    return isPersonal ? const Color(0xFF06B6D4) : const Color(0xFF10B981);
  }
}

/// Modelo inmutable representativo de un entorno de trabajo (Workspace)
@immutable
class EnvironmentModel {
  static const String allId = '__all__';

  final String id;
  final String name;
  final bool isPersonal;
  final String createdBy;
  final DateTime createdAt;
  final String role;
  final int memberCount;
  final String? icon;
  final String? color;

  const EnvironmentModel({
    required this.id,
    required this.name,
    this.isPersonal = false,
    required this.createdBy,
    required this.createdAt,
    this.role = 'member',
    this.memberCount = 1,
    this.icon,
    this.color,
  });

  /// Pseudo-entorno global "Todos"
  factory EnvironmentModel.all() {
    return EnvironmentModel(
      id: allId,
      name: 'Todos los entornos',
      isPersonal: false,
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      role: 'member',
      memberCount: 0,
      icon: 'dashboard',
      color: '#8B5CF6',
    );
  }

  bool get isAll => id == allId;
  bool get isOwner => role == 'owner';

  /// Icono resuelto según la clave personalizada o el tipo de entorno
  IconData get iconData =>
      isAll ? Icons.dashboard_customize_rounded : EnvironmentThemeHelper.resolveIcon(icon, isPersonal: isPersonal);

  /// Color temático resuelto según el valor hexadecimal o el tipo de entorno
  Color get colorValue =>
      isAll ? const Color(0xFF8B5CF6) : EnvironmentThemeHelper.resolveColor(color, isPersonal: isPersonal);

  factory EnvironmentModel.fromJson(Map<String, dynamic> json, {String? userRole}) {
    return EnvironmentModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sin nombre',
      isPersonal: json['is_personal'] as bool? ?? false,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      role: userRole ?? (json['role'] as String? ?? 'member'),
      memberCount: json['member_count'] as int? ?? 1,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_personal': isPersonal,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'role': role,
      'member_count': memberCount,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    };
  }

  EnvironmentModel copyWith({
    String? id,
    String? name,
    bool? isPersonal,
    String? createdBy,
    DateTime? createdAt,
    String? role,
    int? memberCount,
    String? icon,
    String? color,
  }) {
    return EnvironmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isPersonal: isPersonal ?? this.isPersonal,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      memberCount: memberCount ?? this.memberCount,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'EnvironmentModel(id: $id, name: $name, isPersonal: $isPersonal, role: $role, icon: $icon, color: $color)';
}
