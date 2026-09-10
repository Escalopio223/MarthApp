import 'profile_model.dart';

/// Representa una solicitud o relación de amistad en `friend_requests`
class FriendRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime createdAt;
  final ProfileModel? senderProfile;
  final ProfileModel? receiverProfile;

  const FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.senderProfile,
    this.receiverProfile,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory FriendRequestModel.fromJson(
    Map<String, dynamic> json, {
    ProfileModel? senderProfile,
    ProfileModel? receiverProfile,
  }) {
    return FriendRequestModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      senderProfile: senderProfile ??
          (json['sender'] != null && json['sender'] is Map<String, dynamic>
              ? ProfileModel.fromJson(json['sender'] as Map<String, dynamic>)
              : null),
      receiverProfile: receiverProfile ??
          (json['receiver'] != null && json['receiver'] is Map<String, dynamic>
              ? ProfileModel.fromJson(json['receiver'] as Map<String, dynamic>)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FriendRequestModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? status,
    DateTime? createdAt,
    ProfileModel? senderProfile,
    ProfileModel? receiverProfile,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      senderProfile: senderProfile ?? this.senderProfile,
      receiverProfile: receiverProfile ?? this.receiverProfile,
    );
  }
}
