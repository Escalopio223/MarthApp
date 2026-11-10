import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/dish_model.dart';
import '../../domain/models/weekly_menu_slot_model.dart';
import '../../domain/models/shopping_item_model.dart';
import '../../domain/repositories/i_food_repository.dart';

class FoodService implements IFoodRepository {
  final SupabaseClient _client;

  FoodService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // PLATOS (DISHES)
  // ==========================================

  @override
  Future<List<DishModel>> getDishes(String environmentId, {String? query}) async {
    try {
      var builder = _client
          .from('dishes')
          .select()
          .eq('environment_id', environmentId);

      if (query != null && query.trim().isNotEmpty) {
        builder = builder.ilike('name', '%${query.trim()}%');
      }

      final response = await builder.order('name', ascending: true);
      final list = response as List<dynamic>;
      return list.map((json) => DishModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<DishModel> saveDish(DishModel dish) async {
    final payload = dish.toJson(includeId: dish.id.isNotEmpty);
    if (dish.id.isEmpty) {
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

    // Obtener ítems activos actuales para no duplicar si ya están sin tachar
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
          'dish_id': dishId,
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

