import 'package:flutter/foundation.dart';
import 'leisure_media_type.dart';

/// Modelo inmutable representativo de un elemento contenido en una lista compartida
@immutable
class LeisureSharedListItemModel {
  final String id;
  final String listId;
  final String mediaId;
  final LeisureMediaType mediaType;
  final String title;
  final String? posterUrl;
  final String addedBy;
  final DateTime createdAt;

  const LeisureSharedListItemModel({
    required this.id,
    required this.listId,
    required this.mediaId,
    required this.mediaType,
    required this.title,
    this.posterUrl,
    required this.addedBy,
    required this.createdAt,
  });

  factory LeisureSharedListItemModel.fromJson(Map<String, dynamic> json) {
    return LeisureSharedListItemModel(
      id: json['id'] as String? ?? '',
      listId: json['list_id'] as String? ?? '',
      mediaId: json['media_id'] as String? ?? '',
      mediaType: LeisureMediaType.fromValue(json['media_type'] as String?),
      title: json['title'] as String? ?? 'Sin título',
      posterUrl: json['poster_url'] as String?,
      addedBy: json['added_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'list_id': listId,
      'media_id': mediaId,
      'media_type': mediaType.toValue(),
      'title': title,
      'poster_url': posterUrl,
      'added_by': addedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LeisureSharedListItemModel copyWith({
    String? id,
    String? listId,
    String? mediaId,
    LeisureMediaType? mediaType,
    String? title,
    String? posterUrl,
    String? addedBy,
    DateTime? createdAt,
  }) {
    return LeisureSharedListItemModel(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      mediaId: mediaId ?? this.mediaId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeisureSharedListItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'LeisureSharedListItemModel(id: $id, listId: $listId, mediaId: $mediaId, title: $title)';
}
