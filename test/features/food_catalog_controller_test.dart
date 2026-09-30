import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/food/domain/models/active_calendar_slot_model.dart';
import 'package:marth_app/features/food/domain/models/food_category_model.dart';
import 'package:marth_app/features/food/domain/models/food_favorite_model.dart';
import 'package:marth_app/features/food/domain/models/recipe_ingredient_model.dart';
import 'package:marth_app/features/food/domain/models/recipe_model.dart';
import 'package:marth_app/features/food/domain/models/saved_weekly_menu_model.dart';
import 'package:marth_app/features/food/domain/models/saved_weekly_menu_slot_model.dart';
import 'package:marth_app/features/food/domain/models/shopping_list_item_model.dart';
import 'package:marth_app/features/food/domain/repositories/i_food_repository.dart';
import 'package:marth_app/features/food/presentation/controllers/food_catalog_controller.dart';

class MockFoodRepository implements IFoodRepository {
  List<RecipeModel> recipesStorage = [
    RecipeModel(
      id: 'rec-1',
      title: 'Pollo crujiente en airfryer',
      country: 'España',
      cuisineType: 'Airfryer',
      prepAirfryer: '180°C durante 15 min',
      createdAt: DateTime.now(),
      ingredients: [
        RecipeIngredientModel(
          id: 'ing-1',
          recipeId: 'rec-1',
          name: 'pechuga de pollo',
          categoryId: '00000000-0000-0000-0000-000000000004',
          createdAt: DateTime.now(),
        ),
      ],
    ),
    RecipeModel(
      id: 'rec-2',
      title: 'Lasaña boloñesa al horno',
      country: 'Italia',
      cuisineType: 'Italiana',
      prepOven: '190°C durante 30 min',
      createdAt: DateTime.now(),
    ),
  ];

  List<FoodFavoriteModel> favoritesStorage = [];

