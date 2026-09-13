import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/leisure_config.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';

/// Servicio de integracion para IGDB (Internet Game Database):
/// - Utiliza la Supabase Edge Function `igdb-proxy` como proxy de alta seguridad
/// - Cuenta con fallback directo autenticado por OAuth2 de Twitch para entornos locales o cliente
class IgdbService {
  final FunctionsClient? _functions;
  final http.Client _httpClient;

  static String? _cachedTwitchToken;
  static DateTime? _twitchTokenExpiresAt;

  IgdbService({
    FunctionsClient? functions,
    SupabaseClient? supabaseClient,
    http.Client? httpClient,
  })  : _functions = functions ?? (supabaseClient ?? _safeGetClient())?.functions,
        _httpClient = httpClient ?? http.Client();

  static SupabaseClient? _safeGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Construye la URL canonica de una portada o captura de IGDB
  static String? buildImageUrl(String? imageId, {String size = 't_cover_big'}) {
    if (imageId == null || imageId.isEmpty) return null;
    return '${LeisureConfig.igdbImageBaseUrl}/$size/$imageId.jpg';
  }

  /// Obtiene o renueva el token OAuth2 de Twitch para consultas directas
  Future<String?> _getTwitchToken() async {
    final now = DateTime.now();
    if (_cachedTwitchToken != null &&
        _twitchTokenExpiresAt != null &&
        now.isBefore(_twitchTokenExpiresAt!)) {
      return _cachedTwitchToken;
    }

    if (!LeisureConfig.isIgdbConfigured) return null;

    try {
      final response = await _httpClient.post(
        Uri.parse('https://id.twitch.tv/oauth2/token'),
        body: {
          'client_id': LeisureConfig.twitchClientId,
          'client_secret': LeisureConfig.twitchClientSecret,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedTwitchToken = data['access_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        _twitchTokenExpiresAt = now.add(Duration(seconds: expiresIn - 60));
        return _cachedTwitchToken;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Ejecuta una consulta a IGDB (primero via Edge Function y luego fallback directo)
  Future<List<dynamic>> _invokeQuery(String endpoint, String query) async {
    // 1. Intentar via Edge Function de Supabase
    final functions = _functions;
    if (functions != null) {
      try {
        final response = await functions.invoke(
          'igdb-proxy',
          body: {
            'endpoint': endpoint,
            'query': query,
          },
        );
        if (response.status == 200 && response.data is List) {
          return response.data as List<dynamic>;
        }
      } catch (_) {
        // Fallback directo si la Edge Function no responde o no esta desplegada
      }
    }

    // 2. Fallback directo con credenciales OAuth2 de Twitch
    final token = await _getTwitchToken();
    if (token != null) {
      try {
        final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
        final response = await _httpClient.post(
          Uri.parse('https://api.igdb.com/v4$cleanEndpoint'),
          headers: {
            'Client-ID': LeisureConfig.twitchClientId,
            'Authorization': 'Bearer $token',
            'Content-Type': 'text/plain',
            'Accept': 'application/json',
          },
          body: query,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is List) return data;
        }
      } catch (_) {
        return [];
      }
    }

    return [];
  }

  /// Obtiene los videojuegos mas populares / valorados
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

    final data = await _invokeQuery('/games', query);
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseGameJson(item))
        .toList();
  }

  /// Busca videojuegos por coincidencia de texto
  Future<List<LeisureMediaDetails>> searchGames(String queryText, {int limit = 20}) async {
    if (queryText.trim().isEmpty) return [];

    final sanitizedQuery = queryText.replaceAll('"', '\\"');
    final query = '''
      search "$sanitizedQuery";
      fields id, name, summary, rating, rating_count, total_rating, total_rating_count,
             first_release_date, cover.image_id, genres.name, platforms.name,
             screenshots.image_id, involved_companies.developer, involved_companies.company.name;
      limit $limit;
    ''';

    final data = await _invokeQuery('/games', query);
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseGameJson(item))
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

    final data = await _invokeQuery('/games', query);
    if (data.isEmpty) {
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
          backdropUrl ??= url;
        }
      }
    }

    // Fecha de lanzamiento (epoch en segundos)
    String? releaseDateStr;
    String? yearStr;
    final releaseTimestamp = json['first_release_date'];
    if (releaseTimestamp is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(releaseTimestamp * 1000, isUtc: true);
      releaseDateStr = dt.toIso8601String().split('T').first;
      yearStr = dt.year.toString();
    }

    // Generos
    final genresRaw = json['genres'] as List? ?? [];
    final genres = genresRaw
        .whereType<Map>()
        .map((g) => g['name']?.toString())
        .whereType<String>()
        .toList();

    // Plataformas
    final platformsRaw = json['platforms'] as List? ?? [];
    final platforms = platformsRaw
        .whereType<Map>()
        .map((p) => p['name']?.toString())
        .whereType<String>()
        .toList();

    // Desarrollador
    String? developer;
    final companiesRaw = json['involved_companies'] as List? ?? [];
    for (final c in companiesRaw) {
      if (c is Map && c['developer'] == true) {
        final comp = c['company'];
        if (comp is Map && comp['name'] != null) {
          developer = comp['name'].toString();
          break;
        }
      }
    }

    // Calificacion (IGDB escala 0-100 -> normalizamos a 0-10)
    final rawRating = json['total_rating'] ?? json['rating'];
    double? rating;
    if (rawRating is num) {
      rating = double.parse((rawRating / 10.0).toStringAsFixed(1));
    }

    return LeisureMediaDetails(
      mediaId: id,
      mediaType: LeisureMediaType.game,
      title: name,
      overview: summary,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      releaseDate: releaseDateStr,
      year: yearStr,
      creatorOrDirector: developer,
      genres: genres,
      castOrPlatforms: platforms,
      rating: rating,
      screenshots: screenshots,
    );
  }
}
