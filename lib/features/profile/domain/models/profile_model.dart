import 'avatar_data.dart';

/// Modelo de dominio que representa el perfil de un usuario en MarthApp
class ProfileModel {
  final String id;
  final String username;
  final AvatarData avatarData;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.username,
    this.avatarData = const AvatarData.initials(),
    required this.updatedAt,
  });

  AvatarType get avatarType => avatarData.type;
  String? get avatarUrl => avatarData.imageUrl;
  String? get avatarIcon => avatarData.iconKey;
  String? get avatarBgColor => avatarData.bgColorHex;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Usuario',
      avatarData: AvatarData.fromDb(
        typeStr: json['avatar_type'] as String?,
        url: json['avatar_url'] as String?,
        icon: json['avatar_icon'] as String?,
        bgColor: json['avatar_bg_color'] as String?,
      ),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      ...avatarData.toDbMap(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    AvatarData? avatarData,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarData: avatarData ?? this.avatarData,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          avatarData == other.avatarData;

  @override
  int get hashCode => id.hashCode ^ username.hashCode ^ avatarData.hashCode;
}
