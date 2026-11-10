import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
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

  // Claves de SharedPreferences para persistencia local de respaldo
  String _slotsStorageKey(String envId) => 'local_menu_slots_$envId';
  String _shoppingStorageKey(String envId) => 'local_shopping_items_$envId';
  String _dishesStorageKey(String envId) => 'local_dishes_$envId';

  /// Carga el catálogo global de 1.500 recetas desde Supabase o el asset local
  Future<List<DishModel>> _loadGlobalRecipes() async {
    if (_cachedCatalog != null && _cachedCatalog!.isNotEmpty) {
      return _cachedCatalog!;
    }

    try {
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
    } catch (_) {}

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

    // 1. Platos creados por los miembros (Supabase con fallback local)
    bool fetchedFromRemote = false;
    try {
      final response = await _client
          .from('dishes')
          .select()
          .eq('environment_id', environmentId)
          .order('name', ascending: true);
      final list = response as List<dynamic>;
      results.addAll(list.map((json) => DishModel.fromJson(json as Map<String, dynamic>)));
      fetchedFromRemote = true;
    } catch (_) {}

    if (!fetchedFromRemote) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_dishesStorageKey(environmentId));
        if (raw != null) {
          final list = json.decode(raw) as List<dynamic>;
          results.addAll(list.map((j) => DishModel.fromJson(j as Map<String, dynamic>)));
        }
      } catch (_) {}
    }

    // 2. Catálogo global de 1.500 recetas
    final globalRecipes = await _loadGlobalRecipes();
    results.addAll(globalRecipes);

    // 3. Aplicar filtros
    final filtered = results.where((dish) {
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchesName = dish.name.toLowerCase().contains(q);
        final matchesCuisine = dish.cuisine?.toLowerCase().contains(q) ?? false;
        final matchesIngredients = dish.ingredients.any((ing) => ing.toLowerCase().contains(q));
        if (!matchesName && !matchesCuisine && !matchesIngredients) {
          return false;
        }
      }

      if (cuisine != null && cuisine.isNotEmpty && cuisine != 'Todas') {
        if (dish.cuisine?.toLowerCase() != cuisine.toLowerCase()) {
          return false;
        }
      }

      if (servingTemperature != null && servingTemperature.isNotEmpty && servingTemperature != 'Todos') {
        if (dish.servingTemperature?.toLowerCase() != servingTemperature.toLowerCase()) {
          return false;
        }
      }

      if (appliance != null && appliance.isNotEmpty && appliance != 'Todos') {
        if (!dish.supportedAppliances.contains(appliance.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    // 4. Ordenar por relevancia
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
    try {
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
    } catch (_) {
      // Fallback local
      final prefs = await SharedPreferences.getInstance();
      final key = _dishesStorageKey(dish.environmentId);
      final raw = prefs.getString(key);
      final list = raw != null ? (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      
      final toSave = dish.id.isEmpty
          ? dish.copyWith(id: 'local-dish-${DateTime.now().millisecondsSinceEpoch}')
          : dish;
      
      final idx = list.indexWhere((m) => m['id'] == toSave.id);
      if (idx != -1) {
        list[idx] = toSave.toJson();
      } else {
        list.add(toSave.toJson());
      }
      await prefs.setString(key, json.encode(list));
      return toSave;
    }
  }

  @override
  Future<void> deleteDish(String dishId) async {
    try {
      await _client.from('dishes').delete().eq('id', dishId);
    } catch (_) {}
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
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);

    try {
      final response = await _client
          .from('weekly_menu_slots')
          .select('*, dishes(*)')
          .eq('environment_id', environmentId)
          .gte('slot_date', startStr)
          .lte('slot_date', endStr)
          .order('slot_date', ascending: true);

      final list = response as List<dynamic>;
      return list.map((json) => WeeklyMenuSlotModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      // Fallback local de SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_slotsStorageKey(environmentId));
        if (raw == null) return [];

        final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
        return list.map((m) => WeeklyMenuSlotModel.fromJson(m)).where((s) {
          final sDate = _formatDate(s.slotDate);
          return sDate.compareTo(startStr) >= 0 && sDate.compareTo(endStr) <= 0;
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<WeeklyMenuSlotModel> upsertMenuSlot(WeeklyMenuSlotModel slot) async {
    final payload = slot.toJson(includeId: slot.id.isNotEmpty);
    try {
      final response = await _client
          .from('weekly_menu_slots')
          .upsert(
            payload,
            onConflict: 'environment_id,slot_date,meal_type',
          )
          .select('*, dishes(*)')
          .single();

      return WeeklyMenuSlotModel.fromJson(response);
    } catch (_) {
      // Fallback local en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = _slotsStorageKey(slot.environmentId);
      final raw = prefs.getString(key);
      final list = raw != null ? (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];

      final dateStr = _formatDate(slot.slotDate);
      final slotId = slot.id.isNotEmpty ? slot.id : 'local-slot-${DateTime.now().millisecondsSinceEpoch}';
      final toSave = slot.copyWith(id: slotId);

      final idx = list.indexWhere((m) =>
          m['slot_date'] == dateStr && m['meal_type'] == slot.mealType.dbValue);

      if (idx != -1) {
        list[idx] = toSave.toJson();
      } else {
        list.add(toSave.toJson());
      }

      await prefs.setString(key, json.encode(list));
      return toSave;
    }
  }

  @override
  Future<void> clearMenuSlot(String slotId) async {
    try {
      await _client.from('weekly_menu_slots').delete().eq('id', slotId);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      // Limpiar en todas las claves locales posibles
      final keys = prefs.getKeys().where((k) => k.startsWith('local_menu_slots_'));
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw != null) {
          final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
          list.removeWhere((m) => m['id'] == slotId);
          await prefs.setString(k, json.encode(list));
        }
      }
    } catch (_) {}
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
        dish: sourceSlot.dish,
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
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_shoppingStorageKey(environmentId));
        if (raw == null) return [];
        final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
        return list.map((m) => ShoppingItemModel.fromJson(m)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<ShoppingItemModel> addShoppingItem(ShoppingItemModel item) async {
    final payload = item.toJson(includeId: item.id.isNotEmpty);
    try {
      final res = await _client.from('shopping_items').insert(payload).select().single();
      return ShoppingItemModel.fromJson(res);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final key = _shoppingStorageKey(item.environmentId);
      final raw = prefs.getString(key);
      final list = raw != null ? (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];

      final toSave = item.id.isNotEmpty
          ? item
          : item.copyWith(id: 'local-shop-${DateTime.now().millisecondsSinceEpoch}');

      list.insert(0, toSave.toJson());
      await prefs.setString(key, json.encode(list));
      return toSave;
    }
  }

  @override
  Future<void> toggleShoppingItem({required String itemId, required bool isChecked}) async {
    try {
      await _client
          .from('shopping_items')
          .update({'is_checked': isChecked})
          .eq('id', itemId);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('local_shopping_items_'));
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw != null) {
          final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
          final idx = list.indexWhere((m) => m['id'] == itemId);
          if (idx != -1) {
            list[idx]['is_checked'] = isChecked;
            await prefs.setString(k, json.encode(list));
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> deleteShoppingItem(String itemId) async {
    try {
      await _client.from('shopping_items').delete().eq('id', itemId);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('local_shopping_items_'));
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw != null) {
          final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
          list.removeWhere((m) => m['id'] == itemId);
          await prefs.setString(k, json.encode(list));
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> clearCompletedShoppingItems(String environmentId) async {
    try {
      await _client
          .from('shopping_items')
          .delete()
          .eq('environment_id', environmentId)
          .eq('is_checked', true);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _shoppingStorageKey(environmentId);
      final raw = prefs.getString(key);
      if (raw != null) {
        final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
        list.removeWhere((m) => m['is_checked'] == true);
        await prefs.setString(key, json.encode(list));
      }
    } catch (_) {}
  }

  @override
  Future<int> sendDishIngredientsToShoppingList({
    required String environmentId,
    required String dishName,
    required List<String> ingredients,
    String? dishId,
  }) async {
    if (ingredients.isEmpty) return 0;

    int addedCount = 0;
    final currentItems = await getShoppingItems(environmentId);
    final activeNames = currentItems
        .where((i) => !i.isChecked)
        .map((i) => i.name.trim().toLowerCase())
        .toSet();

    for (final ing in ingredients) {
      final clean = ing.trim();
      if (clean.isEmpty) continue;
      if (!activeNames.contains(clean.toLowerCase())) {
        final newItem = ShoppingItemModel(
          id: '',
          environmentId: environmentId,
          name: clean,
          isChecked: false,
          categoryOrSource: dishName.trim(),
          dishId: (dishId != null && !dishId.startsWith('global-')) ? dishId : null,
          createdAt: DateTime.now(),
        );
        await addShoppingItem(newItem);
        activeNames.add(clean.toLowerCase());
        addedCount++;
      }
    }

    return addedCount;
  }
}