  @override
  Future<List<FoodCategoryModel>> getCategories() async {
    return [
      FoodCategoryModel(
        id: '00000000-0000-0000-0000-000000000001',
        name: 'Lácteos',
        iconSlug: FoodCategorySlug.dairy,
        createdAt: DateTime.now(),
      ),
      FoodCategoryModel(
        id: '00000000-0000-0000-0000-000000000003',
        name: 'Verduras',
        iconSlug: FoodCategorySlug.vegetable,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<RecipeModel>> getRecipes({
    String? query,
    String? cuisineType,
    String? country,
    String? environmentId,
    bool? onlyAirfryer,
    bool? onlyOven,
    bool? onlyMicrowave,
    int limit = 50,
    int offset = 0,
  }) async {
    return recipesStorage.where((r) {
      if (query != null && !r.title.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }
      if (cuisineType != null && r.cuisineType != cuisineType) {
        return false;
      }
      if (onlyAirfryer == true && !r.hasAirfryer) {
        return false;
      }
      if (onlyOven == true && !r.hasOven) {
        return false;
      }
      if (onlyMicrowave == true && !r.hasMicrowave) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<RecipeModel?> getRecipeById(String recipeId) async {
    final matches = recipesStorage.where((r) => r.id == recipeId);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<RecipeModel> createCustomRecipe({
    required RecipeModel recipe,
    required List<RecipeIngredientModel> ingredients,
  }) async {
    final created = recipe.copyWith(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      ingredients: ingredients,
    );
    recipesStorage.insert(0, created);
    return created;
  }

  @override
  Future<RecipeModel> updateCustomRecipe({
    required RecipeModel recipe,
    required List<RecipeIngredientModel> ingredients,
  }) async => recipe;

  @override
  Future<void> deleteCustomRecipe(String recipeId) async {
    recipesStorage.removeWhere((r) => r.id == recipeId);
  }

  @override
  Future<List<FoodFavoriteModel>> getFavorites(String environmentId) async {
    return favoritesStorage.where((f) => f.environmentId == environmentId).toList();
  }

  @override
  Future<FoodFavoriteModel> addFavoriteRecipe({
    required String environmentId,
    required String recipeId,
  }) async {
    final recipe = await getRecipeById(recipeId);
    final fav = FoodFavoriteModel(
      id: 'fav-rec-${DateTime.now().millisecondsSinceEpoch}',
      environmentId: environmentId,
      itemType: FoodFavoriteType.recipe,
      recipeId: recipeId,
      createdAt: DateTime.now(),
      recipe: recipe,
    );
    favoritesStorage.insert(0, fav);
    return fav;
  }

  @override
  Future<FoodFavoriteModel> addFavoriteIngredient({
    required String environmentId,
    required String ingredientName,
  }) async {
    final fav = FoodFavoriteModel(
      id: 'fav-ing-${DateTime.now().millisecondsSinceEpoch}',
      environmentId: environmentId,
      itemType: FoodFavoriteType.ingredient,
      ingredientName: ingredientName,
      createdAt: DateTime.now(),
    );
    favoritesStorage.insert(0, fav);
    return fav;
  }

  @override
  Future<void> removeFavorite(String favoriteId) async {
    favoritesStorage.removeWhere((f) => f.id == favoriteId);
  }

  @override
  Future<List<SavedWeeklyMenuModel>> getSavedWeeklyMenus(String environmentId) async => [];
  @override
  Future<SavedWeeklyMenuModel?> getSavedWeeklyMenuById(String menuId) async => null;
  @override
  Future<SavedWeeklyMenuModel> createSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async => menu;
  @override
  Future<SavedWeeklyMenuModel> updateSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async => menu;
  @override
  Future<SavedWeeklyMenuModel> renameSavedWeeklyMenu({
    required String menuId,
    required String newName,
    String? newDescription,
  }) async {
    return SavedWeeklyMenuModel(
      id: menuId,
      environmentId: 'env-1',
      name: newName,
      description: newDescription,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteSavedWeeklyMenu(String menuId) async {}
  @override
  Future<List<ActiveCalendarSlotModel>> getActiveCalendarSlots({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async => [];
  @override
  Future<ActiveCalendarSlotModel> upsertActiveCalendarSlot(ActiveCalendarSlotModel slot) async => slot;
  @override
  Future<void> deleteActiveCalendarSlot(String slotId) async {}
  @override
  Future<void> applySavedMenuToCalendar({
    required String environmentId,
    required String savedMenuId,
    required DateTime mondayStartDate,
    bool overwrite = true,
  }) async {}

  @override
  Future<SavedWeeklyMenuModel> saveActiveWeekAsMenu({
    required String environmentId,
    required String name,
    String? description,
    required DateTime mondayStartDate,
  }) async {
    return SavedWeeklyMenuModel(
      id: 'saved-${DateTime.now().millisecondsSinceEpoch}',
      environmentId: environmentId,
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
  }

  @override
  dynamic subscribeToActiveCalendar(
    String environmentId,
    void Function() onCalendarChanged,
  ) => null;

  @override
  Future<void> unsubscribe(dynamic channel) async {}
  @override
  Future<List<ShoppingListItemModel>> getShoppingList(String environmentId) async => [];
  @override
  Future<void> toggleShoppingListItem({required String itemId, required bool isChecked}) async {}
  @override
  Future<ShoppingListItemModel> addShoppingListItem(ShoppingListItemModel item) async => item;
  @override
  Future<void> removeShoppingListItem(String itemId) async {}
  @override
  Future<void> clearCheckedShoppingListItems(String environmentId) async {}
  @override
  Future<void> syncShoppingListFromActiveCalendar({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {}
}

void main() {
  late MockFoodRepository mockRepo;
  late FoodCatalogController controller;

  setUp(() {
    mockRepo = MockFoodRepository();
    controller = FoodCatalogController(repository: mockRepo);
  });

  tearDown(() {
    controller.dispose();
  });

  group('FoodCatalogController', () {
    test('Inicializa y carga catálogo, categorías y favoritos correctamente', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      expect(controller.recipes.length, 2);
      expect(controller.categories.length, 2);
      expect(controller.favorites, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('Filtra recetas por electrodomésticos (Airfryer / Horno)', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      controller.toggleAirfryerFilter();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.recipes.length, 1);
      expect(controller.recipes.first.title, contains('airfryer'));

      controller.toggleAirfryerFilter(); // desactiva airfryer
      controller.toggleOvenFilter();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.recipes.length, 1);
      expect(controller.recipes.first.title, contains('horno'));
    });

    test('Gestión reactiva de recetas favoritas (añadir y quitar)', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');
      final recipe = controller.recipes.first;

      expect(controller.isRecipeFavorite(recipe.id), isFalse);

      // Añadir a favoritos
      await controller.toggleFavoriteRecipe(recipe);
      expect(controller.isRecipeFavorite(recipe.id), isTrue);
      expect(controller.favoriteRecipes.length, 1);

      // Quitar de favoritos
      await controller.toggleFavoriteRecipe(recipe);
      expect(controller.isRecipeFavorite(recipe.id), isFalse);
      expect(controller.favoriteRecipes, isEmpty);
    });

    test('Gestión de ingredientes favoritos recurrentes', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      await controller.addFavoriteIngredient('Yogur griego');
      expect(controller.isIngredientFavorite('yogur griego'), isTrue);
      expect(controller.favoriteIngredients.length, 1);

      await controller.removeFavoriteIngredient('yogur griego');
      expect(controller.isIngredientFavorite('yogur griego'), isFalse);
      expect(controller.favoriteIngredients, isEmpty);
    });

    test('Creación ultra-rápida de receta casera', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      final created = await controller.createQuickRecipe(
        title: 'Revuelto exprés de setas',
        country: 'España',
        cuisineType: 'Rápida',
        ingredientNames: ['setas', 'huevo', 'ajo'],
        prepAirfryer: '180°C 8 min',
      );

      expect(created, isNotNull);
      expect(created!.title, 'Revuelto exprés de setas');
      expect(controller.recipes.first.title, 'Revuelto exprés de setas');
      expect(controller.recipes.length, 3);
    });
  });
}
