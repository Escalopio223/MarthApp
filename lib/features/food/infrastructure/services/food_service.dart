import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/dish_model.dart';
import '../../domain/models/weekly_menu_slot_model.dart';
import '../../domain/models/shopping_item_model.dart';
import '../../domain/repositories/i_food_repository.dart';

class FoodService implements IFoodRepository {
  final SupabaseClient _client;
  List<DishModel>? _cachedCatalog;

  FoodService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Carga el catálogo global de 1.500 recetas desde el bundle local o Supabase
  Future<List<DishModel>> _loadGlobalRecipes() async {
    if (_cachedCatalog != null && _cachedCatalog!.isNotEmpty) {
      return _cachedCatalog!;
    }

    try {
      // Intentar primero desde Supabase si la tabla global_recipes está desplegada
      final response = await _client
          .from('global_recipes')
          .select()
          .limit(1500);

      final list = response as List<dynamic>;
      if (list.isNotEmpty) {
        _cachedCatalog = list
            .map((json) => DishModel.fromJson(json as Map<String, dynamic>).copyWith(isGlobal: true))
            .toList();
        return _cachedCatalog!;
      }
    } catch (_) {
      // Si la tabla no está en Supabase aún, usar el asset precargado de 1.500 recetas
    }

    try {
      final jsonlString = await rootBundle.loadString('assets/data/recipes_catalog.jsonl');
      final lines = const LineSplitter().convert(jsonlString);
      final recipes = <DishModel>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        try {
          final data = json.decode(line) as Map<String, dynamic>;
          recipes.add(DishModel.fromJson(data).copyWith(
            id: 'global-recipe-$i',
            isGlobal: true,
          ));
        } catch (_) {}
      }

      _cachedCatalog = recipes;
      return _cachedCatalog!;
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // PLATOS (DISHES)
  // ==========================================

  @override
  Future<List<DishModel>> getDishes(
    String environmentId, {
    String? query,
    String? cuisine,
    String? servingTemperature,
    String? appliance,
  }) async {
    final results = <DishModel>[];

    // 1. Platos creados por los miembros de este entorno en Supabase
    try {
      var builder = _client
          .from('dishes')
          .select()
          .eq('environment_id', environmentId);

      final response = await builder.order('name', ascending: true);
      final list = response as List<dynamic>;
      results.addAll(list.map((json) => DishModel.fromJson(json as Map<String, dynamic>)));
    } catch (_) {}

    // 2. Catálogo global de 1.500 recetas reales
    final globalRecipes = await _loadGlobalRecipes();
    results.addAll(globalRecipes);

    // 3. Aplicar filtros en memoria
    final filtered = results.where((dish) {
      // Filtro de texto (búsqueda)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchesName = dish.name.toLowerCase().contains(q);
        final matchesCuisine = dish.cuisine?.toLowerCase().contains(q) ?? false;
        final matchesIngredients = dish.ingredients.any((ing) => ing.toLowerCase().contains(q));
        if (!matchesName && !matchesCuisine && !matchesIngredients) {
          return false;
        }
      }

      // Filtro por Cultura / Cocina
      if (cuisine != null && cuisine.isNotEmpty && cuisine != 'Todas') {
        if (dish.cuisine?.toLowerCase() != cuisine.toLowerCase()) {
          return false;
        }
      }

      // Filtro por Temperatura de servicio ("frío" | "caliente")
      if (servingTemperature != null && servingTemperature.isNotEmpty && servingTemperature != 'Todos') {
        if (dish.servingTemperature?.toLowerCase() != servingTemperature.toLowerCase()) {
          return false;
        }
      }

      // Filtro por Electrodoméstico / Método
      if (appliance != null && appliance.isNotEmpty && appliance != 'Todos') {
        if (!dish.supportedAppliances.contains(appliance.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    // 4. Ordenar por relevancia si hay un término de búsqueda:
    // Los platos cuyo TÍTULO contiene la búsqueda van primero; después los que solo lo tienen en ingredientes.
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered.sort((a, b) {
        final aTitleStarts = a.name.toLowerCase().startsWith(q);
        final bTitleStarts = b.name.toLowerCase().startsWith(q);
        if (aTitleStarts && !bTitleStarts) return -1;
        if (!aTitleStarts && bTitleStarts) return 1;

        final aTitleContains = a.name.toLowerCase().contains(q);
        final bTitleContains = b.name.toLowerCase().contains(q);
        if (aTitleContains && !bTitleContains) return -1;
        if (!aTitleContains && bTitleContains) return 1;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    return filtered;
  }

  @override
  Future<DishModel> saveDish(DishModel dish) async {
    final payload = dish.toJson(includeId: dish.id.isNotEmpty && !dish.isGlobal);
    if (dish.id.isEmpty || dish.isGlobal) {
      final res = await _client.from('dishes').insert(payload).select().single();
      return DishModel.fromJson(res);
    } else {
      final res = await _client
          .from('dishes')
          .update(payload)
          .eq('id', dish.id)
          .select()
          .single();
      return DishModel.fromJson(res);
    }
  }

  @override
  Future<void> deleteDish(String dishId) async {
    await _client.from('dishes').delete().eq('id', dishId);
  }

  // ==========================================
  // MENÚ SEMANAL (WEEKLY MENU SLOTS)
  // ==========================================

  @override
  Future<List<WeeklyMenuSlotModel>> getWeeklyMenuSlots({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);

      final response = await _client
          .from('weekly_menu_slots')
          .select('*, dishes(*)')
          .eq('environment_id', environmentId)
          .gte('slot_date', startStr)
          .lte('slot_date', endStr)
          .order('slot_date', ascending: true);

      final list = response as List<dynamic>;
      return list.map((json) => WeeklyMenuSlotModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<WeeklyMenuSlotModel> upsertMenuSlot(WeeklyMenuSlotModel slot) async {
    final payload = slot.toJson(includeId: slot.id.isNotEmpty);
    final response = await _client
        .from('weekly_menu_slots')
        .upsert(
          payload,
          onConflict: 'environment_id,slot_date,meal_type',
        )
        .select('*, dishes(*)')
        .single();

    return WeeklyMenuSlotModel.fromJson(response);
  }

  @override
  Future<void> clearMenuSlot(String slotId) async {
    await _client.from('weekly_menu_slots').delete().eq('id', slotId);
  }

  @override
  Future<void> copySlotToOtherDays({
    required WeeklyMenuSlotModel sourceSlot,
    required List<DateTime> targetDates,
    required MealType mealType,
  }) async {
    for (final targetDate in targetDates) {
      final newSlot = WeeklyMenuSlotModel(
        id: '',
        environmentId: sourceSlot.environmentId,
        slotDate: targetDate,
        mealType: mealType,
        dishId: sourceSlot.dishId,
        customDishName: sourceSlot.customDishName,
        servingsNote: sourceSlot.servingsNote,
        createdBy: sourceSlot.createdBy,
        createdAt: DateTime.now(),
      );
      await upsertMenuSlot(newSlot);
    }
  }

  // ==========================================
  // LISTA DE LA COMPRA (SHOPPING ITEMS)
  // ==========================================

  @override
  Future<List<ShoppingItemModel>> getShoppingItems(String environmentId) async {
    try {
      final response = await _client
          .from('shopping_items')
          .select()
          .eq('environment_id', environmentId)
          .order('is_checked', ascending: true)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((json) => ShoppingItemModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<ShoppingItemModel> addShoppingItem(ShoppingItemModel item) async {
    final payload = item.toJson(includeId: item.id.isNotEmpty);
    final res = await _client.from('shopping_items').insert(payload).select().single();
    return ShoppingItemModel.fromJson(res);
  }

  @override
  Future<void> toggleShoppingItem({required String itemId, required bool isChecked}) async {
    await _client
        .from('shopping_items')
        .update({'is_checked': isChecked})
        .eq('id', itemId);
  }

  @override
  Future<void> deleteShoppingItem(String itemId) async {
    await _client.from('shopping_items').delete().eq('id', itemId);
  }

  @override
  Future<void> clearCompletedShoppingItems(String environmentId) async {
    await _client
        .from('shopping_items')
        .delete()
        .eq('environment_id', environmentId)
        .eq('is_checked', true);
  }

  @override
  Future<int> sendDishIngredientsToShoppingList({
    required String environmentId,
    required String dishName,
    required List<String> ingredients,
    String? dishId,
  }) async {
    if (ingredients.isEmpty) return 0;

    final currentActive = await _client
        .from('shopping_items')
        .select('name')
        .eq('environment_id', environmentId)
        .eq('is_checked', false);

    final activeNames = (currentActive as List<dynamic>)
        .map((e) => (e['name'] as String? ?? '').trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    int addedCount = 0;
    final toInsert = <Map<String, dynamic>>[];

    for (final ing in ingredients) {
      final clean = ing.trim();
      if (clean.isEmpty) continue;
      if (!activeNames.contains(clean.toLowerCase())) {
        toInsert.add({
          'environment_id': environmentId,
          'name': clean,
          'is_checked': false,
          'category_or_source': dishName.trim(),
          'dish_id': (dishId != null && !dishId.startsWith('global-')) ? dishId : null,
        });
        activeNames.add(clean.toLowerCase());
        addedCount++;
      }
    }

    if (toInsert.isNotEmpty) {
      await _client.from('shopping_items').insert(toInsert);
    }

    return addedCount;
  }
}
