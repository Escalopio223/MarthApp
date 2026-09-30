import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/food_category_model.dart';
import '../../domain/models/food_favorite_model.dart';
import '../../domain/models/recipe_ingredient_model.dart';
import '../../domain/models/recipe_model.dart';
import '../../domain/repositories/i_food_repository.dart';
import '../../infrastructure/services/food_service.dart';

/// Controlador reactivo para el catálogo de recetas y la gestión de favoritos
class FoodCatalogController extends ChangeNotifier {
  final IFoodRepository _repository;

  String? _currentEnvironmentId;
  String? _currentUserId;

  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  // Filtros activos
  String _searchQuery = '';
  String? _selectedCuisine;
  bool _filterAirfryer = false;
  bool _filterOven = false;
  bool _filterMicrowave = false;
  int _activeViewIndex = 0; // 0: Explorar Catálogo, 1: Favoritos Rápidos

  Timer? _debounceTimer;

  // Datos en memoria
  List<RecipeModel> _recipes = [];
  List<FoodFavoriteModel> _favorites = [];
  List<FoodCategoryModel> _categories = [];

  // Lookups optimizados O(1)
  final Set<String> _favoriteRecipeIds = {};
  final Set<String> _favoriteIngredientNames = {};
  final Map<String, String> _favoriteIdByRecipeId = {};
  final Map<String, String> _favoriteIdByIngredientName = {};

  FoodCatalogController({IFoodRepository? repository})
      : _repository = repository ?? FoodService();

  // Getters
  String? get currentEnvironmentId => _currentEnvironmentId;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCuisine => _selectedCuisine;
  bool get filterAirfryer => _filterAirfryer;
  bool get filterOven => _filterOven;
  bool get filterMicrowave => _filterMicrowave;
  int get activeViewIndex => _activeViewIndex;

  List<RecipeModel> get recipes => _recipes;
  List<FoodFavoriteModel> get favorites => _favorites;
  List<FoodCategoryModel> get categories => _categories;
  Set<String> get favoriteRecipeIds => _favoriteRecipeIds;
  Set<String> get favoriteIngredientNames => _favoriteIngredientNames;

  List<FoodFavoriteModel> get favoriteRecipes =>
      _favorites.where((f) => f.isRecipe && f.recipe != null).toList();

  List<FoodFavoriteModel> get favoriteIngredients =>
      _favorites.where((f) => f.isIngredient).toList();

  bool isRecipeFavorite(String recipeId) => _favoriteRecipeIds.contains(recipeId);
  bool isIngredientFavorite(String name) =>
      _favoriteIngredientNames.contains(name.toLowerCase().trim());

  /// Inicialización con el entorno y usuario activo
  Future<void> initialize({
    required String environmentId,
    required String userId,
  }) async {
    _currentEnvironmentId = environmentId;
    _currentUserId = userId;
    await Future.wait([
      loadCategories(),
      loadFavorites(),
      loadRecipes(),
    ]);
  }

  /// Cambio de entorno activo
  Future<void> setEnvironmentId(String environmentId) async {
    if (_currentEnvironmentId == environmentId) return;
    _currentEnvironmentId = environmentId;
    await Future.wait([
      loadFavorites(),
      loadRecipes(),
    ]);
  }

  void setActiveViewIndex(int index) {
    if (_activeViewIndex == index) return;
    _activeViewIndex = index;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CARGA DE DATOS
  // ---------------------------------------------------------------------------

  Future<void> loadCategories() async {
    try {
      _categories = await _repository.getCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('[FoodCatalogController] Error al cargar categorías: $e');
    }
  }

  Future<void> loadFavorites() async {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) return;

    try {
      _favorites = await _repository.getFavorites(envId);
      _rebuildFavoriteLookups();
      notifyListeners();
    } catch (e) {
      debugPrint('[FoodCatalogController] Error al cargar favoritos: $e');
    }
  }

  void _rebuildFavoriteLookups() {
    _favoriteRecipeIds.clear();
    _favoriteIngredientNames.clear();
    _favoriteIdByRecipeId.clear();
    _favoriteIdByIngredientName.clear();

    for (final fav in _favorites) {
      if (fav.isRecipe && fav.recipeId != null) {
        _favoriteRecipeIds.add(fav.recipeId!);
        _favoriteIdByRecipeId[fav.recipeId!] = fav.id;
      } else if (fav.isIngredient && fav.ingredientName != null) {
        final norm = fav.ingredientName!.toLowerCase().trim();
        _favoriteIngredientNames.add(norm);
        _favoriteIdByIngredientName[norm] = fav.id;
      }
    }
  }

