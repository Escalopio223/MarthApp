import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/book_edition_dto.dart';
import '../../domain/models/leisure_environment_match_model.dart';
import '../../domain/models/leisure_item_status.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';
import '../../domain/models/leisure_shared_list_item_model.dart';
import '../../domain/models/leisure_shared_list_model.dart';
import '../../domain/models/leisure_user_item_model.dart';
import '../../domain/models/tv_season_details_dto.dart';
import '../../domain/repositories/i_leisure_repository.dart';
import '../../infrastructure/repositories/leisure_repository.dart';

/// Controlador reactivo central del módulo de Ocio (Leisure):
/// - Búsqueda con debounce real (400ms) cancelando peticiones en vuelo
/// - Actualización optimista de estados y calificaciones personales
/// - Conciencia de entorno (Personal vs Colaborativo) para listas y matches
/// - Estado en memoria para selección de títulos hacia la ruleta
class LeisureController extends ChangeNotifier {
  final ILeisureRepository _repository;

  String? _currentUserId;
  String? _currentEnvironmentId;
  bool _isPersonalEnvironment = true;

  LeisureMediaType _selectedType = LeisureMediaType.movie;
  int _selectedSubFilter = 0; // 0: Explorar catálogo, 1: Mis guardados

  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  String _searchQuery = '';
  Timer? _debounceTimer;
  int _activeSearchId = 0;

  List<LeisureMediaDetails> _catalogItems = [];
  List<LeisureMediaDetails> _searchResults = [];

  // Mapa reactivo indexado por 'mediaType_mediaId' para lookup O(1)
  final Map<String, LeisureUserItemModel> _userItems = {};

  // Conjunto de identificadores 'mediaType_mediaId' añadidos a la ruleta
  final Set<String> _rouletteMediaKeys = {};

  // Listas compartidas del entorno y matches
  List<LeisureSharedListModel> _sharedLists = [];
  final Map<String, List<LeisureSharedListItemModel>> _sharedListItemsMap = {};
  List<LeisureEnvironmentMatchModel> _environmentMatches = [];

  LeisureController({ILeisureRepository? repository})
      : _repository = repository ?? LeisureRepository();

  // Getters
  String? get currentUserId => _currentUserId;
  String? get currentEnvironmentId => _currentEnvironmentId;
  bool get isPersonalEnvironment => _isPersonalEnvironment;
  LeisureMediaType get selectedType => _selectedType;
  int get selectedSubFilter => _selectedSubFilter;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  List<LeisureMediaDetails> get catalogItems => List.unmodifiable(_catalogItems);
  List<LeisureMediaDetails> get searchResults => List.unmodifiable(_searchResults);
  List<LeisureSharedListModel> get sharedLists => List.unmodifiable(_sharedLists);
  List<LeisureEnvironmentMatchModel> get environmentMatches =>
      List.unmodifiable(_environmentMatches);
  int get rouletteCount => _rouletteMediaKeys.length;

  /// Clave canónica compuesta para lookup en mapas
  static String makeKey(LeisureMediaType type, String mediaId) =>
      '${type.toValue()}_$mediaId';

  /// Obtiene el progreso del usuario para un medio si existe
  LeisureUserItemModel? getUserItem(LeisureMediaType type, String mediaId) {
    return _userItems[makeKey(type, mediaId)];
  }

  /// Verifica si un medio está seleccionado para la ruleta
  bool isRouletteSelected(LeisureMediaType type, String mediaId) {
    return _rouletteMediaKeys.contains(makeKey(type, mediaId));
  }

  /// Inicializa el controlador con el usuario y entorno activo
  Future<void> initialize(
    String userId, {
    String? environmentId,
    bool isPersonal = true,
  }) async {
    _currentUserId = userId;
    _currentEnvironmentId = environmentId;
    _isPersonalEnvironment = isPersonal;

    await Future.wait([
      loadUserItems(),
      loadCatalog(),
      if (!isPersonal && environmentId != null) ...[
        loadSharedLists(),
        loadEnvironmentMatches(),
      ],
    ]);
  }

  /// Actualiza el entorno activo (cuando el usuario cambia de workspace)
  Future<void> setEnvironment(String? environmentId, {bool isPersonal = true}) async {
    _currentEnvironmentId = environmentId;
    _isPersonalEnvironment = isPersonal;
    _sharedLists = [];
    _sharedListItemsMap.clear();
    _environmentMatches = [];
    notifyListeners();

    if (!isPersonal && environmentId != null) {
      await Future.wait([
        loadSharedLists(),
        loadEnvironmentMatches(),
      ]);
    }
  }

