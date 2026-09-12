import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/leisure_config.dart';
import '../../domain/models/book_edition_dto.dart';
import '../../domain/models/leisure_environment_match_model.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';
import '../../domain/models/leisure_item_status.dart';
import '../../domain/models/leisure_shared_list_item_model.dart';
import '../../domain/models/leisure_shared_list_model.dart';
import '../../domain/models/leisure_user_item_model.dart';
import '../../domain/models/streaming_provider_dto.dart';
import '../../domain/models/tv_season_details_dto.dart';
import '../../domain/repositories/i_leisure_repository.dart';
import '../services/igdb_service.dart';
import '../services/open_library_service.dart';
import '../services/tmdb_service.dart';

/// Implementación del repositorio central de Ocio (Leisure).
/// Orquesta TMDB v3, Open Library e IGDB junto con Supabase (progreso personal,
/// listas de entorno, matches y caché relacional de 7 días).
class LeisureRepository implements ILeisureRepository {
  final SupabaseClient? _supabase;
  final TmdbService _tmdbService;
  final OpenLibraryService _openLibraryService;
  final IgdbService _igdbService;

  LeisureRepository({
    SupabaseClient? supabaseClient,
    TmdbService? tmdbService,
    OpenLibraryService? openLibraryService,
    IgdbService? igdbService,
  })  : _supabase = supabaseClient ?? _safeGetClient(),
        _tmdbService = tmdbService ?? TmdbService(),
        _openLibraryService = openLibraryService ?? OpenLibraryService(),
        _igdbService = igdbService ?? IgdbService(supabaseClient: supabaseClient);

  static SupabaseClient? _safeGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _client {
    final client = _supabase;
    if (client == null) {
      throw StateError('Supabase no está inicializado.');
    }
    return client;
  }

