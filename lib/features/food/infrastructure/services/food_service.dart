import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/active_calendar_slot_model.dart';
import '../../domain/models/food_category_model.dart';
import '../../domain/models/food_favorite_model.dart';
import '../../domain/models/recipe_ingredient_model.dart';
import '../../domain/models/recipe_model.dart';
import '../../domain/models/saved_weekly_menu_model.dart';
import '../../domain/models/saved_weekly_menu_slot_model.dart';
import '../../domain/models/shopping_list_item_model.dart';
import '../../domain/repositories/i_food_repository.dart';

/// Implementación del servicio de alimentación conectado a Supabase PostgreSQL
class FoodService implements IFoodRepository {
  final SupabaseClient? _supabase;

  FoodService({SupabaseClient? client})
      : _supabase = client ?? _safeGetClient();

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
      throw StateError('SupabaseClient no está disponible (no inicializado)');
    }
    return client;
  }

  // ---------------------------------------------------------------------------
  // 1. CATEGORÍAS
  // ---------------------------------------------------------------------------
  @override
  Future<List<FoodCategoryModel>> getCategories() async {
    try {
      final res = await _client
          .from('food_categories')
          .select('*')
          .order('name', ascending: true);

      final list = res as List<dynamic>;
      return list
          .map((item) => FoodCategoryModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Error al obtener categorías: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 2. RECETAS
  // ---------------------------------------------------------------------------
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
    try {
      var builder = _client
          .from('recipes')
          .select('*, recipe_ingredients(*, food_categories(*))');

      // Filtrado por ámbito: globales o pertenecientes al entorno
      if (environmentId != null && environmentId.isNotEmpty) {
        builder = builder.or('is_global.eq.true,environment_id.eq.$environmentId');
      } else {
        builder = builder.eq('is_global', true);
      }

      // Filtro de búsqueda por texto utilizando ILIKE (índice trigram en Postgres)
      if (query != null && query.trim().isNotEmpty) {
        final sanitized = query.trim();
        builder = builder.ilike('title', '%$sanitized%');
      }

      if (cuisineType != null && cuisineType.isNotEmpty) {
        builder = builder.eq('cuisine_type', cuisineType);
      }

      if (country != null && country.isNotEmpty) {
        builder = builder.eq('country', country);
      }

      if (onlyAirfryer == true) {
        builder = builder.not('prep_airfryer', 'is', null);
      }

      if (onlyOven == true) {
        builder = builder.not('prep_oven', 'is', null);
      }

      if (onlyMicrowave == true) {
        builder = builder.not('prep_microwave', 'is', null);
      }

      final res = await builder
          .order('title', ascending: true)
          .range(offset, offset + limit - 1);

      final list = res as List<dynamic>;
      return list
          .map((item) => RecipeModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Error al buscar recetas: $e');
      return [];
    }
  }

  @override
  Future<RecipeModel?> getRecipeById(String recipeId) async {
    try {
      final res = await _client
          .from('recipes')
          .select('*, recipe_ingredients(*, food_categories(*))')
          .eq('id', recipeId)
          .maybeSingle();

      if (res == null) return null;
      return RecipeModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[FoodService] Error al obtener receta por id ($recipeId): $e');
      return null;
    }
  }

  @override
  Future<RecipeModel> createCustomRecipe({
    required RecipeModel recipe,
    required List<RecipeIngredientModel> ingredients,
  }) async {
    try {
      final recipePayload = recipe.toJson(includeId: false);
      recipePayload['is_global'] = false;

      final res = await _client
          .from('recipes')
          .insert(recipePayload)
          .select()
          .single();

      final newRecipeId = res['id'] as String;

      if (ingredients.isNotEmpty) {
        final ingredientsPayload = ingredients.map((ing) {
          final map = ing.toJson(includeId: false);
          map['recipe_id'] = newRecipeId;
          return map;
        }).toList();

        await _client.from('recipe_ingredients').insert(ingredientsPayload);
      }

      return (await getRecipeById(newRecipeId))!;
    } catch (e) {
      debugPrint('[FoodService] Error al crear receta casera: $e');
      rethrow;
    }
  }

  @override
  Future<RecipeModel> updateCustomRecipe({
    required RecipeModel recipe,
    required List<RecipeIngredientModel> ingredients,
  }) async {
    try {
      await _client
          .from('recipes')
          .update({
            'title': recipe.title,
            'country': recipe.country,
            'cuisine_type': recipe.cuisineType,
            'prep_oven': recipe.prepOven,
            'prep_airfryer': recipe.prepAirfryer,
            'prep_microwave': recipe.prepMicrowave,
          })
          .eq('id', recipe.id);

      // Reemplazo atómico de ingredientes
      await _client.from('recipe_ingredients').delete().eq('recipe_id', recipe.id);

      if (ingredients.isNotEmpty) {
        final ingredientsPayload = ingredients.map((ing) {
          final map = ing.toJson(includeId: false);
          map['recipe_id'] = recipe.id;
          return map;
        }).toList();

        await _client.from('recipe_ingredients').insert(ingredientsPayload);
      }

      return (await getRecipeById(recipe.id))!;
    } catch (e) {
      debugPrint('[FoodService] Error al actualizar receta casera: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteCustomRecipe(String recipeId) async {
    try {
      await _client.from('recipes').delete().eq('id', recipeId);
    } catch (e) {
      debugPrint('[FoodService] Error al eliminar receta ($recipeId): $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. FAVORITOS
  // ---------------------------------------------------------------------------
  @override
  Future<List<FoodFavoriteModel>> getFavorites(String environmentId) async {
    try {
      final res = await _client
          .from('food_favorites')
          .select('*, recipes(*, recipe_ingredients(*, food_categories(*)))')
          .eq('environment_id', environmentId)
          .order('created_at', ascending: false);

      final list = res as List<dynamic>;
      return list
          .map((item) => FoodFavoriteModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Error al obtener favoritos: $e');
      return [];
    }
  }

  @override
  Future<FoodFavoriteModel> addFavoriteRecipe({
    required String environmentId,
    required String recipeId,
  }) async {
    try {
      final res = await _client
          .from('food_favorites')
          .insert({
            'environment_id': environmentId,
            'item_type': 'recipe',
            'recipe_id': recipeId,
            'ingredient_name': null,
          })
          .select('*, recipes(*, recipe_ingredients(*, food_categories(*)))')
          .single();

      return FoodFavoriteModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[FoodService] Error al añadir receta a favoritos: $e');
      rethrow;
    }
  }

  @override
  Future<FoodFavoriteModel> addFavoriteIngredient({
    required String environmentId,
    required String ingredientName,
  }) async {
    try {
      final res = await _client
          .from('food_favorites')
          .insert({
            'environment_id': environmentId,
            'item_type': 'ingredient',
            'recipe_id': null,
            'ingredient_name': ingredientName.toLowerCase().trim(),
          })
          .select()
          .single();

      return FoodFavoriteModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[FoodService] Error al añadir ingrediente a favoritos: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFavorite(String favoriteId) async {
    try {
      await _client.from('food_favorites').delete().eq('id', favoriteId);
    } catch (e) {
      debugPrint('[FoodService] Error al eliminar favorito ($favoriteId): $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. BIBLIOTECA DE MENÚS SEMANALES GUARDADOS
  // ---------------------------------------------------------------------------
  @override
  Future<List<SavedWeeklyMenuModel>> getSavedWeeklyMenus(String environmentId) async {
    try {
      final res = await _client
          .from('saved_weekly_menus')
          .select('*, saved_weekly_menu_slots(*, recipes(*))')
          .eq('environment_id', environmentId)
          .order('created_at', ascending: false);

      final list = res as List<dynamic>;
      return list
          .map((item) => SavedWeeklyMenuModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Error al obtener menús guardados: $e');
      return [];
    }
  }

  @override
  Future<SavedWeeklyMenuModel?> getSavedWeeklyMenuById(String menuId) async {
    try {
      final res = await _client
          .from('saved_weekly_menus')
          .select('*, saved_weekly_menu_slots(*, recipes(*, recipe_ingredients(*, food_categories(*))))')
          .eq('id', menuId)
          .maybeSingle();

      if (res == null) return null;
      return SavedWeeklyMenuModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[FoodService] Error al obtener menú guardado ($menuId): $e');
      return null;
    }
  }

  @override
  Future<SavedWeeklyMenuModel> createSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async {
    try {
      final res = await _client
          .from('saved_weekly_menus')
          .insert({
            'environment_id': menu.environmentId,
            'name': menu.name,
            'description': menu.description,
          })
          .select()
          .single();

      final newMenuId = res['id'] as String;

      if (slots.isNotEmpty) {
        final slotsPayload = slots.map((s) {
          final map = s.toJson(includeId: false);
          map['saved_menu_id'] = newMenuId;
          return map;
        }).toList();

        await _client.from('saved_weekly_menu_slots').insert(slotsPayload);
      }

      return (await getSavedWeeklyMenuById(newMenuId))!;
    } catch (e) {
      debugPrint('[FoodService] Error al crear menú guardado: $e');
      rethrow;
    }
  }

  @override
  Future<SavedWeeklyMenuModel> updateSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async {
    try {
      await _client
          .from('saved_weekly_menus')
          .update({
            'name': menu.name,
            'description': menu.description,
          })
          .eq('id', menu.id);

      await _client.from('saved_weekly_menu_slots').delete().eq('saved_menu_id', menu.id);

      if (slots.isNotEmpty) {
        final slotsPayload = slots.map((s) {
          final map = s.toJson(includeId: false);
          map['saved_menu_id'] = menu.id;
          return map;
        }).toList();

        await _client.from('saved_weekly_menu_slots').insert(slotsPayload);
      }

      return (await getSavedWeeklyMenuById(menu.id))!;
    } catch (e) {
      debugPrint('[FoodService] Error al actualizar menú guardado: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteSavedWeeklyMenu(String menuId) async {
    try {
      await _client.from('saved_weekly_menus').delete().eq('id', menuId);
    } catch (e) {
      debugPrint('[FoodService] Error al eliminar menú guardado ($menuId): $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 5. CALENDARIO SEMANAL ACTIVO
  // ---------------------------------------------------------------------------
  @override
  Future<List<ActiveCalendarSlotModel>> getActiveCalendarSlots({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr =
          '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endStr =
          '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

      final res = await _client
          .from('active_calendar_slots')
          .select('*, recipes(*, recipe_ingredients(*, food_categories(*)))')
          .eq('environment_id', environmentId)
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date', ascending: true);

      final list = res as List<dynamic>;
      return list
          .map((item) => ActiveCalendarSlotModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Error al obtener calendario activo: $e');
      return [];
    }
  }

  @override
  Future<ActiveCalendarSlotModel> upsertActiveCalendarSlot(ActiveCalendarSlotModel slot) async {
    try {
      final payload = slot.toJson(includeId: slot.id.isNotEmpty);
      final res = await _client
          .from('active_calendar_slots')
          .upsert(payload)
          .select('*, recipes(*, recipe_ingredients(*, food_categories(*)))')
          .single();

      return ActiveCalendarSlotModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[FoodService] Error al registrar slot de calendario: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteActiveCalendarSlot(String slotId) async {
    try {
      await _client.from('active_calendar_slots').delete().eq('id', slotId);
    } catch (e) {
      debugPrint('[FoodService] Error al eliminar slot de calendario ($slotId): $e');
      rethrow;
    }
  }

  @override
  Future<void> applySavedMenuToCalendar({
    required String environmentId,
    required String savedMenuId,
    required DateTime mondayStartDate,
  }) async {
    try {
      final menu = await getSavedWeeklyMenuById(savedMenuId);
      if (menu == null || menu.slots.isEmpty) return;

      // Limpiar días de esa semana (lunes a domingo: 7 días)
      final sundayEndDate = mondayStartDate.add(const Duration(days: 6));
      final startStr =
          '${mondayStartDate.year.toString().padLeft(4, '0')}-${mondayStartDate.month.toString().padLeft(2, '0')}-${mondayStartDate.day.toString().padLeft(2, '0')}';
      final endStr =
          '${sundayEndDate.year.toString().padLeft(4, '0')}-${sundayEndDate.month.toString().padLeft(2, '0')}-${sundayEndDate.day.toString().padLeft(2, '0')}';

      await _client
          .from('active_calendar_slots')
          .delete()
          .eq('environment_id', environmentId)
          .gte('date', startStr)
          .lte('date', endStr);

      final newSlotsPayload = menu.slots.map((slot) {
        final targetDate = mondayStartDate.add(Duration(days: slot.dayOfWeek - 1));
        final targetDateStr =
            '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

        return {
          'environment_id': environmentId,
          'date': targetDateStr,
          'meal_type': slot.mealType.dbValue,
          'item_type': slot.itemType.dbValue,
          'recipe_id': slot.recipeId,
          'custom_name': slot.customName,
        };
      }).toList();

      await _client.from('active_calendar_slots').insert(newSlotsPayload);
    } catch (e) {
      debugPrint('[FoodService] Error al aplicar menú guardado al calendario: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 6. LISTA DE LA COMPRA
  // ---------------------------------------------------------------------------
  @override
  Future<List<ShoppingListItemModel>> getShoppingList(String environmentId) async {
    try {
      final res = await _client
          .from('shopping_list_items')
          .select('*, food_categories(*)')
          .eq('environment_id', environmentId)
          .order('is_checked', ascending: true)
          .order('name', ascending: true);

      final list = res as List<dynamic>;
      return list
          .map((item) => ShoppingListItemModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[FoodService] Error al obtener lista de la compra: $e');
      return [];
    }
  }

  @override
  Future<void> toggleShoppingListItem({
    required String itemId,
    required bool isChecked,
  }) async {
    try {
      await _client
          .from('shopping_list_items')
          .update({'is_checked': isChecked, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', itemId);
    } catch (e) {
      debugPrint('[FoodService] Error al alternar check de compra ($itemId): $e');
      rethrow;
    }
  }

  @override
  Future<ShoppingListItemModel> addShoppingListItem(ShoppingListItemModel item) async {
    try {
      final payload = item.toJson(includeId: false);
      final res = await _client
          .from('shopping_list_items')
          .insert(payload)
          .select('*, food_categories(*)')
          .single();

      return ShoppingListItemModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('[FoodService] Error al añadir ítem a la lista de la compra: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeShoppingListItem(String itemId) async {
    try {
      await _client.from('shopping_list_items').delete().eq('id', itemId);
    } catch (e) {
      debugPrint('[FoodService] Error al eliminar ítem de compra ($itemId): $e');
      rethrow;
    }
  }

  @override
  Future<void> clearCheckedShoppingListItems(String environmentId) async {
    try {
      await _client
          .from('shopping_list_items')
          .delete()
          .eq('environment_id', environmentId)
          .eq('is_checked', true);
    } catch (e) {
      debugPrint('[FoodService] Error al limpiar ítems comprados: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncShoppingListFromActiveCalendar({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // 1. Obtener slots del calendario con sus recetas e ingredientes
      final slots = await getActiveCalendarSlots(
        environmentId: environmentId,
        startDate: startDate,
        endDate: endDate,
      );

      // 2. Extraer y contabilizar ocurrencias de ingredientes
      final Map<String, int> counts = {};
      final Map<String, String?> categoryMapping = {};

      for (final slot in slots) {
        if (slot.itemType == SlotItemType.recipe && slot.recipe != null) {
          for (final ing in slot.recipe!.ingredients) {
            final key = ing.name.toLowerCase().trim();
            if (key.isEmpty) continue;
            counts[key] = (counts[key] ?? 0) + 1;
            categoryMapping[key] = ing.categoryId;
          }
        } else if (slot.itemType == SlotItemType.singleIngredient && slot.customName != null) {
          final key = slot.customName!.toLowerCase().trim();
          if (key.isEmpty) continue;
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }

      // 3. Obtener lista actual para no sobrescribir ítems manuales o ya chequeados
      final existingItems = await getShoppingList(environmentId);
      final existingMap = {
        for (var item in existingItems) item.name.toLowerCase().trim(): item
      };

      for (final entry in counts.entries) {
        final name = entry.key;
        final occurrences = entry.value;
        final catId = categoryMapping[name];

        if (existingMap.containsKey(name)) {
          final current = existingMap[name]!;
          // Solo actualizar si no fue marcado como comprado
          if (!current.isChecked) {
            await _client
                .from('shopping_list_items')
                .update({
                  'occurrences_count': occurrences,
                  if (catId != null && current.categoryId == null) 'category_id': catId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', current.id);
          }
        } else {
          await _client.from('shopping_list_items').insert({
            'environment_id': environmentId,
            'name': name,
            'occurrences_count': occurrences,
            'category_id': catId,
            'is_checked': false,
            'is_manual': false,
          });
        }
      }
    } catch (e) {
      debugPrint('[FoodService] Error al sincronizar lista de la compra con calendario: $e');
      rethrow;
    }
  }
}
