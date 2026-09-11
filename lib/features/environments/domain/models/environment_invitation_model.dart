import 'package:flutter/foundation.dart';

/// Modelo inmutable de una invitación a un entorno de trabajo
@immutable
class EnvironmentInvitationModel {
  final String id;
  final String environmentId;
  final String environmentName;
  final String senderId;
  final String senderUsername;
  final String receiverId;
  final String status;
  final DateTime createdAt;

  const EnvironmentInvitationModel({
    required this.id,
    required this.environmentId,
    required this.environmentName,
    required this.senderId,
    required this.senderUsername,
    required this.receiverId,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory EnvironmentInvitationModel.fromJson(Map<String, dynamic> json) {
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
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
