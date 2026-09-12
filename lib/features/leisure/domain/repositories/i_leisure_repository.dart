import '../models/book_edition_dto.dart';
import '../models/leisure_environment_match_model.dart';
import '../models/leisure_media_details.dart';
import '../models/leisure_media_type.dart';
import '../models/leisure_item_status.dart';
import '../models/leisure_shared_list_item_model.dart';
import '../models/leisure_shared_list_model.dart';
import '../models/leisure_user_item_model.dart';
import '../models/streaming_provider_dto.dart';
import '../models/tv_season_details_dto.dart';

/// Interfaz del repositorio central del módulo de Ocio (Leisure).
/// Orquesta el consumo de APIs externas (TMDB, Open Library, IGDB) con caché
/// inteligente en Supabase (`leisure_media_cache`) y operaciones CRUD
/// para progreso personal, listas de entorno y Watch Party matches.
abstract class ILeisureRepository {
  // --- Catálogo y APIs Externas ---

  /// Obtiene películas en cartelera (predeterminado España 'ES')
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({
    String region = 'ES',
    int page = 1,
  });

  /// Obtiene contenido multimedia popular para alimentar el swipe feed
  Future<List<LeisureMediaDetails>> getPopularMedia({
    required LeisureMediaType type,
    int page = 1,
  });

  /// Busca títulos multimedia por texto libre según su tipo
  Future<List<LeisureMediaDetails>> searchMedia({
    required String query,
    required LeisureMediaType type,
    int page = 1,
  });

  /// Obtiene el detalle exhaustivo de un medio utilizando estrategia de caché
  Future<LeisureMediaDetails> getMediaDetails({
    required String mediaId,
    required LeisureMediaType type,
    bool forceRefresh = false,
  });

  /// Obtiene proveedores de streaming con suscripción ('flatrate') en España
  Future<List<StreamingProviderDto>> getWatchProviders({
    required String mediaId,
    required LeisureMediaType type,
    String region = 'ES',
  });

  /// Obtiene episodios de una temporada de serie con caché de 7 días
  Future<TvSeasonDetailsDto> getTvSeasonDetails({
    required String seriesId,
    required int seasonNumber,
    bool forceRefresh = false,
  });

  /// Obtiene ediciones de un libro con caché de 7 días
  Future<List<BookEditionDto>> getBookEditions({
    required String workId,
    bool forceRefresh = false,
  });

  // --- Progreso Personal (Privado) ---

  /// Obtiene el progreso de un usuario para un medio específico si existe
  Future<LeisureUserItemModel?> getUserItem({
    required String mediaId,
    required LeisureMediaType type,
  });

  /// Obtiene todos los ítems personales del usuario autenticado
  Future<List<LeisureUserItemModel>> getUserItems({
    LeisureMediaType? type,
    LeisureItemStatus? status,
  });

  /// Guarda o actualiza (Upsert) el progreso personal de un usuario
  Future<LeisureUserItemModel> saveUserItem(LeisureUserItemModel item);

  /// Elimina el progreso personal de un usuario
  Future<void> deleteUserItem({
    required String mediaId,
    required LeisureMediaType type,
  });

  // --- Listas Compartidas de Entorno ---

  /// Obtiene las listas temáticas pertenecientes a un entorno
  Future<List<LeisureSharedListModel>> getSharedLists({
    required String environmentId,
  });

  /// Crea una nueva lista temática en un entorno
  Future<LeisureSharedListModel> createSharedList({
    required String environmentId,
    required String title,
    String? description,
  });

  /// Elimina una lista compartida
  Future<void> deleteSharedList({required String listId});

  /// Obtiene los elementos pertenecientes a una lista compartida
  Future<List<LeisureSharedListItemModel>> getSharedListItems({
    required String listId,
  });

  /// Añade un elemento a una lista compartida forzando además su persistencia en caché
  Future<LeisureSharedListItemModel> addSharedListItem({
    required String listId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    String? posterUrl,
    LeisureMediaDetails? detailsToCache,
  });

  /// Elimina un elemento de una lista compartida
  Future<void> removeSharedListItem({required String itemId});

  // --- Coincidencias de Watch Party ---

  /// Obtiene las coincidencias de likes en el entorno
  Future<List<LeisureEnvironmentMatchModel>> getEnvironmentMatches({
    required String environmentId,
  });

  /// Registra o añade un match mutuo entre miembros de un entorno
  Future<LeisureEnvironmentMatchModel> recordEnvironmentMatch({
    required String environmentId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    required String matchedUserId,
  });
}