  /// Cambia la categoría de medio (Películas, Series, Libros, Videojuegos)
  Future<void> setMediaType(LeisureMediaType type) async {
    if (_selectedType == type) return;
    _selectedType = type;
    _searchQuery = '';
    _searchResults = [];
    _debounceTimer?.cancel();
    notifyListeners();

    await loadCatalog();
  }

  /// Cambia el subfiltro (0: Catálogo, 1: Mis Guardados)
  void setSubFilter(int index) {
    if (_selectedSubFilter == index) return;
    _selectedSubFilter = index;
    notifyListeners();
  }

  /// Carga el catálogo principal según el tipo seleccionado
  Future<void> loadCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_selectedType == LeisureMediaType.movie) {
        _catalogItems = await _repository.getNowPlayingMovies(region: 'ES');
      } else {
        _catalogItems = await _repository.getPopularMedia(type: _selectedType);
      }
    } catch (e) {
      _errorMessage = 'Error al cargar el catálogo de ${_selectedType.label}: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga todos los ítems guardados por el usuario
  Future<void> loadUserItems() async {
    if (_currentUserId == null) return;
    try {
      final items = await _repository.getUserItems();
      _userItems.clear();
      for (final item in items) {
        _userItems[makeKey(item.mediaType, item.mediaId)] = item;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar ítems de ocio del usuario: $e');
    }
  }

  /// Maneja cambios en el campo de búsqueda con Debounce (400ms)
  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _isSearching = false;
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(query);
    });
  }

  /// Ejecuta la búsqueda cancelando resultados obsoletos mediante searchId
  Future<void> _executeSearch(String query) async {
    final searchId = ++_activeSearchId;
    try {
      final results = await _repository.searchMedia(
        query: query,
        type: _selectedType,
      );
      if (searchId == _activeSearchId) {
        _searchResults = results;
        _isSearching = false;
        notifyListeners();
      }
    } catch (e) {
      if (searchId == _activeSearchId) {
        _errorMessage = 'Error en la búsqueda: $e';
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Limpia la búsqueda y vuelve al catálogo
  void clearSearch() {
    _debounceTimer?.cancel();
    _searchQuery = '';
    _isSearching = false;
    _searchResults = [];
    notifyListeners();
  }

  // ===========================================================================
  // ACTUALIZACIONES OPTIMISTAS (Progreso personal y Rating 1.0 - 10.0)
  // ===========================================================================

  /// Alterna o actualiza el estado y calificación personal con actualización optimista
  Future<void> setUserItemStatus({
    required LeisureMediaDetails media,
    required LeisureItemStatus? newStatus,
    double? rating,
    String? notes,
  }) async {
    if (_currentUserId == null) return;

    final key = makeKey(media.mediaType, media.mediaId);
    final previousItem = _userItems[key];

    // 1. Actualización optimista inmediata en memoria
    if (newStatus == null && rating == null && (notes == null || notes.isEmpty)) {
      _userItems.remove(key);
    } else {
      final now = DateTime.now();
      final updated = LeisureUserItemModel(
        id: previousItem?.id ?? 'temp_${now.millisecondsSinceEpoch}',
        userId: _currentUserId!,
        mediaId: media.mediaId,
        mediaType: media.mediaType,
        status: newStatus ?? previousItem?.status,
        rating: rating ?? previousItem?.rating,
        notes: notes ?? previousItem?.notes,
        createdAt: previousItem?.createdAt ?? now,
        updatedAt: now,
      );
      _userItems[key] = updated;
    }
    notifyListeners();

    // 2. Confirmación asíncrona contra Supabase
    try {
      if (newStatus == null && rating == null && (notes == null || notes.isEmpty)) {
        await _repository.deleteUserItem(
          mediaId: media.mediaId,
          type: media.mediaType,
        );
      } else {
        final now = DateTime.now();
        final payload = LeisureUserItemModel(
          id: previousItem?.id ?? '',
          userId: _currentUserId!,
          mediaId: media.mediaId,
          mediaType: media.mediaType,
          status: newStatus ?? previousItem?.status,
          rating: rating ?? previousItem?.rating,
          notes: notes ?? previousItem?.notes,
          createdAt: previousItem?.createdAt ?? now,
          updatedAt: now,
        );
        final persisted = await _repository.saveUserItem(payload);
        _userItems[key] = persisted;
        notifyListeners();
      }
    } catch (e) {
      // Revertir estado optimista en caso de fallo
      if (previousItem != null) {
        _userItems[key] = previousItem;
      } else {
        _userItems.remove(key);
      }
      _errorMessage = 'No se pudo guardar el progreso: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Actualiza la calificación numérica (1.0 a 10.0 en incrementos de 0.1)
  Future<void> updateRating(LeisureMediaDetails media, double? newRating) async {
    final key = makeKey(media.mediaType, media.mediaId);
    final current = _userItems[key];
    await setUserItemStatus(
      media: media,
      newStatus: current?.status,
      rating: newRating,
    );
  }

  /// Añade o quita un elemento del conjunto de ruleta
  bool toggleRouletteItem(LeisureMediaDetails media) {
    final key = makeKey(media.mediaType, media.mediaId);
    final wasSelected = _rouletteMediaKeys.contains(key);
    if (wasSelected) {
      _rouletteMediaKeys.remove(key);
    } else {
      _rouletteMediaKeys.add(key);
    }
    notifyListeners();
    return !wasSelected;
  }

  // ===========================================================================
  // LISTAS COMPARTIDAS DEL ENTORNO
  // ===========================================================================

  Future<void> loadSharedLists() async {
    if (_isPersonalEnvironment || _currentEnvironmentId == null) return;
    try {
      _sharedLists = await _repository.getSharedLists(
        environmentId: _currentEnvironmentId!,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar listas compartidas del entorno: $e');
    }
  }

  Future<List<LeisureSharedListItemModel>> getSharedListItems(String listId) async {
    try {
      final items = await _repository.getSharedListItems(listId: listId);
      _sharedListItemsMap[listId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      debugPrint('Error al cargar elementos de lista compartida: $e');
      return _sharedListItemsMap[listId] ?? [];
    }
  }

  Future<LeisureSharedListModel> createSharedList(String title, String? description) async {
    if (_isPersonalEnvironment || _currentEnvironmentId == null) {
      throw Exception('Las listas compartidas requieren un entorno colaborativo');
    }

    final created = await _repository.createSharedList(
      environmentId: _currentEnvironmentId!,
      title: title,
      description: description,
    );
    _sharedLists = [created, ..._sharedLists];
    notifyListeners();
    return created;
  }

  Future<void> addMediaToSharedList(String listId, LeisureMediaDetails media) async {
    final item = await _repository.addSharedListItem(
      listId: listId,
      mediaId: media.mediaId,
      mediaType: media.mediaType,
      title: media.title,
      posterUrl: media.posterUrl,
      detailsToCache: media,
    );

    final current = _sharedListItemsMap[listId] ?? [];
    _sharedListItemsMap[listId] = [...current, item];
    notifyListeners();
  }

  Future<void> removeMediaFromSharedList(String itemId, String listId) async {
    await _repository.removeSharedListItem(itemId: itemId);
    final current = _sharedListItemsMap[listId] ?? [];
    _sharedListItemsMap[listId] = current.where((i) => i.id != itemId).toList();
    notifyListeners();
  }

  // ===========================================================================
  // MATCHES DE GUSTOS (WATCH PARTY)
  // ===========================================================================

  Future<void> loadEnvironmentMatches() async {
    if (_isPersonalEnvironment || _currentEnvironmentId == null) return;
    try {
      _environmentMatches = await _repository.getEnvironmentMatches(
        environmentId: _currentEnvironmentId!,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar matches del entorno: $e');
    }
  }

  // ===========================================================================
  // CONSULTAS DETALLADAS CON CACHÉ (Temporadas TV y Ediciones de Libros)
  // ===========================================================================

  Future<LeisureMediaDetails> getMediaDetails(String mediaId, LeisureMediaType type) {
    return _repository.getMediaDetails(mediaId: mediaId, type: type);
  }

  Future<TvSeasonDetailsDto> getTvSeasonDetails(String seriesId, int seasonNumber) {
    return _repository.getTvSeasonDetails(
      seriesId: seriesId,
      seasonNumber: seasonNumber,
    );
  }

  Future<List<BookEditionDto>> getBookEditions(String workId) {
    return _repository.getBookEditions(workId: workId);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
