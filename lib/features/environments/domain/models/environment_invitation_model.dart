import 'package:flutter/foundation.dart';
import '../../../profile/domain/models/avatar_data.dart';
import 'environment_member_model.dart';

/// Modelo inmutable de una invitación a un entorno de trabajo
@immutable
class EnvironmentInvitationModel {
  final String id;
  final String environmentId;
  final String environmentName;
  final String senderId;
  final String senderUsername;
  final AvatarData senderAvatarData;
  final List<EnvironmentMemberModel> members;
  final String receiverId;
  final String status;
  final DateTime createdAt;

  const EnvironmentInvitationModel({
    required this.id,
    required this.environmentId,
    required this.environmentName,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatarData = const AvatarData.initials(),
    this.members = const [],
    required this.receiverId,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  /// Lista de otros integrantes del entorno (excluyendo al remitente/anfitrión)
  List<EnvironmentMemberModel> get otherMembers =>
      members.where((m) => m.userId != senderId).toList();

  factory EnvironmentInvitationModel.fromJson(Map<String, dynamic> json) {
    AvatarData parseSenderAvatar() {
      if (json['sender_avatar'] != null && json['sender_avatar'] is Map) {
        final m = Map<String, dynamic>.from(json['sender_avatar'] as Map);
        return AvatarData.fromDb(
          typeStr: m['avatar_type'] as String?,
          url: m['avatar_url'] as String?,
          icon: m['avatar_icon'] as String?,
          bgColor: m['avatar_bg_color'] as String?,
        );
      }
      if (json['sender_profile'] != null && json['sender_profile'] is Map) {
        final m = Map<String, dynamic>.from(json['sender_profile'] as Map);
        return AvatarData.fromDb(
          typeStr: m['avatar_type'] as String?,
          url: m['avatar_url'] as String?,
          icon: m['avatar_icon'] as String?,
          bgColor: m['avatar_bg_color'] as String?,
        );
      }
      return AvatarData.fromDb(
        typeStr: json['sender_avatar_type'] as String?,
        url: json['sender_avatar_url'] as String?,
        icon: json['sender_avatar_icon'] as String?,
        bgColor: json['sender_avatar_bg_color'] as String?,
      );
    }

    List<EnvironmentMemberModel> parseMembers() {
      final rawList = json['members'] ?? json['environment_members'];
      if (rawList != null && rawList is List) {
        return rawList
            .map((item) => EnvironmentMemberModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return const [];
    }

    return EnvironmentInvitationModel(
      id: json['id'] as String,
      environmentId: json['environment_id'] as String? ?? '',
      environmentName: json['environment_name'] as String? ??
          (json['environments'] != null && json['environments'] is Map
              ? (json['environments']['name'] as String? ?? 'Entorno')
              : 'Entorno'),
      senderId: json['sender_id'] as String? ?? '',
      senderUsername: json['sender_username'] as String? ??
          (json['sender_profile'] != null && json['sender_profile'] is Map
              ? (json['sender_profile']['username'] as String? ?? 'Amigo')
              : 'Amigo'),
      senderAvatarData: parseSenderAvatar(),
      members: parseMembers(),
      receiverId: json['receiver_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'environment_id': environmentId,
      'environment_name': environmentName,
      'sender_id': senderId,
      'sender_username': senderUsername,
      'sender_avatar_type': senderAvatarData.type.name,
      'sender_avatar_url': senderAvatarData.imageUrl,
      'sender_avatar_icon': senderAvatarData.iconKey,
      'sender_avatar_bg_color': senderAvatarData.bgColorHex,
      'members': members.map((m) => m.toJson()).toList(),
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  EnvironmentInvitationModel copyWith({
    String? id,
    String? environmentId,
    String? environmentName,
    String? senderId,
    String? senderUsername,
    AvatarData? senderAvatarData,
    List<EnvironmentMemberModel>? members,
    String? receiverId,
    String? status,
    DateTime? createdAt,
  }) {
    return EnvironmentInvitationModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      environmentName: environmentName ?? this.environmentName,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderAvatarData: senderAvatarData ?? this.senderAvatarData,
      members: members ?? this.members,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentInvitationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          environmentId == other.environmentId &&
          senderId == other.senderId &&
          status == other.status &&
          members.length == other.members.length;

  @override
  int get hashCode => Object.hash(id, environmentId, senderId, status);
}
