import 'package:flutter/foundation.dart';
import 'leisure_media_type.dart';

/// Modelo inmutable de una coincidencia mutua ("Watch Party Match") en un entorno
@immutable
class LeisureEnvironmentMatchModel {
  final String id;
  final String environmentId;
  final String mediaId;
  final LeisureMediaType mediaType;
  final String title;
  final List<String> matchedUserIds;
  final DateTime createdAt;

  const LeisureEnvironmentMatchModel({
    required this.id,
    required this.environmentId,
    required this.mediaId,
    required this.mediaType,
    required this.title,
    this.matchedUserIds = const [],
    required this.createdAt,
  });

  factory LeisureEnvironmentMatchModel.fromJson(Map<String, dynamic> json) {
    final rawUserIds = json['matched_user_ids'];
    final List<String> parsedUserIds = rawUserIds is List
        ? rawUserIds.map((e) => e.toString()).toList()
        : <String>[];

    return LeisureEnvironmentMatchModel(
      id: json['id'] as String? ?? '',
      environmentId: json['environment_id'] as String? ?? '',
      mediaId: json['media_id'] as String? ?? '',
      mediaType: LeisureMediaType.fromValue(json['media_type'] as String?),
      title: json['title'] as String? ?? 'Sin título',
      matchedUserIds: parsedUserIds,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'environment_id': environmentId,
      'media_id': mediaId,
      'media_type': mediaType.toValue(),
      'title': title,
      'matched_user_ids': matchedUserIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LeisureEnvironmentMatchModel copyWith({
    String? id,
    String? environmentId,
    String? mediaId,
    LeisureMediaType? mediaType,
    String? title,
    List<String>? matchedUserIds,
    DateTime? createdAt,
  }) {
    return LeisureEnvironmentMatchModel(
      id: id ?? this.id,
      environmentId: environmentId ?? this.environmentId,
      mediaId: mediaId ?? this.mediaId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      matchedUserIds: matchedUserIds ?? this.matchedUserIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeisureEnvironmentMatchModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'LeisureEnvironmentMatchModel(id: $id, mediaId: $mediaId, title: $title, matches: ${matchedUserIds.length})';
}
