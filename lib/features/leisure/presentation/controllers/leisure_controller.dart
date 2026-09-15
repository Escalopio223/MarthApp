import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/models/book_edition_dto.dart';
import '../../domain/models/leisure_environment_match_model.dart';
import '../../domain/models/leisure_item_status.dart';
import '../../domain/models/leisure_list_sort_option.dart';
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

  // Mapa de elementos añadidos a la ruleta indexados por 'mediaType_mediaId'
  final Map<String, LeisureMediaDetails> _rouletteItems = {};

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
  int get rouletteCount => _rouletteItems.length;
  List<LeisureMediaDetails> get rouletteItems => _rouletteItems.values.toList();

  /// Clave canónica compuesta para lookup en mapas
  static String makeKey(LeisureMediaType type, String mediaId) =>
      '${type.toValue()}_$mediaId';

  /// Obtiene el progreso del usuario para un medio si existe
  LeisureUserItemModel? getUserItem(LeisureMediaType type, String mediaId) {
    return _userItems[makeKey(type, mediaId)];
  }

  /// Verifica si un medio está seleccionado para la ruleta
  bool isRouletteSelected(LeisureMediaType type, String mediaId) {
    return _rouletteItems.containsKey(makeKey(type, mediaId));
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
      if (environmentId != null) ...[
        loadSharedLists(),
        if (!isPersonal) loadEnvironmentMatches(),
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

    if (environmentId != null) {
      await Future.wait([
        loadSharedLists(),
        if (!isPersonal) loadEnvironmentMatches(),
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

  // Caché en memoria de catálogos cargados por medio para navegación instantánea
  final Map<LeisureMediaType, List<LeisureMediaDetails>> _cachedCatalogs = {};

  /// Carga el catálogo principal según el tipo seleccionado
  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedCatalogs.containsKey(_selectedType) &&
        _cachedCatalogs[_selectedType]!.isNotEmpty) {
      _catalogItems = _cachedCatalogs[_selectedType]!;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_selectedType == LeisureMediaType.movie) {
        _catalogItems = await _repository.getNowPlayingMovies(region: 'ES');
      } else {
        _catalogItems = await _repository.getPopularMedia(type: _selectedType);
      }
      _cachedCatalogs[_selectedType] = _catalogItems;
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
    final wasSelected = _rouletteItems.containsKey(key);
    if (wasSelected) {
      _rouletteItems.remove(key);
    } else {
      _rouletteItems[key] = media;
    }
    notifyListeners();
    return !wasSelected;
  }

  /// Limpia manualmente todos los elementos seleccionados para los dados
  void clearRoulette() {
    if (_rouletteItems.isNotEmpty) {
      _rouletteItems.clear();
      notifyListeners();
    }
  }

  /// Realiza la tirada del dado seleccionando un ganador al azar
  /// y limpia automáticamente los elementos seleccionados.
  LeisureMediaDetails? rollRoulette() {
    if (_rouletteItems.isEmpty) return null;
    final items = _rouletteItems.values.toList();
    final randomIndex = Random().nextInt(items.length);
    final winner = items[randomIndex];
    _rouletteItems.clear();
    notifyListeners();
    return winner;
  }

  // ===========================================================================
  // LISTAS COMPARTIDAS DEL ENTORNO
  // ===========================================================================

  Future<void> loadSharedLists() async {
    if (_currentEnvironmentId == null) return;
    try {
      final lists = await _repository.getSharedLists(
        environmentId: _currentEnvironmentId!,
      );
      _sharedLists = List<LeisureSharedListModel>.from(lists);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar listas compartidas del entorno: $e');
    }
  }

  List<LeisureSharedListItemModel> getCachedListItems(String listId) {
    return _sharedListItemsMap[listId] ?? const [];
  }

  bool hasCachedListItems(String listId) {
    return _sharedListItemsMap.containsKey(listId);
  }

  Future<List<LeisureSharedListItemModel>> getSharedListItems(
    String listId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _sharedListItemsMap.containsKey(listId)) {
      return _sharedListItemsMap[listId]!;
    }

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
    if (_currentEnvironmentId == null) {
      throw Exception('Selecciona un entorno para crear una lista');
    }

    final created = await _repository.createSharedList(
      environmentId: _currentEnvironmentId!,
      title: title,
      description: description,
    );
    _sharedLists = [created, ..._sharedLists.where((l) => l.id != created.id)];
    notifyListeners();
    return created;
  }

  final Map<String, LeisureListSortOption> _listSortOptions = {};
  final Map<String, String?> _listGenreFilters = {};
  final Map<String, String> _listSearchQueries = {};

  LeisureListSortOption getListSortOption(String listId) {
    return _listSortOptions[listId] ?? LeisureListSortOption.manual;
  }

  void setListSortOption(String listId, LeisureListSortOption option) {
    _listSortOptions[listId] = option;
    notifyListeners();
  }

  String? getListGenreFilter(String listId) {
    return _listGenreFilters[listId];
  }

  void setListGenreFilter(String listId, String? genre) {
    _listGenreFilters[listId] = genre;
    notifyListeners();
  }

  String getListSearchQuery(String listId) {
    return _listSearchQueries[listId] ?? '';
  }

  void setListSearchQuery(String listId, String query) {
    _listSearchQueries[listId] = query;
    notifyListeners();
  }

  void clearListFilters(String listId) {
    _listGenreFilters[listId] = null;
    _listSearchQueries[listId] = '';
    notifyListeners();
  }

  List<String> getAvailableGenresForList(String listId) {
    final items = _sharedListItemsMap[listId] ?? [];
    final set = <String>{};
    for (final item in items) {
      for (final g in item.genres) {
        if (g.trim().isNotEmpty) {
          set.add(g.trim());
        }
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<LeisureSharedListItemModel> getFilteredAndSortedItems(String listId) {
    var items = List<LeisureSharedListItemModel>.from(_sharedListItemsMap[listId] ?? []);

    // 1. Filtrado por género
    final genre = _listGenreFilters[listId];
    if (genre != null && genre.isNotEmpty) {
      items = items.where((item) =>
          item.genres.any((g) => g.trim().toLowerCase() == genre.trim().toLowerCase())
      ).toList();
    }

    // 2. Filtrado por buscador rápido
    final query = (_listSearchQueries[listId] ?? '').trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((item) =>
          item.title.toLowerCase().contains(query)
      ).toList();
    }

    // 3. Ordenación
    final sort = getListSortOption(listId);
    switch (sort) {
      case LeisureListSortOption.manual:
        items.sort((a, b) {
          final comp = a.customOrder.compareTo(b.customOrder);
          if (comp != 0) return comp;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case LeisureListSortOption.ratingDesc:
        items.sort((a, b) {
          if (a.rating == null && b.rating == null) return 0;
          if (a.rating == null) return 1;
          if (b.rating == null) return -1;
          return b.rating!.compareTo(a.rating!);
        });
        break;
      case LeisureListSortOption.ratingAsc:
        items.sort((a, b) {
          if (a.rating == null && b.rating == null) return 0;
          if (a.rating == null) return 1;
          if (b.rating == null) return -1;
          return a.rating!.compareTo(b.rating!);
        });
        break;
      case LeisureListSortOption.yearDesc:
        items.sort((a, b) {
          final yearA = int.tryParse(a.year ?? '');
          final yearB = int.tryParse(b.year ?? '');
          if (yearA == null && yearB == null) return 0;
          if (yearA == null) return 1;
          if (yearB == null) return -1;
          return yearB.compareTo(yearA);
        });
        break;
      case LeisureListSortOption.yearAsc:
        items.sort((a, b) {
          final yearA = int.tryParse(a.year ?? '');
          final yearB = int.tryParse(b.year ?? '');
          if (yearA == null && yearB == null) return 0;
          if (yearA == null) return 1;
          if (yearB == null) return -1;
          return yearA.compareTo(yearB);
        });
        break;
      case LeisureListSortOption.dateAddedDesc:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case LeisureListSortOption.titleAsc:
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return items;
  }

  Future<void> reorderSharedListItems(String listId, int oldIndex, int newIndex) async {
    final current = List<LeisureSharedListItemModel>.from(_sharedListItemsMap[listId] ?? []);
    if (oldIndex < 0 || oldIndex >= current.length) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0 || newIndex >= current.length) return;

    // Cambiar automáticamente a orden manual al arrastrar
    _listSortOptions[listId] = LeisureListSortOption.manual;

    final movedItem = current.removeAt(oldIndex);
    current.insert(newIndex, movedItem);

    // Reasignar índices de orden secuencial
    final updatedList = <LeisureSharedListItemModel>[];
    for (int i = 0; i < current.length; i++) {
      updatedList.add(current[i].copyWith(customOrder: i));
    }

    _sharedListItemsMap[listId] = updatedList;
    notifyListeners();

    try {
      await _repository.reorderSharedListItems(
        listId: listId,
        orderedItemIds: updatedList.map((e) => e.id).toList(),
      );
    } catch (e) {
      debugPrint('Aviso al persistir reordenación en repositorio: $e');
    }
  }

  Future<void> addMediaToSharedList(String listId, LeisureMediaDetails media) async {
    final current = _sharedListItemsMap[listId] ?? [];
    final item = await _repository.addSharedListItem(
      listId: listId,
      mediaId: media.mediaId,
      mediaType: media.mediaType,
      title: media.title,
      posterUrl: media.posterUrl,
      year: media.year,
      rating: media.rating,
      genres: media.genres,
      customOrder: current.length,
      detailsToCache: media,
    );

    _sharedListItemsMap[listId] = [...current, item];

    // Actualizar el contador de ítems en la lista correspondiente
    _sharedLists = _sharedLists.map((l) {
      if (l.id == listId) {
        return LeisureSharedListModel(
          id: l.id,
          environmentId: l.environmentId,
          createdBy: l.createdBy,
          title: l.title,
          description: l.description,
          itemsCount: l.itemsCount + 1,
          createdAt: l.createdAt,
        );
      }
      return l;
    }).toList();

    notifyListeners();
  }

  Future<void> removeMediaFromSharedList(String itemId, String listId) async {
    await _repository.removeSharedListItem(itemId: itemId);
    final current = _sharedListItemsMap[listId] ?? [];
    _sharedListItemsMap[listId] = current.where((i) => i.id != itemId).toList();

    // Decrementar el contador de ítems en la lista correspondiente
    _sharedLists = _sharedLists.map((l) {
      if (l.id == listId) {
        return LeisureSharedListModel(
          id: l.id,
          environmentId: l.environmentId,
          createdBy: l.createdBy,
          title: l.title,
          description: l.description,
          itemsCount: (l.itemsCount - 1).clamp(0, 999999),
          createdAt: l.createdAt,
        );
      }
      return l;
    }).toList();

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
