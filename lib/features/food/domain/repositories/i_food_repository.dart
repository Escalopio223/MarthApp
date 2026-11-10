import '../models/dish_model.dart';
import '../models/weekly_menu_slot_model.dart';
import '../models/shopping_item_model.dart';

abstract class IFoodRepository {
  // --- Platos (Dishes) ---
  Future<List<DishModel>> getDishes(String environmentId, {String? query});
  Future<DishModel> saveDish(DishModel dish);
  Future<void> deleteDish(String dishId);

  // --- Menú Semanal (Weekly Slots) ---
  Future<List<WeeklyMenuSlotModel>> getWeeklyMenuSlots({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  });
  Future<WeeklyMenuSlotModel> upsertMenuSlot(WeeklyMenuSlotModel slot);
  Future<void> clearMenuSlot(String slotId);
  Future<void> copySlotToOtherDays({
    required WeeklyMenuSlotModel sourceSlot,
    required List<DateTime> targetDates,
    required MealType mealType,
  });

  // --- Lista de la Compra (Shopping Items) ---
  Future<List<ShoppingItemModel>> getShoppingItems(String environmentId);
  Future<ShoppingItemModel> addShoppingItem(ShoppingItemModel item);
  Future<void> toggleShoppingItem({required String itemId, required bool isChecked});
  Future<void> deleteShoppingItem(String itemId);
  Future<void> clearCompletedShoppingItems(String environmentId);
  Future<int> sendDishIngredientsToShoppingList({
    required String environmentId,
    required String dishName,
    required List<String> ingredients,
    String? dishId,
  });
}
