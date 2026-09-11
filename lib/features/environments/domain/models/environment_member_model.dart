import 'package:flutter/foundation.dart';
import '../../../profile/domain/models/avatar_data.dart';

/// Modelo representativo de un miembro de un entorno
@immutable
class EnvironmentMemberModel {
  final String environmentId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String username;
  final AvatarData avatarData;

  const EnvironmentMemberModel({
    required this.environmentId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.username,
    required this.avatarData,
  });

  bool get isOwner => role == 'owner';

  factory EnvironmentMemberModel.fromJson(Map<String, dynamic> json) {
    return EnvironmentMemberModel(
      environmentId: json['environment_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      username: json['username'] as String? ?? 'Usuario',
      avatarData: AvatarData.fromDb(
        typeStr: json['avatar_type'] as String?,
        url: json['avatar_url'] as String?,
        icon: json['avatar_icon'] as String?,
        bgColor: json['avatar_bg_color'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'environment_id': environmentId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'username': username,
      'avatar_type': avatarData.type.name,
      'avatar_url': avatarData.imageUrl,
      'avatar_icon': avatarData.iconKey,
      'avatar_bg_color': avatarData.bgColorHex,
    };
  }

  EnvironmentMemberModel copyWith({
    String? environmentId,
    String? userId,
    String? role,
    DateTime? joinedAt,
    String? username,
    AvatarData? avatarData,
  }) {
    return EnvironmentMemberModel(
      environmentId: environmentId ?? this.environmentId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      username: username ?? this.username,
      avatarData: avatarData ?? this.avatarData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentMemberModel &&
          runtimeType == other.runtimeType &&
          environmentId == other.environmentId &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(environmentId, userId);
}
