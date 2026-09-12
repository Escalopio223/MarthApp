import 'package:flutter/foundation.dart';
import 'book_edition_dto.dart';
import 'leisure_media_type.dart';
import 'streaming_provider_dto.dart';

/// DTO y modelo de dominio unificado para representar los detalles exhaustivos
/// de cualquier medio (Película, Serie, Libro o Videojuego) en la vista de detalle.
@immutable
class LeisureMediaDetails {
  final String mediaId;
  final LeisureMediaType mediaType;
  final String title;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final String? releaseDate;
  final String? year;
  final String? creatorOrDirector;
  final List<String> genres;
  final List<String> castOrPlatforms;
  final double? rating;
  final int? voteCount;
  final int? seasonsCount;
  final int? episodesCount;
  final List<StreamingProviderDto> watchProviders;
  final List<BookEditionDto> editions;
  final List<String> screenshots;

  const LeisureMediaDetails({
    required this.mediaId,
    required this.mediaType,
    required this.title,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.releaseDate,
    this.year,
    this.creatorOrDirector,
    this.genres = const [],
    this.castOrPlatforms = const [],
    this.rating,
    this.voteCount,
    this.seasonsCount,
    this.episodesCount,
    this.watchProviders = const [],
    this.editions = const [],
    this.screenshots = const [],
  });

  factory LeisureMediaDetails.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    final List<String> genres = rawGenres is List
        ? rawGenres.map((e) {
            if (e is Map && e['name'] != null) return e['name'].toString();
            return e.toString();
          }).toList()
        : <String>[];

    final rawCast = json['cast_or_platforms'];
    final List<String> castOrPlatforms = rawCast is List
        ? rawCast.map((e) => e.toString()).toList()
        : <String>[];

    final rawProviders = json['watch_providers'];
    final List<StreamingProviderDto> watchProviders = rawProviders is List
        ? rawProviders
            .map((e) => StreamingProviderDto.fromJson(e as Map<String, dynamic>))
            .toList()
        : <StreamingProviderDto>[];

    final rawEditions = json['editions'];
    final List<BookEditionDto> editions = rawEditions is List
        ? rawEditions
            .map((e) => BookEditionDto.fromJson(e as Map<String, dynamic>))
            .toList()
        : <BookEditionDto>[];

    final rawScreenshots = json['screenshots'];
    final List<String> screenshots = rawScreenshots is List
        ? rawScreenshots.map((e) => e.toString()).toList()
        : <String>[];

    return LeisureMediaDetails(
      mediaId: json['media_id']?.toString() ?? '',
      mediaType: LeisureMediaType.fromValue(json['media_type'] as String?),
      title: json['title'] as String? ?? 'Sin título',
      overview: json['overview'] as String?,
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      releaseDate: json['release_date'] as String?,
      year: json['year'] as String?,
      creatorOrDirector: json['creator_or_director'] as String?,
      genres: genres,
      castOrPlatforms: castOrPlatforms,
      rating: (json['rating'] as num?)?.toDouble(),
      voteCount: (json['vote_count'] as num?)?.toInt(),
      seasonsCount: (json['seasons_count'] as num?)?.toInt(),
      episodesCount: (json['episodes_count'] as num?)?.toInt(),
      watchProviders: watchProviders,
      editions: editions,
      screenshots: screenshots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media_id': mediaId,
      'media_type': mediaType.toValue(),
      'title': title,
      'overview': overview,
      'poster_url': posterUrl,
      'backdrop_url': backdropUrl,
      'release_date': releaseDate,
      'year': year,
      'creator_or_director': creatorOrDirector,
      'genres': genres,
      'cast_or_platforms': castOrPlatforms,
      'rating': rating,
      'vote_count': voteCount,
      'seasons_count': seasonsCount,
      'episodes_count': episodesCount,
      'watch_providers': watchProviders.map((e) => e.toJson()).toList(),
      'editions': editions.map((e) => e.toJson()).toList(),
      'screenshots': screenshots,
    };
  }

  LeisureMediaDetails copyWith({
    String? mediaId,
    LeisureMediaType? mediaType,
    String? title,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    String? releaseDate,
    String? year,
    String? creatorOrDirector,
    List<String>? genres,
    List<String>? castOrPlatforms,
    double? rating,
    int? voteCount,
    int? seasonsCount,
    int? episodesCount,
    List<StreamingProviderDto>? watchProviders,
    List<BookEditionDto>? editions,
    List<String>? screenshots,
  }) {
    return LeisureMediaDetails(
      mediaId: mediaId ?? this.mediaId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      releaseDate: releaseDate ?? this.releaseDate,
      year: year ?? this.year,
      creatorOrDirector: creatorOrDirector ?? this.creatorOrDirector,
      genres: genres ?? this.genres,
      castOrPlatforms: castOrPlatforms ?? this.castOrPlatforms,
      rating: rating ?? this.rating,
      voteCount: voteCount ?? this.voteCount,
      seasonsCount: seasonsCount ?? this.seasonsCount,
      episodesCount: episodesCount ?? this.episodesCount,
      watchProviders: watchProviders ?? this.watchProviders,
      editions: editions ?? this.editions,
      screenshots: screenshots ?? this.screenshots,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeisureMediaDetails &&
          runtimeType == other.runtimeType &&
          mediaId == other.mediaId &&
          mediaType == other.mediaType;

  @override
  int get hashCode => Object.hash(mediaId, mediaType);

  @override
  String toString() => 'LeisureMediaDetails($title, type: $mediaType, id: $mediaId)';
}
