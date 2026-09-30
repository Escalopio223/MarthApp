import 'package:flutter/material.dart';
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
import 'package:marth_app/features/food/presentation/controllers/weekly_menu_planner_controller.dart';
import 'package:marth_app/features/food/presentation/screens/weekly_menu_planner_screen.dart';
import 'package:marth_app/features/food/presentation/widgets/load_menu_preset_modal.dart';
import 'package:marth_app/features/food/presentation/widgets/saved_menu_editor_modal.dart';

class MockWeeklyPlannerRepository implements IFoodRepository {
  List<ActiveCalendarSlotModel> activeSlotsStorage = [];
  List<SavedWeeklyMenuModel> savedMenusStorage = [];
  List<FoodFavoriteModel> favoritesStorage = [];
  List<RecipeModel> recipesStorage = [
    RecipeModel(
      id: 'rec-1',
      title: 'Tortilla española con cebolla',
      country: 'España',
      cuisineType: 'Tradicional',
      createdAt: DateTime.now(),
    ),
    RecipeModel(
      id: 'rec-2',
      title: 'Salmón con verduras en airfryer',
      country: 'Noruega',
      cuisineType: 'Airfryer',
      prepAirfryer: '180°C durante 12 min',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<ActiveCalendarSlotModel>> getActiveCalendarSlots({
    required String environmentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endStr =
        '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    return activeSlotsStorage.where((s) {
      return s.environmentId == environmentId &&
          s.dateString.compareTo(startStr) >= 0 &&
          s.dateString.compareTo(endStr) <= 0;
    }).toList();
  }

  @override
  Future<ActiveCalendarSlotModel> upsertActiveCalendarSlot(ActiveCalendarSlotModel slot) async {
    final existingIdx = activeSlotsStorage.indexWhere(
      (s) =>
          s.environmentId == slot.environmentId &&
          s.dateString == slot.dateString &&
          s.mealType == slot.mealType,
    );

    final saved = slot.copyWith(
      id: slot.id.isNotEmpty ? slot.id : 'slot-${DateTime.now().millisecondsSinceEpoch}',
    );

    if (existingIdx != -1) {
      activeSlotsStorage[existingIdx] = saved;
    } else {
      activeSlotsStorage.add(saved);
    }
    return saved;
  }

  @override
  Future<void> deleteActiveCalendarSlot(String slotId) async {
    activeSlotsStorage.removeWhere((s) => s.id == slotId);
  }

  @override
  Future<List<SavedWeeklyMenuModel>> getSavedWeeklyMenus(String environmentId) async {
    return savedMenusStorage.where((m) => m.environmentId == environmentId).toList();
  }

  @override
  Future<SavedWeeklyMenuModel?> getSavedWeeklyMenuById(String menuId) async {
    final matches = savedMenusStorage.where((m) => m.id == menuId);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<SavedWeeklyMenuModel> createSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async {
    final created = menu.copyWith(
      id: 'menu-${DateTime.now().millisecondsSinceEpoch}',
      slots: slots,
    );
    savedMenusStorage.insert(0, created);
    return created;
  }

  @override
  Future<SavedWeeklyMenuModel> updateSavedWeeklyMenu({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async {
    final updated = menu.copyWith(slots: slots);
    final idx = savedMenusStorage.indexWhere((m) => m.id == menu.id);
    if (idx != -1) {
      savedMenusStorage[idx] = updated;
    }
    return updated;
  }

  @override
  Future<SavedWeeklyMenuModel> renameSavedWeeklyMenu({
    required String menuId,
    required String newName,
    String? newDescription,
  }) async {
    final idx = savedMenusStorage.indexWhere((m) => m.id == menuId);
    if (idx == -1) throw Exception('Menu not found');
    final updated = savedMenusStorage[idx].copyWith(
      name: newName,
      description: newDescription,
    );
    savedMenusStorage[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteSavedWeeklyMenu(String menuId) async {
    savedMenusStorage.removeWhere((m) => m.id == menuId);
  }

  @override
  Future<void> applySavedMenuToCalendar({
    required String environmentId,
    required String savedMenuId,
    required DateTime mondayStartDate,
    bool overwrite = true,
  }) async {
    final menu = await getSavedWeeklyMenuById(savedMenuId);
    if (menu == null) return;

    final sundayEndDate = mondayStartDate.add(const Duration(days: 6));
    final startStr =
        '${mondayStartDate.year.toString().padLeft(4, '0')}-${mondayStartDate.month.toString().padLeft(2, '0')}-${mondayStartDate.day.toString().padLeft(2, '0')}';
    final endStr =
        '${sundayEndDate.year.toString().padLeft(4, '0')}-${sundayEndDate.month.toString().padLeft(2, '0')}-${sundayEndDate.day.toString().padLeft(2, '0')}';

    if (overwrite) {
      activeSlotsStorage.removeWhere((s) =>
          s.environmentId == environmentId &&
          s.dateString.compareTo(startStr) >= 0 &&
          s.dateString.compareTo(endStr) <= 0);
    }

    final occupiedKeys = {
      for (final s in activeSlotsStorage) '${s.dateString}_${s.mealType.dbValue}'
    };

    for (final s in menu.slots) {
      final targetDate = mondayStartDate.add(Duration(days: s.dayOfWeek - 1));
      final dateStr =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      final key = '${dateStr}_${s.mealType.dbValue}';

      if (!overwrite && occupiedKeys.contains(key)) {
        continue;
      }

      activeSlotsStorage.add(ActiveCalendarSlotModel(
        id: 'slot-applied-${DateTime.now().microsecondsSinceEpoch}',
        environmentId: environmentId,
        date: targetDate,
        mealType: s.mealType,
        itemType: s.itemType,
        recipeId: s.recipeId,
        customName: s.customName,
        recipe: s.recipe,
      ));
    }
  }

  @override
  Future<SavedWeeklyMenuModel> saveActiveWeekAsMenu({
    required String environmentId,
    required String name,
    String? description,
    required DateTime mondayStartDate,
  }) async {
    final sundayEndDate = mondayStartDate.add(const Duration(days: 6));
    final slots = await getActiveCalendarSlots(
      environmentId: environmentId,
      startDate: mondayStartDate,
      endDate: sundayEndDate,
    );

    final cleanMonday = DateTime(mondayStartDate.year, mondayStartDate.month, mondayStartDate.day);

    final convertedSlots = slots.map((s) {
      final cleanDate = DateTime(s.date.year, s.date.month, s.date.day);
      final diff = cleanDate.difference(cleanMonday).inDays;
      final dayOfWeek = ((diff % 7) + 1).clamp(1, 7);

      return SavedWeeklyMenuSlotModel(
        id: '',
        savedMenuId: '',
        dayOfWeek: dayOfWeek,
        mealType: s.mealType,
        itemType: s.itemType,
        recipeId: s.recipeId,
        customName: s.customName,
        recipe: s.recipe,
      );
    }).toList();

    return createSavedWeeklyMenu(
      menu: SavedWeeklyMenuModel(
        id: '',
        environmentId: environmentId,
        name: name,
        description: description,
        createdAt: DateTime.now(),
      ),
      slots: convertedSlots,
    );
  }

  @override
  dynamic subscribeToActiveCalendar(String environmentId, void Function() onCalendarChanged) => 'mock-channel';

  @override
  Future<void> unsubscribe(dynamic channel) async {}

  @override
  Future<List<FoodCategoryModel>> getCategories() async => [];
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
  }) async => recipesStorage;
  @override
  Future<RecipeModel?> getRecipeById(String recipeId) async =>
      recipesStorage.firstWhere((r) => r.id == recipeId);
  @override
  Future<RecipeModel> createCustomRecipe({required RecipeModel recipe, required List<RecipeIngredientModel> ingredients}) async => recipe;
  @override
  Future<RecipeModel> updateCustomRecipe({required RecipeModel recipe, required List<RecipeIngredientModel> ingredients}) async => recipe;
  @override
  Future<void> deleteCustomRecipe(String recipeId) async {}
  @override
  Future<List<FoodFavoriteModel>> getFavorites(String environmentId) async => favoritesStorage;
  @override
  Future<FoodFavoriteModel> addFavoriteRecipe({required String environmentId, required String recipeId}) async {
    final fav = FoodFavoriteModel(
      id: 'fav-${DateTime.now().millisecondsSinceEpoch}',
      environmentId: environmentId,
      itemType: FoodFavoriteType.recipe,
      recipeId: recipeId,
      createdAt: DateTime.now(),
    );
    favoritesStorage.add(fav);
    return fav;
  }
  @override
  Future<FoodFavoriteModel> addFavoriteIngredient({required String environmentId, required String ingredientName}) async {
    final fav = FoodFavoriteModel(
      id: 'fav-${DateTime.now().millisecondsSinceEpoch}',
      environmentId: environmentId,
      itemType: FoodFavoriteType.ingredient,
      ingredientName: ingredientName,
      createdAt: DateTime.now(),
    );
    favoritesStorage.add(fav);
    return fav;
  }
  @override
  Future<void> removeFavorite(String favoriteId) async => favoritesStorage.removeWhere((f) => f.id == favoriteId);
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
  Future<void> syncShoppingListFromActiveCalendar({required String environmentId, required DateTime startDate, required DateTime endDate}) async {}
}

void main() {
  late MockWeeklyPlannerRepository mockRepo;
  late WeeklyMenuPlannerController controller;

  // Fecha fija de prueba: Miércoles 30 de Septiembre de 2026
  final testWednesday = DateTime(2026, 9, 30);
  final expectedMonday = DateTime(2026, 9, 28);

  setUp(() {
    mockRepo = MockWeeklyPlannerRepository();
    controller = WeeklyMenuPlannerController(
      repository: mockRepo,
      initialDate: testWednesday,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('WeeklyMenuPlannerController - Lógica y Fechas', () {
    test('Calcula el Lunes correctamente para cualquier día de la semana', () {
      expect(controller.currentMonday, equals(expectedMonday));
      expect(controller.currentSunday, equals(DateTime(2026, 10, 4)));

      // Domingo 4 de Octubre debe mapear al Lunes 28 de Septiembre
      final sunday = DateTime(2026, 10, 4);
      expect(WeeklyMenuPlannerController.getMonday(sunday), equals(expectedMonday));

      // Lunes 28 de Septiembre debe mapear a sí mismo
      expect(WeeklyMenuPlannerController.getMonday(expectedMonday), equals(expectedMonday));
    });

    test('Navegación semanal (semana anterior, siguiente e ir a hoy)', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      controller.nextWeek();
      expect(controller.currentMonday, equals(DateTime(2026, 10, 5)));

      controller.previousWeek();
      expect(controller.currentMonday, equals(DateTime(2026, 9, 28)));

      controller.goToToday();
      final todayMonday = WeeklyMenuPlannerController.getMonday(DateTime.now());
      expect(controller.currentMonday, equals(todayMonday));
    });

    test('Asignación de receta y alimento suelto a ranuras (slots)', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      final mondayDate = controller.currentMonday;
      final recipe = mockRepo.recipesStorage.first;

      // 1. Asignar receta a comida del Lunes
      await controller.setSlotRecipe(mondayDate, MealType.lunch, recipe);

      final slotLunch = controller.getSlot(mondayDate, MealType.lunch);
      expect(slotLunch, isNotNull);
      expect(slotLunch!.itemType, equals(SlotItemType.recipe));
      expect(slotLunch.recipeId, equals(recipe.id));
      expect(slotLunch.displayTitle, equals(recipe.title));

      // 2. Asignar alimento suelto a merienda del Lunes
      await controller.setSlotSingleIngredient(mondayDate, MealType.snack, 'Bocadillo de jamón con tomate');

      final slotSnack = controller.getSlot(mondayDate, MealType.snack);
      expect(slotSnack, isNotNull);
      expect(slotSnack!.itemType, equals(SlotItemType.singleIngredient));
      expect(slotSnack.customName, equals('Bocadillo de jamón con tomate'));

      // 3. Vaciar slot (clearSlot)
      await controller.clearSlot(mondayDate, MealType.lunch);
      expect(controller.getSlot(mondayDate, MealType.lunch), isNull);
    });
  });

  group('Biblioteca de Menús Guardados (Presets) y Volcado al Calendario', () {
    test('Creación, renombrado, actualización y eliminación de menús guardados', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      // 1. Crear Preset
      final created = await controller.createPreset(
        name: 'Semana rápida de examen',
        description: 'Recetas express para ahorrar tiempo',
        slots: [
          SavedWeeklyMenuSlotModel(
            id: 's-1',
            savedMenuId: '',
            dayOfWeek: 1, // Lunes
            mealType: MealType.lunch,
            itemType: SlotItemType.singleIngredient,
            customName: 'Arroz con huevo a la plancha',
          ),
          SavedWeeklyMenuSlotModel(
            id: 's-2',
            savedMenuId: '',
            dayOfWeek: 2, // Martes
            mealType: MealType.dinner,
            itemType: SlotItemType.recipe,
            recipeId: 'rec-2',
            recipe: mockRepo.recipesStorage[1],
          ),
        ],
      );

      expect(controller.savedMenus.length, 1);
      expect(controller.savedMenus.first.name, equals('Semana rápida de examen'));
      expect(controller.savedMenus.first.slots.length, 2);

      // 2. Renombrar Preset
      await controller.renamePreset(created.id, 'Semana Express Exámenes', 'Nueva descripción');
      expect(controller.savedMenus.first.name, equals('Semana Express Exámenes'));

      // 3. Eliminar Preset
      await controller.deletePreset(created.id);
      expect(controller.savedMenus.isEmpty, isTrue);
    });

    test('Volcado de menú guardado al calendario activo (sobrescribir vs respetar huecos)', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');
      final monday = controller.currentMonday;

      // Crear preset de prueba
      final preset = await controller.createPreset(
        name: 'Menú Saludable',
        slots: [
          SavedWeeklyMenuSlotModel(
            id: 'p-1',
            savedMenuId: '',
            dayOfWeek: 1, // Lunes
            mealType: MealType.breakfast,
            itemType: SlotItemType.singleIngredient,
            customName: 'Avena con fruta',
          ),
          SavedWeeklyMenuSlotModel(
            id: 'p-2',
            savedMenuId: '',
            dayOfWeek: 1, // Lunes
            mealType: MealType.lunch,
            itemType: SlotItemType.recipe,
            recipeId: 'rec-1',
            recipe: mockRepo.recipesStorage.first,
          ),
        ],
      );

      // Aplicar al calendario actual
      await controller.applyPresetToCurrentWeek(preset.id, overwrite: true);

      // Verificar que los slots están ahora en el calendario activo
      final activeBreakfast = controller.getSlot(monday, MealType.breakfast);
      final activeLunch = controller.getSlot(monday, MealType.lunch);

      expect(activeBreakfast, isNotNull);
      expect(activeBreakfast!.customName, equals('Avena con fruta'));
      expect(activeLunch, isNotNull);
      expect(activeLunch!.recipeId, equals('rec-1'));

      // Modificar un slot en el calendario activo NO altera el preset original de la biblioteca
      await controller.setSlotSingleIngredient(monday, MealType.breakfast, 'Café solo');
      expect(controller.getSlot(monday, MealType.breakfast)!.customName, equals('Café solo'));

      final originalPreset = await mockRepo.getSavedWeeklyMenuById(preset.id);
      expect(originalPreset!.slots.first.customName, equals('Avena con fruta'));
    });

    test('Guardar semana activa como nuevo menú en la biblioteca con un solo botón', () async {
      await controller.initialize(environmentId: 'env-1', userId: 'user-1');
      final monday = controller.currentMonday;

      // Planificamos 2 comidas en el calendario activo
      await controller.setSlotRecipe(monday, MealType.lunch, mockRepo.recipesStorage.first);
      await controller.setSlotSingleIngredient(
        monday.add(const Duration(days: 4)), // Viernes
        MealType.dinner,
        'Pizza casera',
      );

      // Guardar semana como menú
      final savedWeekMenu = await controller.saveCurrentWeekAsPreset(
        name: 'Semana Favorita Familiar',
        description: 'Viernes de pizza y comidas tradicionales',
      );

      expect(savedWeekMenu.name, equals('Semana Favorita Familiar'));
      expect(savedWeekMenu.slots.length, 2);
      expect(controller.savedMenus.any((m) => m.name == 'Semana Favorita Familiar'), isTrue);
    });
  });

  group('WeeklyMenuPlanner Widgets Testing', () {
    testWidgets('WeeklyMenuPlannerScreen renderiza cabecera, días y slots de comidas', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      await tester.pumpWidget(
        MaterialApp(
          home: WeeklyMenuPlannerScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que se renderiza el título y los selectores
      expect(find.text('Planificador Semanal'), findsOneWidget);
      expect(find.text('Calendario Semanal'), findsOneWidget);
      expect(find.text('Biblioteca de Menús'), findsOneWidget);
      expect(find.text('Cargar Menú'), findsOneWidget);
      expect(find.text('Guardar Menú'), findsOneWidget);

      // Verificar que se muestran los días Lun..Dom
      expect(find.text('Lun'), findsOneWidget);
      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('Mié'), findsOneWidget);

      // Verificar que se muestran los 5 tipos de comida
      expect(find.text('Desayuno'), findsWidgets);
      expect(find.text('Media Mañana'), findsWidgets);
      expect(find.text('Comida'), findsWidgets);
      expect(find.text('Merienda'), findsWidgets);
      expect(find.text('Cena'), findsWidgets);
    });

    testWidgets('Alternar a pestaña Biblioteca de Menús muestra lista de plantillas y botón crear', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      await tester.pumpWidget(
        MaterialApp(
          home: WeeklyMenuPlannerScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Tocar en pestaña "Biblioteca de Menús"
      await tester.tap(find.text('Biblioteca de Menús'));
      await tester.pumpAndSettle();

      expect(find.text('Plantillas Semanales'), findsOneWidget);
      expect(find.text('Crear Menú'), findsOneWidget);
      expect(find.text('Guardar Semana'), findsOneWidget);
    });

    testWidgets('LoadMenuPresetModal muestra modos de aplicación y lista de plantillas', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Añadimos un preset previo en el mock
      mockRepo.savedMenusStorage.add(
        SavedWeeklyMenuModel(
          id: 'preset-1',
          environmentId: 'env-1',
          name: 'Menú Saludable',
          description: 'Rico en fibra',
          createdAt: DateTime.now(),
          slots: const [],
        ),
      );

      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => LoadMenuPresetModal.show(ctx, controller: controller),
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir modal
      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Cargar Menú Guardado'), findsOneWidget);
      expect(find.text('Sobrescribir todo'), findsOneWidget);
      expect(find.text('Solo huecos vacíos'), findsOneWidget);
      expect(find.text('Menú Saludable'), findsOneWidget);
      expect(find.text('Cargar en semana'), findsOneWidget);
    });

    testWidgets('SavedMenuEditorModal permite configurar slots para los 7 días', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await controller.initialize(environmentId: 'env-1', userId: 'user-1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => SavedMenuEditorModal.show(ctx, controller: controller),
                child: const Text('Abrir Editor'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir editor
      await tester.tap(find.text('Abrir Editor'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Menú Guardado'), findsOneWidget);
      expect(find.text('Nombre del Menú *'), findsOneWidget);
      expect(find.text('Lunes • 5 Comidas'), findsOneWidget);
      expect(find.text('Guardar Plantilla'), findsOneWidget);
    });
  });
}
