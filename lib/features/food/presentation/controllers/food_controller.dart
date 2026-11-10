import 'package:flutter/foundation.dart';
import '../../domain/models/dish_model.dart';
import '../../domain/models/weekly_menu_slot_model.dart';
import '../../domain/models/shopping_item_model.dart';
import '../../domain/repositories/i_food_repository.dart';

class FoodController extends ChangeNotifier {
  final IFoodRepository _repository;

  FoodController({required IFoodRepository repository})
      // ignore: prefer_initializing_formals
      : _repository = repository;

  String? _environmentId;
  String? _userId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --- Filtros Activos de Búsqueda y Catálogo ---
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _selectedCuisine = 'Todas';
  String get selectedCuisine => _selectedCuisine;

  String _selectedTemperature = 'Todos'; // 'Todos', 'frío', 'caliente'
  String get selectedTemperature => _selectedTemperature;

  String _selectedAppliance = 'Todos'; // 'Todos', 'airfryer', 'oven', 'microwave', 'stovetop'
  String get selectedAppliance => _selectedAppliance;

  // --- Fecha Semanal ---
  DateTime _weekStartDate = _getMondayOfWeek(DateTime.now());
  DateTime get weekStartDate => _weekStartDate;
  DateTime get weekEndDate => _weekStartDate.add(const Duration(days: 6));

  // --- Estado: Platos ---
  List<DishModel> _dishes = [];
  List<DishModel> get dishes => _dishes;

  // --- Estado: Menú Semanal ---
  List<WeeklyMenuSlotModel> _menuSlots = [];
  List<WeeklyMenuSlotModel> get menuSlots => _menuSlots;

  // --- Estado: Lista de la Compra ---
  List<ShoppingItemModel> _shoppingItems = [];
  List<ShoppingItemModel> get shoppingItems => _shoppingItems;

  List<ShoppingItemModel> get pendingShoppingItems =>
      _shoppingItems.where((i) => !i.isChecked).toList();

  List<ShoppingItemModel> get completedShoppingItems =>
      _shoppingItems.where((i) => i.isChecked).toList();

  // Inicialización
  Future<void> initialize({
    required String environmentId,
    required String userId,
    DateTime? initialDate,
  }) async {
    _environmentId = environmentId;
    _userId = userId;
    _weekStartDate = _getMondayOfWeek(initialDate ?? DateTime.now());

    await loadAll();
  }