  Future<void> loadRecipes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _recipes = await _repository.getRecipes(
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        cuisineType: _selectedCuisine,
        environmentId: _currentEnvironmentId,
        onlyAirfryer: _filterAirfryer ? true : null,
        onlyOven: _filterOven ? true : null,
        onlyMicrowave: _filterMicrowave ? true : null,
        limit: 80,
      );
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las recetas: $e';
      debugPrint('[FoodCatalogController] Error en loadRecipes: $e');
    } finally {
      _isLoading = false;
      _isSearching = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // FILTRADO Y BÚSQUEDA REACTIVA CON DEBOUNCE
  // ---------------------------------------------------------------------------

  void onSearchQueryChanged(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      loadRecipes();
    });
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _debounceTimer?.cancel();
    loadRecipes();
  }

  void selectCuisine(String? cuisine) {
    if (_selectedCuisine == cuisine) {
      _selectedCuisine = null;
    } else {
      _selectedCuisine = cuisine;
    }
    loadRecipes();
  }

  void toggleAirfryerFilter() {
    _filterAirfryer = !_filterAirfryer;
    loadRecipes();
  }

  void toggleOvenFilter() {
    _filterOven = !_filterOven;
    loadRecipes();
  }

  void toggleMicrowaveFilter() {
    _filterMicrowave = !_filterMicrowave;
    loadRecipes();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCuisine = null;
    _filterAirfryer = false;
    _filterOven = false;
    _filterMicrowave = false;
    loadRecipes();
  }

  // ---------------------------------------------------------------------------
  // GESTIÓN DE FAVORITOS (OPTIMISTIC UPDATES)
  // ---------------------------------------------------------------------------

  Future<void> toggleFavoriteRecipe(RecipeModel recipe) async {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) return;

    final recipeId = recipe.id;
    final isFav = isRecipeFavorite(recipeId);

    if (isFav) {
      final favId = _favoriteIdByRecipeId[recipeId];
      if (favId == null) return;

      // Optimistic remove
      _favoriteRecipeIds.remove(recipeId);
      _favoriteIdByRecipeId.remove(recipeId);
      _favorites.removeWhere((f) => f.id == favId);
      notifyListeners();

      try {
        await _repository.removeFavorite(favId);
      } catch (e) {
        debugPrint('[FoodCatalogController] Error al eliminar receta favorita: $e');
        await loadFavorites(); // Revertir en caso de fallo
      }
    } else {
      // Optimistic add
      _favoriteRecipeIds.add(recipeId);
      final tempFav = FoodFavoriteModel(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        environmentId: envId,
        itemType: FoodFavoriteType.recipe,
        recipeId: recipeId,
        createdAt: DateTime.now(),
        recipe: recipe,
      );
      _favorites.insert(0, tempFav);
      notifyListeners();

      try {
        final realFav = await _repository.addFavoriteRecipe(
          environmentId: envId,
          recipeId: recipeId,
        );
        _favoriteIdByRecipeId[recipeId] = realFav.id;
        final index = _favorites.indexWhere((f) => f.id == tempFav.id);
        if (index != -1) {
          _favorites[index] = realFav;
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[FoodCatalogController] Error al añadir receta favorita: $e');
        await loadFavorites();
      }
    }
  }

  Future<void> addFavoriteIngredient(String rawName) async {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) return;

    final name = rawName.toLowerCase().trim();
    if (name.isEmpty || isIngredientFavorite(name)) return;

    // Optimistic add
    _favoriteIngredientNames.add(name);
    final tempFav = FoodFavoriteModel(
      id: 'temp-ing-${DateTime.now().millisecondsSinceEpoch}',
      environmentId: envId,
      itemType: FoodFavoriteType.ingredient,
      ingredientName: name,
      createdAt: DateTime.now(),
    );
    _favorites.insert(0, tempFav);
    notifyListeners();

    try {
      final realFav = await _repository.addFavoriteIngredient(
        environmentId: envId,
        ingredientName: name,
      );
      _favoriteIdByIngredientName[name] = realFav.id;
      final index = _favorites.indexWhere((f) => f.id == tempFav.id);
      if (index != -1) {
        _favorites[index] = realFav;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[FoodCatalogController] Error al añadir ingrediente favorito: $e');
      await loadFavorites();
    }
  }

  Future<void> removeFavoriteIngredient(String rawName) async {
    final name = rawName.toLowerCase().trim();
    final favId = _favoriteIdByIngredientName[name];
    if (favId == null) return;

    // Optimistic remove
    _favoriteIngredientNames.remove(name);
    _favoriteIdByIngredientName.remove(name);
    _favorites.removeWhere((f) => f.id == favId);
    notifyListeners();

    try {
      await _repository.removeFavorite(favId);
    } catch (e) {
      debugPrint('[FoodCatalogController] Error al eliminar ingrediente favorito: $e');
      await loadFavorites();
    }
  }

  // ---------------------------------------------------------------------------
  // CREACIÓN RÁPIDA DE RECETA CASERA (<20s)
  // ---------------------------------------------------------------------------

  Future<RecipeModel?> createQuickRecipe({
    required String title,
    String? country,
    String? cuisineType,
    required List<String> ingredientNames,
    String? prepOven,
    String? prepAirfryer,
    String? prepMicrowave,
  }) async {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) {
      throw StateError('Debes seleccionar un entorno antes de registrar una receta.');
    }

    try {
      final fallbackCategoryId = _categories.isNotEmpty
          ? _categories.first.id
          : '00000000-0000-0000-0000-000000000003';

      final newRecipe = RecipeModel(
        id: '',
        title: title.trim(),
        country: (country != null && country.trim().isNotEmpty) ? country.trim() : 'Casera',
        cuisineType: (cuisineType != null && cuisineType.trim().isNotEmpty)
            ? cuisineType.trim()
            : 'Tradicional',
        prepOven: prepOven?.trim().isNotEmpty == true ? prepOven!.trim() : null,
        prepAirfryer: prepAirfryer?.trim().isNotEmpty == true ? prepAirfryer!.trim() : null,
        prepMicrowave: prepMicrowave?.trim().isNotEmpty == true ? prepMicrowave!.trim() : null,
        isGlobal: false,
        environmentId: envId,
        createdAt: DateTime.now(),
      );

      final ingredients = ingredientNames.map((name) {
        return RecipeIngredientModel(
          id: '',
          recipeId: '',
          name: name.toLowerCase().trim(),
          categoryId: fallbackCategoryId,
          createdAt: DateTime.now(),
        );
      }).toList();

      final created = await _repository.createCustomRecipe(
        recipe: newRecipe,
        ingredients: ingredients,
      );

      // Insertar de inmediato al principio del catálogo en memoria
      _recipes.insert(0, created);
      notifyListeners();

      return created;
    } catch (e) {
      debugPrint('[FoodCatalogController] Error al crear receta rápida: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
