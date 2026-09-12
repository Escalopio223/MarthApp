import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/config/leisure_config.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';
import '../../domain/models/streaming_provider_dto.dart';
import '../../domain/models/tv_season_details_dto.dart';

/// Servicio de integración para The Movie Database (TMDB v3).
/// Soporta inyección de [http.Client] para pruebas y gestión de timeouts.
class TmdbService {
  final http.Client _client;
  final String _apiKey;
  final String _baseUrl;

  TmdbService({
    http.Client? client,
    String? apiKey,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? LeisureConfig.tmdbApiKey,
        _baseUrl = baseUrl ?? LeisureConfig.tmdbBaseUrl;

  /// Cierra el cliente si fue instanciado internamente
  void dispose() {
    _client.close();
  }

  /// Construye los headers y query parameters comunes
  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final params = <String, String>{
      'api_key': _apiKey,
      'language': 'es-ES',
      ...?queryParams,
    };
    return Uri.parse('$_baseUrl$path').replace(queryParameters: params);
  }

  /// Películas actualmente en cartelera (predeterminado España 'ES')
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({
    String region = 'ES',
    int page = 1,
  }) async {
    final uri = _buildUri('/movie/now_playing', {
      'region': region,
      'page': page.toString(),
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException('Error TMDB now_playing (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List? ?? [];

    return results.map((item) => _parseMovieSummary(item as Map<String, dynamic>)).toList();
  }

  /// Contenido multimedia popular para alimentar el swipe feed
  Future<List<LeisureMediaDetails>> getPopularMedia({
    required LeisureMediaType type,
    int page = 1,
  }) async {
    assert(
      type == LeisureMediaType.movie || type == LeisureMediaType.tv,
      'TMDB solo soporta movie y tv',
    );

    final endpoint = type == LeisureMediaType.movie ? '/movie/popular' : '/tv/popular';
    final uri = _buildUri(endpoint, {'page': page.toString()});

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException('Error TMDB popular (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List? ?? [];

    return results.map((item) {
      final map = item as Map<String, dynamic>;
      return type == LeisureMediaType.movie
          ? _parseMovieSummary(map)
          : _parseTvSummary(map);
    }).toList();
  }

  /// Búsqueda de películas por texto libre
  Future<List<LeisureMediaDetails>> searchMovies(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final uri = _buildUri('/search/movie', {
      'query': query,
      'page': page.toString(),
    });

    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('Error TMDB search/movie (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List? ?? [];
    return results.map((item) => _parseMovieSummary(item as Map<String, dynamic>)).toList();
  }

  /// Búsqueda de series por texto libre
  Future<List<LeisureMediaDetails>> searchTvShows(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final uri = _buildUri('/search/tv', {
      'query': query,
      'page': page.toString(),
    });

    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('Error TMDB search/tv (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List? ?? [];
    return results.map((item) => _parseTvSummary(item as Map<String, dynamic>)).toList();
  }

  /// Detalle exhaustivo con sinopsis, director/creador, géneros y top de reparto
  Future<LeisureMediaDetails> getMediaDetails({
    required String mediaId,
    required LeisureMediaType type,
  }) async {
    final endpoint = type == LeisureMediaType.movie ? '/movie/$mediaId' : '/tv/$mediaId';
    final uri = _buildUri(endpoint, {'append_to_response': 'credits'});

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException('Error TMDB details (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // 1. Géneros
    final rawGenres = json['genres'] as List? ?? [];
    final genres = rawGenres.map((g) => g['name'].toString()).toList();

    // 2. Créditos (Director / Cast)
    String? creatorOrDirector;
    final List<String> castNames = [];

    if (type == LeisureMediaType.movie) {
      final crew = (json['credits']?['crew'] as List?) ?? [];
      for (final member in crew) {
        if (member['job'] == 'Director') {
          creatorOrDirector = member['name'] as String?;
          break;
        }
      }
    } else {
      final creators = json['created_by'] as List? ?? [];
      if (creators.isNotEmpty) {
        creatorOrDirector = creators.first['name'] as String?;
      }
    }

    final cast = (json['credits']?['cast'] as List?) ?? [];
    for (var i = 0; i < cast.length && i < 6; i++) {
      final name = cast[i]['name'] as String?;
      if (name != null) castNames.add(name);
    }

    // 3. Fechas
    final releaseDate = (type == LeisureMediaType.movie
        ? json['release_date']
        : json['first_air_date']) as String?;
    final year = releaseDate != null && releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : null;

    final posterPath = json['poster_path'] as String?;
    final backdropPath = json['backdrop_path'] as String?;

    return LeisureMediaDetails(
      mediaId: mediaId,
      mediaType: type,
      title: (type == LeisureMediaType.movie ? json['title'] : json['name']) as String? ?? 'Sin título',
      overview: json['overview'] as String?,
      posterUrl: posterPath != null ? '${LeisureConfig.tmdbImageBaseUrl}/w500$posterPath' : null,
      backdropUrl: backdropPath != null ? '${LeisureConfig.tmdbImageBaseUrl}/original$backdropPath' : null,
      releaseDate: releaseDate,
      year: year,
      creatorOrDirector: creatorOrDirector,
      genres: genres,
      castOrPlatforms: castNames,
      rating: (json['vote_average'] as num?)?.toDouble(),
      voteCount: (json['vote_count'] as num?)?.toInt(),
      seasonsCount: (json['number_of_seasons'] as num?)?.toInt(),
      episodesCount: (json['number_of_episodes'] as num?)?.toInt(),
    );
  }

  /// Plataformas de streaming con suscripción ('flatrate') disponibles en España
  Future<List<StreamingProviderDto>> getWatchProviders({
    required String mediaId,
    required LeisureMediaType type,
    String region = 'ES',
  }) async {
    final endpoint = type == LeisureMediaType.movie
        ? '/movie/$mediaId/watch/providers'
        : '/tv/$mediaId/watch/providers';

    final uri = _buildUri(endpoint);

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as Map<String, dynamic>? ?? {};
    final regionData = results[region] as Map<String, dynamic>?;

    if (regionData == null) return [];

    final flatrate = regionData['flatrate'] as List? ?? [];

    return flatrate
        .map((p) => StreamingProviderDto.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Desglose de episodios de una temporada de serie
  Future<TvSeasonDetailsDto> getTvSeasonsAndEpisodes({
    required String seriesId,
    required int seasonNumber,
  }) async {
    final uri = _buildUri('/tv/$seriesId/season/$seasonNumber');

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException('Error TMDB season ($seriesId S$seasonNumber): ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return TvSeasonDetailsDto.fromJson(json, seriesId: seriesId);
  }

  // --- Helpers de Mapeo Resumido ---

  LeisureMediaDetails _parseMovieSummary(Map<String, dynamic> json) {
    final posterPath = json['poster_path'] as String?;
    final backdropPath = json['backdrop_path'] as String?;
    final releaseDate = json['release_date'] as String?;
    final year = releaseDate != null && releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : null;

    return LeisureMediaDetails(
      mediaId: json['id'].toString(),
      mediaType: LeisureMediaType.movie,
      title: json['title'] as String? ?? 'Película',
      overview: json['overview'] as String?,
      posterUrl: posterPath != null ? '${LeisureConfig.tmdbImageBaseUrl}/w500$posterPath' : null,
      backdropUrl: backdropPath != null ? '${LeisureConfig.tmdbImageBaseUrl}/w780$backdropPath' : null,
      releaseDate: releaseDate,
      year: year,
      rating: (json['vote_average'] as num?)?.toDouble(),
      voteCount: (json['vote_count'] as num?)?.toInt(),
    );
  }

  LeisureMediaDetails _parseTvSummary(Map<String, dynamic> json) {
    final posterPath = json['poster_path'] as String?;
    final backdropPath = json['backdrop_path'] as String?;
    final releaseDate = json['first_air_date'] as String?;
    final year = releaseDate != null && releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : null;

    return LeisureMediaDetails(
      mediaId: json['id'].toString(),
      mediaType: LeisureMediaType.tv,
      title: json['name'] as String? ?? 'Serie',
      overview: json['overview'] as String?,
      posterUrl: posterPath != null ? '${LeisureConfig.tmdbImageBaseUrl}/w500$posterPath' : null,
      backdropUrl: backdropPath != null ? '${LeisureConfig.tmdbImageBaseUrl}/w780$backdropPath' : null,
      releaseDate: releaseDate,
      year: year,
      rating: (json['vote_average'] as num?)?.toDouble(),
      voteCount: (json['vote_count'] as num?)?.toInt(),
    );
  }
}
