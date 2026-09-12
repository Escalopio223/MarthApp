import 'package:flutter/foundation.dart';
import '../../../../core/config/leisure_config.dart';

/// DTO para el detalle de un episodio individual de serie
@immutable
class TvEpisodeDto {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? stillPath;
  final String? airDate;
  final double? voteAverage;

  const TvEpisodeDto({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.voteAverage,
  });

  String? get stillUrl => (stillPath != null && stillPath!.isNotEmpty)
      ? (stillPath!.startsWith('http')
          ? stillPath
          : '${LeisureConfig.tmdbImageBaseUrl}/w500$stillPath')
      : null;

  factory TvEpisodeDto.fromJson(Map<String, dynamic> json) {
    return TvEpisodeDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 1,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? 'Episodio',
      overview: json['overview'] as String?,
      stillPath: json['still_path'] as String?,
      airDate: json['air_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'episode_number': episodeNumber,
      'season_number': seasonNumber,
      'name': name,
      'overview': overview,
      'still_path': stillPath,
      'air_date': airDate,
      'vote_average': voteAverage,
    };
  }
}

/// DTO para la temporada completa con su lista de episodios
@immutable
class TvSeasonDetailsDto {
  final int id;
  final String seriesId;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? posterPath;
  final String? airDate;
  final List<TvEpisodeDto> episodes;

  const TvSeasonDetailsDto({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.posterPath,
    this.airDate,
    this.episodes = const [],
  });

  String? get posterUrl => (posterPath != null && posterPath!.isNotEmpty)
      ? (posterPath!.startsWith('http')
          ? posterPath
          : '${LeisureConfig.tmdbImageBaseUrl}/w500$posterPath')
      : null;

  factory TvSeasonDetailsDto.fromJson(Map<String, dynamic> json, {String seriesId = ''}) {
    final rawEpisodes = json['episodes'];
    final List<TvEpisodeDto> parsedEpisodes = rawEpisodes is List
        ? rawEpisodes
            .map((e) => TvEpisodeDto.fromJson(e as Map<String, dynamic>))
            .toList()
        : <TvEpisodeDto>[];

    return TvSeasonDetailsDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      seriesId: seriesId.isNotEmpty ? seriesId : (json['series_id']?.toString() ?? ''),
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? 'Temporada',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      airDate: json['air_date'] as String?,
      episodes: parsedEpisodes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'series_id': seriesId,
      'season_number': seasonNumber,
      'name': name,
      'overview': overview,
      'poster_path': posterPath,
      'air_date': airDate,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}
