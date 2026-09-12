import 'package:flutter/foundation.dart';
import 'leisure_item_status.dart';
import 'leisure_media_type.dart';

/// Modelo inmutable representativo del progreso, valoración y notas
/// personales de un usuario sobre un elemento multimedia.
@immutable
class LeisureUserItemModel {
  final String id;
  final String userId;
  final String mediaId;
  final LeisureMediaType mediaType;
  final LeisureItemStatus? status;
  final double? rating;
  final String? notes;
  final DateTime? dislikedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LeisureUserItemModel({
    required this.id,
    required this.userId,
    required this.mediaId,
    required this.mediaType,
    this.status,
    this.rating,
    this.notes,
    this.dislikedUntil,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(
          rating == null || (rating >= 1.0 && rating <= 10.0),
          'El rating debe estar comprendido entre 1.0 y 10.0',
        );

  /// Determina si el ítem está marcado como favorito
  bool get isFavorite => status == LeisureItemStatus.favorite;

  /// Determina si el ítem computa como visto (incluye 'watched' y 'favorite')
  bool get isWatched => status?.isWatched ?? false;

  /// Determina si el ítem tiene un descarte temporal activo para el swipe feed
  bool get isDisliked =>
      dislikedUntil?.isAfter(DateTime.now()) ?? false;

  factory LeisureUserItemModel.fromJson(Map<String, dynamic> json) {
    final rawRating = (json['rating'] as num?)?.toDouble();
    final clampedRating = rawRating?.clamp(1.0, 10.0).toDouble();

    return LeisureUserItemModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      mediaId: json['media_id'] as String? ?? '',
      mediaType: LeisureMediaType.fromValue(json['media_type'] as String?),
      status: LeisureItemStatus.fromValue(json['status'] as String?),
      rating: clampedRating,
      notes: json['notes'] as String?,
      dislikedUntil: json['disliked_until'] != null
          ? DateTime.tryParse(json['disliked_until'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'media_id': mediaId,
      'media_type': mediaType.toValue(),
      'status': status?.toValue(),
      'rating': rating,
      'notes': notes,
      'disliked_until': dislikedUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LeisureUserItemModel copyWith({
    String? id,
    String? userId,
    String? mediaId,
    LeisureMediaType? mediaType,
    LeisureItemStatus? status,
    double? rating,
    String? notes,
    DateTime? dislikedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeisureUserItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaId: mediaId ?? this.mediaId,
      mediaType: mediaType ?? this.mediaType,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      dislikedUntil: dislikedUntil ?? this.dislikedUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeisureUserItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'LeisureUserItemModel(id: $id, mediaId: $mediaId, mediaType: $mediaType, status: $status, rating: $rating)';
}
