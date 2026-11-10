import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/food/domain/models/dish_model.dart';
import 'package:marth_app/features/food/domain/models/shopping_item_model.dart';
import 'package:marth_app/features/food/domain/models/weekly_menu_slot_model.dart';
import 'package:marth_app/features/food/domain/repositories/i_food_repository.dart';
import 'package:marth_app/features/food/presentation/controllers/food_controller.dart';
import 'package:marth_app/features/food/presentation/screens/food_screen.dart';

class MockFoodRepository implements IFoodRepository {
  final List<DishModel> dishes = [];
  final List<WeeklyMenuSlotModel> menuSlots = [];
  final List<ShoppingItemModel> shoppingItems = [];

  @override
  Future<List<DishModel>> getDishes(String environmentId, {String? query}) async {
    if (query == null || query.trim().isEmpty) return dishes;
    return dishes.where((d) => d.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  Future<DishModel> saveDish(DishModel dish) async {
    final toSave = dish.id.isEmpty
        ? dish.copyWith(id: 'dish-${dishes.length + 1}')
        : dish;
    final idx = dishes.indexWhere((d) => d.id == toSave.id);
    if (idx != -1) {
      dishes[idx] = toSave;
    } else {
      dishes.add(toSave);
    }
    return toSave;
  }

  @override
  Future<void> deleteDish(String dishId) async {
    dishes.removeWhere((d) => d.id == dishId);
  }

  @override
  Future<List<WeeklyMenuSlotModel>> getWeeklyMenuSlots({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return menuSlots;
  }

  @override
  Future<WeeklyMenuSlotModel> upsertMenuSlot(WeeklyMenuSlotModel slot) async {
    final toSave = slot.id.isEmpty
        ? slot.copyWith(id: 'slot-${menuSlots.length + 1}')
        : slot;
    final idx = menuSlots.indexWhere((s) => s.id == toSave.id);
    if (idx != -1) {
      menuSlots[idx] = toSave;
    } else {
      menuSlots.add(toSave);
    }
    return toSave;
  }

  @override
  Future<void> clearMenuSlot(String slotId) async {
    menuSlots.removeWhere((s) => s.id == slotId);
  }

  @override
  Future<void> copySlotToOtherDays({
    required WeeklyMenuSlotModel sourceSlot,
    required List<DateTime> targetDates,
    required MealType mealType,
  }) async {
    for (final d in targetDates) {
      menuSlots.add(sourceSlot.copyWith(
        id: 'slot-copy-${menuSlots.length + 1}',
        slotDate: d,
        mealType: mealType,
      ));
    }
  }

  @override
  Future<List<ShoppingItemModel>> getShoppingItems(String environmentId) async {
    return shoppingItems;
  }

  @override
  Future<ShoppingItemModel> addShoppingItem(ShoppingItemModel item) async {
    final toSave = item.id.isEmpty
        ? item.copyWith(id: 'item-${shoppingItems.length + 1}')
        : item;
    shoppingItems.insert(0, toSave);
    return toSave;
  }

  @override
  Future<void> toggleShoppingItem({required String itemId, required bool isChecked}) async {
    final idx = shoppingItems.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      shoppingItems[idx] = shoppingItems[idx].copyWith(isChecked: isChecked);
    }
  }

  @override
  Future<void> deleteShoppingItem(String itemId) async {
    shoppingItems.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<void> clearCompletedShoppingItems(String environmentId) async {
    shoppingItems.removeWhere((i) => i.isChecked);
  }

  @override
  Future<int> sendDishIngredientsToShoppingList({
    required String environmentId,
    required String dishName,
    required List<String> ingredients,
    String? dishId,
  }) async {
    int added = 0;
    for (final ing in ingredients) {
      if (!shoppingItems.any((i) => !i.isChecked && i.name.toLowerCase() == ing.toLowerCase())) {
        shoppingItems.insert(0, ShoppingItemModel(
          id: 'item-${shoppingItems.length + 1}',
          environmentId: environmentId,
          name: ing,
          categoryOrSource: dishName,
          dishId: dishId,
          isChecked: false,
          createdAt: DateTime.now(),
        ));
        added++;
      }
    }
    return added;
  }
}

void main() {
  late MockFoodRepository mockRepo;
  late FoodController controller;

  setUp(() {
    mockRepo = MockFoodRepository();
    controller = FoodController(repository: mockRepo);
  });

  group('Food Module Clean Architecture Tests', () {
    test('Crear plato guarda nombre, raciones e ingredientes en el catálogo', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      final dish = await controller.saveDish(
        name: 'Lentejas estofadas',
        defaultServings: 4,
        ingredients: ['Lentejas', 'Zanahoria', 'Chorizo'],
      );

      expect(dish.name, 'Lentejas estofadas');
      expect(dish.defaultServings, 4);
      expect(dish.ingredients.length, 3);
      expect(controller.dishes.length, 1);
    });

    test('Asignar plato al menú semanal y enviar ingredientes a la compra', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      final dish = await controller.saveDish(
        name: 'Pollo al curry',
        defaultServings: 2,
        ingredients: ['Pechuga de pollo', 'Curry en polvo', 'Leche de coco'],
      );

      final date = controller.weekStartDate;
      await controller.assignDishToSlot(
        date: date,
        mealType: MealType.lunch,
        dish: dish,
        servingsNote: '2 rac.',
        syncIngredientsToShopping: true,
      );

      final slot = controller.getSlot(date, MealType.lunch);
      expect(slot, isNotNull);
      expect(slot!.displayName, 'Pollo al curry');
      expect(slot.servingsNote, '2 rac.');

      // Comprobar que los ingredientes se añadieron a la lista de la compra
      expect(controller.shoppingItems.length, 3);
      expect(controller.shoppingItems.first.categoryOrSource, 'Pollo al curry');
    });

    test('Añadir producto rápido a la compra, tacharlo y limpiar completados', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      await controller.addQuickShoppingItem('Papel de cocina');
      expect(controller.pendingShoppingItems.length, 1);

      final item = controller.shoppingItems.first;
      await controller.toggleShoppingItem(item.id, true);
      expect(controller.pendingShoppingItems.length, 0);
      expect(controller.completedShoppingItems.length, 1);

      await controller.clearCompletedShoppingItems();
      expect(controller.shoppingItems.length, 0);
    });

    testWidgets('FoodScreen renderiza pestañas y navega limpiamente', (tester) async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodScreen(controller: controller),
          ),
        ),
      );

      expect(find.text('📅 Menú'), findsOneWidget);
      expect(find.text('🛒 Compra'), findsOneWidget);
      expect(find.text('🍽️ Mis Platos'), findsOneWidget);

      // Cambiar a la pestaña de compra
      await tester.tap(find.text('🛒 Compra'));
      await tester.pumpAndSettle();

      expect(find.text('+ Añadir producto a la compra...'), findsOneWidget);

      // Cambiar a la pestaña de Mis Platos
      await tester.tap(find.text('🍽️ Mis Platos'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar en mis platos...'), findsOneWidget);
    });
  });
}
