import '../models/active_calendar_slot_model.dart';
import '../models/food_category_model.dart';
import '../models/food_favorite_model.dart';
import '../models/recipe_ingredient_model.dart';
import '../models/recipe_model.dart';
import '../models/saved_weekly_menu_model.dart';
import '../models/saved_weekly_menu_slot_model.dart';
import '../models/shopping_list_item_model.dart';

/// Contrato del repositorio para el módulo de alimentación
abstract class IFoodRepository {
  // 1. Categorías
  Future<List<FoodCategoryModel>> getCategories();

  // 2. Catálogo de Recetas
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
  });

  Future<RecipeModel?> getRecipeById(String recipeId);

  Future<RecipeModel> createCustomRecipe({
    required RecipeModel recipe,
    required List<RecipeIngredientModel> ingredients,
  });

  Future<RecipeModel> updateCustomRecipe({
    required RecipeModel recipe,
    required List<RecipeIngredientModel> ingredients,
  });

  Future<void> deleteCustomRecipe(String recipeId);

  // 3. Favoritos del Entorno
  Future<List<FoodFavoriteModel>> getFavorites(String environmentId);

  Future<FoodFavoriteModel> addFavoriteRecipe({
    required String environmentId,
    required String recipeId,
  });

  Future<FoodFavoriteModel> addFavoriteIngredient({
    required String environmentId,
    required String ingredientName,
  });

  Future<void> removeFavorite(String favoriteId);

  // 4. Biblioteca de Menús Semanales Guardados
  Future<List<SavedWeeklyMenuModel>> getSavedWeeklyMenus(String environmentId);

  Future<SavedWeeklyMenuModel?> getSavedWeeklyMenuById(String menuId);

  Future<SavedWeeklyMenuModel> createSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  });

  Future<SavedWeeklyMenuModel> updateSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  });

  Future<void> deleteSavedWeeklyMenu(String menuId);

  // 5. Calendario Semanal Activo
  Future<List<ActiveCalendarSlotModel>> getActiveCalendarSlots({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<ActiveCalendarSlotModel> upsertActiveCalendarSlot(ActiveCalendarSlotModel slot);

  Future<void> deleteActiveCalendarSlot(String slotId);

  Future<void> applySavedMenuToCalendar({
    required String environmentId,
    required String savedMenuId,
    required DateTime mondayStartDate,
  });

  // 6. Lista de la Compra Colaborativa
  Future<List<ShoppingListItemModel>> getShoppingList(String environmentId);

  Future<void> toggleShoppingListItem({
    required String itemId,
    required bool isChecked,
  });

  Future<ShoppingListItemModel> addShoppingListItem(ShoppingListItemModel item);

  Future<void> removeShoppingListItem(String itemId);

  Future<void> clearCheckedShoppingListItems(String environmentId);

  Future<void> syncShoppingListFromActiveCalendar({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  });
}