  String get _currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Usuario no autenticado al interactuar con LeisureRepository');
    }
    return user.id;
  }

  // ===========================================================================
  // 1. CATÁLOGO Y APIS EXTERNAS CON ESTRATEGIA DE CACHÉ
  // ===========================================================================

  @override
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({
    String region = 'ES',
    int page = 1,
  }) async {
    return _tmdbService.getNowPlayingMovies(region: region, page: page);
  }

  @override
  Future<List<LeisureMediaDetails>> getPopularMedia({
    required LeisureMediaType type,
    int page = 1,
  }) async {
    switch (type) {
      case LeisureMediaType.movie:
      case LeisureMediaType.tv:
        return _tmdbService.getPopularMedia(type: type, page: page);
      case LeisureMediaType.book:
        return _openLibraryService.getPopularBooks(page: page);
      case LeisureMediaType.game:
        final offset = (page - 1) * 20;
        return _igdbService.getPopularGames(limit: 20, offset: offset);
    }
  }

  @override
  Future<List<LeisureMediaDetails>> searchMedia({
    required String query,
    required LeisureMediaType type,
    int page = 1,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    switch (type) {
      case LeisureMediaType.movie:
        return _tmdbService.searchMovies(cleanQuery, page: page);
      case LeisureMediaType.tv:
        return _tmdbService.searchTvShows(cleanQuery, page: page);
      case LeisureMediaType.book:
        return _openLibraryService.searchBooks(cleanQuery, page: page);
      case LeisureMediaType.game:
        return _igdbService.searchGames(cleanQuery);
    }
  }

  @override
  Future<LeisureMediaDetails> getMediaDetails({
    required String mediaId,
    required LeisureMediaType type,
    bool forceRefresh = false,
  }) async {
    // 1. Verificar si existe en caché de Supabase
    if (!forceRefresh) {
      final cachedPayload = await _getCachedPayload(mediaId, type);
      if (cachedPayload != null) {
        try {
          return LeisureMediaDetails.fromJson(cachedPayload);
        } catch (e) {
          debugPrint('Error al deserializar mediaDetails de caché: $e');
        }
      }
    }

    // 2. Consulta a la API correspondiente según tipo
    LeisureMediaDetails details;
    switch (type) {
      case LeisureMediaType.movie:
      case LeisureMediaType.tv:
        details = await _tmdbService.getMediaDetails(mediaId: mediaId, type: type);
        // Anexar proveedores de streaming en España
        try {
          final providers = await _tmdbService.getWatchProviders(mediaId: mediaId, type: type);
          details = details.copyWith(watchProviders: providers);
        } catch (_) {}
        break;
      case LeisureMediaType.book:
        details = await _openLibraryService.getWorkDetails(mediaId);
        break;
      case LeisureMediaType.game:
        details = await _igdbService.getGameDetails(mediaId);
        break;
    }

    // 3. Guardar en caché de Supabase en segundo plano
    _saveToCache(mediaId, type, details.toJson());

    return details;
  }

  @override
  Future<List<StreamingProviderDto>> getWatchProviders({
    required String mediaId,
    required LeisureMediaType type,
    String region = 'ES',
  }) async {
    if (type != LeisureMediaType.movie && type != LeisureMediaType.tv) {
      return [];
    }
    return _tmdbService.getWatchProviders(mediaId: mediaId, type: type, region: region);
  }

  @override
  Future<TvSeasonDetailsDto> getTvSeasonDetails({
    required String seriesId,
    required int seasonNumber,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${seriesId}_s$seasonNumber';

    if (!forceRefresh) {
      final cached = await _getCachedPayload(cacheKey, LeisureMediaType.tv);
      if (cached != null) {
        try {
          return TvSeasonDetailsDto.fromJson(cached, seriesId: seriesId);
        } catch (e) {
          debugPrint('Error al deserializar temporada de serie de caché: $e');
        }
      }
    }

    final season = await _tmdbService.getTvSeasonsAndEpisodes(
      seriesId: seriesId,
      seasonNumber: seasonNumber,
    );

    _saveToCache(cacheKey, LeisureMediaType.tv, season.toJson());
    return season;
  }

  @override
  Future<List<BookEditionDto>> getBookEditions({
    required String workId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${workId}_editions';

    if (!forceRefresh) {
      final cached = await _getCachedPayload(cacheKey, LeisureMediaType.book);
      if (cached != null && cached['entries'] is List) {
        try {
          final list = cached['entries'] as List;
          return list.map((e) => BookEditionDto.fromJson(e as Map<String, dynamic>)).toList();
        } catch (e) {
          debugPrint('Error al deserializar ediciones de libro de caché: $e');
        }
      }
    }

    final editions = await _openLibraryService.getWorkEditions(workId);
    _saveToCache(cacheKey, LeisureMediaType.book, {
      'entries': editions.map((e) => e.toJson()).toList(),
    });

    return editions;
  }

  // ===========================================================================
  // 2. PROGRESO PERSONAL (leisure_user_items)
  // ===========================================================================

  @override
  Future<LeisureUserItemModel?> getUserItem({
    required String mediaId,
    required LeisureMediaType type,
  }) async {
    final res = await _client
        .from('leisure_user_items')
        .select()
        .eq('user_id', _currentUserId)
        .eq('media_id', mediaId)
        .eq('media_type', type.toValue())
        .maybeSingle();

    if (res == null) return null;
    return LeisureUserItemModel.fromJson(res);
  }

  @override
  Future<List<LeisureUserItemModel>> getUserItems({
    LeisureMediaType? type,
    LeisureItemStatus? status,
  }) async {
    var query = _client
        .from('leisure_user_items')
        .select()
        .eq('user_id', _currentUserId);

    if (type != null) {
      query = query.eq('media_type', type.toValue());
    }

    if (status != null) {
      query = query.eq('status', status.toValue());
    }

    final res = await query.order('updated_at', ascending: false);
    return (res as List).map((row) => LeisureUserItemModel.fromJson(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<LeisureUserItemModel> saveUserItem(LeisureUserItemModel item) async {
    final rowData = {
      'user_id': _currentUserId,
      'media_id': item.mediaId,
      'media_type': item.mediaType.toValue(),
      'status': item.status?.toValue(),
      'rating': item.rating,
      'notes': item.notes,
      'disliked_until': item.dislikedUntil?.toIso8601String(),
    };

    final res = await _client
        .from('leisure_user_items')
        .upsert(rowData, onConflict: 'user_id,media_id,media_type')
        .select()
        .single();

    return LeisureUserItemModel.fromJson(res);
  }

  @override
  Future<void> deleteUserItem({
    required String mediaId,
    required LeisureMediaType type,
  }) async {
    await _client
        .from('leisure_user_items')
        .delete()
        .eq('user_id', _currentUserId)
        .eq('media_id', mediaId)
        .eq('media_type', type.toValue());
  }

  // ===========================================================================
  // 3. LISTAS COMPARTIDAS DE ENTORNO
  // ===========================================================================

  @override
  Future<List<LeisureSharedListModel>> getSharedLists({
    required String environmentId,
  }) async {
    final res = await _client
        .from('leisure_shared_lists')
        .select('*, leisure_shared_list_items(count)')
        .eq('environment_id', environmentId)
        .order('created_at', ascending: false);

    return (res as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final countList = map['leisure_shared_list_items'] as List?;
      if (countList != null && countList.isNotEmpty) {
        map['items_count'] = countList.first['count'] ?? 0;
      }
      return LeisureSharedListModel.fromJson(map);
    }).toList();
  }

  @override
  Future<LeisureSharedListModel> createSharedList({
    required String environmentId,
    required String title,
    String? description,
  }) async {
    final res = await _client
        .from('leisure_shared_lists')
        .insert({
          'environment_id': environmentId,
          'created_by': _currentUserId,
          'title': title.trim(),
          'description': description?.trim(),
        })
        .select()
        .single();

    return LeisureSharedListModel.fromJson(res);
  }

  @override
  Future<void> deleteSharedList({required String listId}) async {
    await _client
        .from('leisure_shared_lists')
        .delete()
        .eq('id', listId);
  }

  @override
  Future<List<LeisureSharedListItemModel>> getSharedListItems({
    required String listId,
  }) async {
    final res = await _client
        .from('leisure_shared_list_items')
        .select()
        .eq('list_id', listId)
        .order('created_at', ascending: false);

    return (res as List)
        .map((row) => LeisureSharedListItemModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LeisureSharedListItemModel> addSharedListItem({
    required String listId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    String? posterUrl,
    LeisureMediaDetails? detailsToCache,
  }) async {
    final res = await _client
        .from('leisure_shared_list_items')
        .insert({
          'list_id': listId,
          'media_id': mediaId,
          'media_type': mediaType.toValue(),
          'title': title,
          'poster_url': posterUrl,
          'added_by': _currentUserId,
        })
        .select()
        .single();

    // Guardar en caché para que otros miembros del entorno puedan leerlo sin llamar a la API
    if (detailsToCache != null) {
      _saveToCache(mediaId, mediaType, detailsToCache.toJson());
    }

    return LeisureSharedListItemModel.fromJson(res);
  }

  @override
  Future<void> removeSharedListItem({required String itemId}) async {
    await _client
        .from('leisure_shared_list_items')
        .delete()
        .eq('id', itemId);
  }

  // ===========================================================================
  // 4. COINCIDENCIAS DE WATCH PARTY
  // ===========================================================================

  @override
  Future<List<LeisureEnvironmentMatchModel>> getEnvironmentMatches({
    required String environmentId,
  }) async {
    final res = await _client
        .from('leisure_environment_matches')
        .select()
        .eq('environment_id', environmentId)
        .order('created_at', ascending: false);

    return (res as List)
        .map((row) => LeisureEnvironmentMatchModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LeisureEnvironmentMatchModel> recordEnvironmentMatch({
    required String environmentId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    required String matchedUserId,
  }) async {
    // Buscar si ya existe la coincidencia previa
    final existing = await _client
        .from('leisure_environment_matches')
        .select()
        .eq('environment_id', environmentId)
        .eq('media_id', mediaId)
        .eq('media_type', mediaType.toValue())
        .maybeSingle();

    if (existing != null) {
      final matchModel = LeisureEnvironmentMatchModel.fromJson(existing);
      final currentUsers = List<String>.from(matchModel.matchedUserIds);

      if (!currentUsers.contains(matchedUserId)) {
        currentUsers.add(matchedUserId);
        final updateRes = await _client
            .from('leisure_environment_matches')
            .update({'matched_user_ids': currentUsers})
            .eq('id', matchModel.id)
            .select()
            .single();
        return LeisureEnvironmentMatchModel.fromJson(updateRes);
      }
      return matchModel;
    }

    // Crear nueva coincidencia
    final insertRes = await _client
        .from('leisure_environment_matches')
        .insert({
          'environment_id': environmentId,
          'media_id': mediaId,
          'media_type': mediaType.toValue(),
          'title': title,
          'matched_user_ids': [matchedUserId],
        })
        .select()
        .single();

    return LeisureEnvironmentMatchModel.fromJson(insertRes);
  }

  // ===========================================================================
  // 5. GESTIÓN INTERNA DE CACHÉ EN SUPABASE (7 DÍAS)
  // ===========================================================================

  Future<Map<String, dynamic>?> _getCachedPayload(String mediaId, LeisureMediaType type) async {
    final supabase = _supabase;
    if (supabase == null) return null;

    try {
      final res = await supabase
          .from('leisure_media_cache')
          .select('payload, cached_at')
          .eq('media_id', mediaId)
          .eq('media_type', type.toValue())
          .maybeSingle();

      if (res == null) return null;

      final cachedAtStr = res['cached_at'] as String?;
      if (cachedAtStr == null) return null;

      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt == null) return null;

      // Verificar caducidad de 7 días
      final age = DateTime.now().difference(cachedAt);
      if (age > LeisureConfig.cacheMaxAge) {
        return null; // Expirado
      }

      final payload = res['payload'];
      if (payload is Map<String, dynamic>) {
        return payload;
      }
    } catch (e) {
      debugPrint('Aviso: Error de lectura en leisure_media_cache: $e');
    }
    return null;
  }

  void _saveToCache(String mediaId, LeisureMediaType type, Map<String, dynamic> payload) {
    final supabase = _supabase;
    if (supabase == null) return;

    // Se ejecuta de forma asíncrona no bloqueante
    supabase.from('leisure_media_cache').upsert(
      {
        'media_id': mediaId,
        'media_type': type.toValue(),
        'payload': payload,
        'cached_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'media_id,media_type',
    ).then((_) {
      // Éxito silencioso
    }).catchError((error) {
      debugPrint('Aviso: Error al persistir en leisure_media_cache: $error');
    });
  }
}