  static DateTime _getMondayOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final weekday = clean.weekday; // 1 = Lunes, 7 = Domingo
    return clean.subtract(Duration(days: weekday - 1));
  }

  void changeWeek(int offsetWeeks) {
    _weekStartDate = _weekStartDate.add(Duration(days: offsetWeeks * 7));
    loadWeeklyMenu();
  }

  void goToCurrentWeek() {
    _weekStartDate = _getMondayOfWeek(DateTime.now());
    loadWeeklyMenu();
  }

  Future<void> loadAll() async {
    if (_environmentId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        loadDishes(),
        loadWeeklyMenu(),
        loadShoppingItems(),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Métodos de Platos (Dishes) & Filtros ---
  Future<void> setFilters({
    String? query,
    String? cuisine,
    String? temperature,
    String? appliance,
  }) async {
    if (query != null) _searchQuery = query;
    if (cuisine != null) _selectedCuisine = cuisine;
    if (temperature != null) _selectedTemperature = temperature;
    if (appliance != null) _selectedAppliance = appliance;

    await loadDishes();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCuisine = 'Todas';
    _selectedTemperature = 'Todos';
    _selectedAppliance = 'Todos';
    loadDishes();
  }

  Future<void> loadDishes({
    String? query,
    String? cuisine,
    String? servingTemperature,
    String? appliance,
  }) async {
    if (_environmentId == null) return;
    _dishes = await _repository.getDishes(
      _environmentId!,
      query: query ?? _searchQuery,
      cuisine: cuisine ?? _selectedCuisine,
      servingTemperature: servingTemperature ?? _selectedTemperature,
      appliance: appliance ?? _selectedAppliance,
    );
    notifyListeners();
  }

  Future<DishModel> saveDish({
    String? id,
    required String name,
    int defaultServings = 2,
    required List<String> ingredients,
    String? cuisine,
    String? servingTemperature,
    List<String> supportedAppliances = const [],
    int? totalTimeMinutes,
  }) async {
    if (_environmentId == null) throw Exception('No environment');
    final dish = DishModel(
      id: id ?? '',
      environmentId: _environmentId!,
      name: name.trim(),
      defaultServings: defaultServings,
      ingredients: ingredients,
      cuisine: cuisine,
      servingTemperature: servingTemperature,
      supportedAppliances: supportedAppliances,
      totalTimeMinutes: totalTimeMinutes,
      createdBy: _userId,
      createdAt: DateTime.now(),
    );

    final saved = await _repository.saveDish(dish);
    final idx = _dishes.indexWhere((d) => d.id == saved.id);
    if (idx != -1) {
      _dishes[idx] = saved;
    } else {
      _dishes.add(saved);
      _dishes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    notifyListeners();
    return saved;
  }

  Future<void> deleteDish(String dishId) async {
    await _repository.deleteDish(dishId);
    _dishes.removeWhere((d) => d.id == dishId);
    await loadWeeklyMenu();
    notifyListeners();
  }

  // --- Métodos de Menú Semanal ---
  Future<void> loadWeeklyMenu() async {
    if (_environmentId == null) return;
    _menuSlots = await _repository.getWeeklyMenuSlots(
      environmentId: _environmentId!,
      startDate: _weekStartDate,
      endDate: weekEndDate,
    );
    notifyListeners();
  }

  WeeklyMenuSlotModel? getSlot(DateTime date, MealType mealType) {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final s in _menuSlots) {
      final sStr =
          '${s.slotDate.year.toString().padLeft(4, '0')}-${s.slotDate.month.toString().padLeft(2, '0')}-${s.slotDate.day.toString().padLeft(2, '0')}';
      if (sStr == dateStr && s.mealType == mealType) {
        return s;
      }
    }
    return null;
  }

  Future<void> assignDishToSlot({
    required DateTime date,
    required MealType mealType,
    DishModel? dish,
    String? customDishName,
    String? servingsNote,
    bool syncIngredientsToShopping = false,
  }) async {
    if (_environmentId == null) return;

    final existingSlot = getSlot(date, mealType);
    final slotToSave = WeeklyMenuSlotModel(
      id: existingSlot?.id ?? '',
      environmentId: _environmentId!,
      slotDate: date,
      mealType: mealType,
      dishId: (dish != null && !dish.isGlobal) ? dish.id : null,
      customDishName: customDishName ?? (dish?.isGlobal == true ? dish?.name : null),
      servingsNote: servingsNote,
      dish: dish,
      createdBy: _userId,
      createdAt: DateTime.now(),
    );

    final saved = await _repository.upsertMenuSlot(slotToSave);

    final idx = _menuSlots.indexWhere((s) => s.id == saved.id);
    if (idx != -1) {
      _menuSlots[idx] = saved;
    } else {
      _menuSlots.add(saved);
    }

    if (syncIngredientsToShopping && dish != null && dish.ingredients.isNotEmpty) {
      await sendDishIngredients(dish);
    }

    notifyListeners();
  }

  Future<void> clearSlot(DateTime date, MealType mealType) async {
    final existing = getSlot(date, mealType);
    if (existing != null && existing.id.isNotEmpty) {
      await _repository.clearMenuSlot(existing.id);
      _menuSlots.removeWhere((s) => s.id == existing.id);
      notifyListeners();
    }
  }

  Future<void> copyDishToDays({
    required DateTime sourceDate,
    required MealType mealType,
    required List<DateTime> targetDates,
  }) async {
    final source = getSlot(sourceDate, mealType);
    if (source == null || source.isEmpty) return;

    await _repository.copySlotToOtherDays(
      sourceSlot: source,
      targetDates: targetDates,
      mealType: mealType,
    );

    await loadWeeklyMenu();
  }

  // --- Métodos de Lista de la Compra ---
  Future<void> loadShoppingItems() async {
    if (_environmentId == null) return;
    _shoppingItems = await _repository.getShoppingItems(_environmentId!);
    notifyListeners();
  }

  Future<void> addQuickShoppingItem(String name, {String? categoryOrSource}) async {
    final clean = name.trim();
    if (clean.isEmpty || _environmentId == null) return;

    final item = ShoppingItemModel(
      id: '',
      environmentId: _environmentId!,
      name: clean,
      isChecked: false,
      categoryOrSource: categoryOrSource,
      createdBy: _userId,
      createdAt: DateTime.now(),
    );

    final saved = await _repository.addShoppingItem(item);
    if (!_shoppingItems.any((i) => i.id == saved.id)) {
      _shoppingItems.insert(0, saved);
    }
    notifyListeners();
  }

  Future<void> toggleShoppingItem(String itemId, bool isChecked) async {
    final idx = _shoppingItems.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      final current = _shoppingItems[idx];
      _shoppingItems[idx] = current.copyWith(isChecked: isChecked);
      notifyListeners();
      await _repository.toggleShoppingItem(itemId: itemId, isChecked: isChecked);
    }
  }

  Future<void> deleteShoppingItem(String itemId) async {
    _shoppingItems.removeWhere((i) => i.id == itemId);
    notifyListeners();
    await _repository.deleteShoppingItem(itemId);
  }

  Future<void> clearCompletedShoppingItems() async {
    if (_environmentId == null) return;
    _shoppingItems.removeWhere((i) => i.isChecked);
    notifyListeners();
    await _repository.clearCompletedShoppingItems(_environmentId!);
  }

  Future<int> sendDishIngredients(DishModel dish) async {
    if (_environmentId == null || dish.ingredients.isEmpty) return 0;
    final added = await _repository.sendDishIngredientsToShoppingList(
      environmentId: _environmentId!,
      dishName: dish.name,
      ingredients: dish.ingredients,
      dishId: dish.id,
    );
    await loadShoppingItems();
    return added;
  }

  Future<int> sendEntireWeekIngredients() async {
    if (_environmentId == null) return 0;
    int totalAdded = 0;
    final processedDishNames = <String>{};

    for (final slot in _menuSlots) {
      final name = slot.displayName;
      if (name.isNotEmpty && !processedDishNames.contains(name.toLowerCase())) {
        processedDishNames.add(name.toLowerCase());
        final ingredients = slot.dish?.ingredients ?? [];
        if (ingredients.isNotEmpty) {
          final added = await _repository.sendDishIngredientsToShoppingList(
            environmentId: _environmentId!,
            dishName: name,
            ingredients: ingredients,
            dishId: slot.dish?.id,
          );
          totalAdded += added;
        }
      }
    }

    if (totalAdded > 0) {
      await loadShoppingItems();
    }
    return totalAdded;
  }
}
