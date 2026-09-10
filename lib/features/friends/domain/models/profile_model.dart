/// Modelo que representa el perfil de un usuario en la tabla `profiles` de Supabase
class ProfileModel {
  final String id;
  final String username;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Usuario',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username;

  @override
  int get hashCode => id.hashCode ^ username.hashCode;
}
