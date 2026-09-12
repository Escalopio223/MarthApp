import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/leisure_config.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';

/// Servicio de integración para IGDB (Internet Game Database).
/// Se comunica exclusivamente a través de la Supabase Edge Function `igdb-proxy`
/// para no exponer Twitch Client ID ni Client Secret en el cliente Flutter.
class IgdbService {
  final FunctionsClient _functions;

  IgdbService({
    FunctionsClient? functions,
    SupabaseClient? supabaseClient,
  }) : _functions = functions ?? (supabaseClient ?? Supabase.instance.client).functions;

  /// Construye la URL canónica de una portada o captura de IGDB
  static String? buildImageUrl(String? imageId, {String size = 't_cover_big'}) {
    if (imageId == null || imageId.isEmpty) return null;
    return '${LeisureConfig.igdbImageBaseUrl}/$size/$imageId.jpg';
  }

  /// Obtiene los videojuegos más populares / valorados
  Future<List<LeisureMediaDetails>> getPopularGames({
    int limit = 20,
    int offset = 0,
  }) async {
    final query = '''
      fields id, name, summary, rating, rating_count, total_rating, total_rating_count,
             first_release_date, cover.image_id, genres.name, platforms.name,
             screenshots.image_id, involved_companies.developer, involved_companies.company.name;
      sort total_rating_count desc;
      where rating != null & cover != null;
      limit $limit;
      offset $offset;
    ''';

    final response = await _functions.invoke(
      'igdb-proxy',
      body: {
        'endpoint': '/games',
        'query': query,
      },
    );

    if (response.status != 200) {
      throw Exception('Error IGDB getPopularGames (${response.status}): ${response.data}');
    }

    final data = response.data;
    if (data is! List) return [];

    return data
        .map((item) => _parseGameJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el detalle completo de un videojuego por su ID
  Future<LeisureMediaDetails> getGameDetails(String gameId) async {
    final cleanId = int.tryParse(gameId) ?? 0;
    final query = '''
      fields id, name, summary, rating, rating_count, total_rating, total_rating_count,
             first_release_date, cover.image_id, genres.name, platforms.name,
             screenshots.image_id, involved_companies.developer, involved_companies.company.name;
      where id = $cleanId;
      limit 1;
    ''';

    final response = await _functions.invoke(
      'igdb-proxy',
      body: {
        'endpoint': '/games',
        'query': query,
      },
    );

    if (response.status != 200) {
      throw Exception('Error IGDB getGameDetails (${response.status}): ${response.data}');
    }

    final data = response.data;
    if (data is! List || data.isEmpty) {
      throw Exception('Videojuego no encontrado en IGDB (ID: $gameId)');
    }

    return _parseGameJson(data.first as Map<String, dynamic>);
  }

  // --- Parser de Payload IGDB ---

  LeisureMediaDetails _parseGameJson(Map<String, dynamic> json) {
    final id = json['id'].toString();
    final name = json['name'] as String? ?? 'Videojuego';
    final summary = json['summary'] as String?;

    // Portada
    final coverMap = json['cover'] as Map<String, dynamic>?;
    final coverImageId = coverMap?['image_id'] as String?;
    final posterUrl = buildImageUrl(coverImageId, size: 't_cover_big');

    // Capturas de pantalla
    final screenshotsRaw = json['screenshots'] as List? ?? [];
    final List<String> screenshots = [];
    String? backdropUrl;

    for (final s in screenshotsRaw) {
      if (s is Map && s['image_id'] != null) {
        final url = buildImageUrl(s['image_id'].toString(), size: 't_screenshot_big');
        if (url != null) {
          screenshots.add(url);
          backdropUrl ??= url; // Primera captura como backdrop
        }
      }
    }

    // Fecha de lanzamiento (timestamp Unix en segundos)
    String? releaseDate;
    String? year;
    final releaseTimestamp = (json['first_release_date'] as num?)?.toInt();
    if (releaseTimestamp != null && releaseTimestamp > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(releaseTimestamp * 1000, isUtc: true);
      releaseDate = date.toIso8601String().substring(0, 10);
      year = date.year.toString();
    }

    // Géneros
    final genresRaw = json['genres'] as List? ?? [];
    final genres = genresRaw
        .map((g) => g is Map ? g['name']?.toString() ?? '' : g.toString())
        .where((g) => g.isNotEmpty)
        .toList();

    // Plataformas
    final platformsRaw = json['platforms'] as List? ?? [];
    final platforms = platformsRaw
        .map((p) => p is Map ? p['name']?.toString() ?? '' : p.toString())
        .where((p) => p.isNotEmpty)
        .toList();

    // Desarrollador / Estudio
    String? developerName;
    final companiesRaw = json['involved_companies'] as List? ?? [];
    for (final c in companiesRaw) {
      if (c is Map && c['developer'] == true && c['company'] is Map) {
        developerName = c['company']['name'] as String?;
        break;
      }
    }
    developerName ??= (companiesRaw.isNotEmpty && companiesRaw.first is Map && companiesRaw.first['company'] is Map)
        ? companiesRaw.first['company']['name'] as String?
        : null;

    // Rating (IGDB devuelve 0-100, normalizar a escala 1.0 - 10.0)
    final rawRating = (json['total_rating'] ?? json['rating']) as num?;
    final rating = rawRating != null ? (rawRating / 10.0).clamp(1.0, 10.0).toDouble() : null;
    final voteCount = ((json['total_rating_count'] ?? json['rating_count']) as num?)?.toInt();

    return LeisureMediaDetails(
      mediaId: id,
      mediaType: LeisureMediaType.game,
      title: name,
      overview: summary,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      releaseDate: releaseDate,
      year: year,
      creatorOrDirector: developerName,
      genres: genres,
      castOrPlatforms: platforms,
      rating: rating,
      voteCount: voteCount,
      screenshots: screenshots,
    );
  }
}
