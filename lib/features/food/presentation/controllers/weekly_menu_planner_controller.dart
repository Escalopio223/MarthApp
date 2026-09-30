import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/active_calendar_slot_model.dart';
import '../../domain/models/food_favorite_model.dart';
import '../../domain/models/recipe_model.dart';
import '../../domain/models/saved_weekly_menu_model.dart';
import '../../domain/models/saved_weekly_menu_slot_model.dart';
import '../../domain/repositories/i_food_repository.dart';
import '../../infrastructure/services/food_service.dart';

/// Controlador reactivo para la planificación semanal de comidas:
/// - Calendario semanal activo (Lunes a Domingo con 5 comidas por día)
/// - Navegación entre semanas con selector de fechas
/// - Sincronización Realtime con Supabase
/// - Biblioteca de menús guardados (presets) y volcado hacia el calendario
class WeeklyMenuPlannerController extends ChangeNotifier {
  final IFoodRepository _repository;

  String? _currentEnvironmentId;
  String? _currentUserId;

  late DateTime _currentMonday;
  bool _isLoading = false;
  bool _isRealtimeConnected = false;
  String? _errorMessage;

  dynamic _realtimeSubscription;

  // Estado del calendario semanal activo
  List<ActiveCalendarSlotModel> _activeSlots = [];
  final Map<String, ActiveCalendarSlotModel> _slotsMap = {};

  // Estado de la biblioteca de menús guardados
  List<SavedWeeklyMenuModel> _savedMenus = [];
  SavedWeeklyMenuModel? _selectedPreset;

  // Favoritos para selección rápida de 1 tap
  List<FoodFavoriteModel> _favorites = [];

  WeeklyMenuPlannerController({
    IFoodRepository? repository,
    DateTime? initialDate,
  })  : _repository = repository ?? FoodService(),
        _currentMonday = getMonday(initialDate ?? DateTime.now());

  // Getters
  IFoodRepository get repository => _repository;
  String? get currentEnvironmentId => _currentEnvironmentId;
  String? get currentUserId => _currentUserId;
  DateTime get currentMonday => _currentMonday;
  DateTime get currentSunday => _currentMonday.add(const Duration(days: 6));
  bool get isLoading => _isLoading;
  bool get isRealtimeConnected => _isRealtimeConnected;
  String? get errorMessage => _errorMessage;

  List<ActiveCalendarSlotModel> get activeSlots => _activeSlots;
  List<SavedWeeklyMenuModel> get savedMenus => _savedMenus;
  SavedWeeklyMenuModel? get selectedPreset => _selectedPreset;
  List<FoodFavoriteModel> get favorites => _favorites;

  List<FoodFavoriteModel> get favoriteRecipes =>
      _favorites.where((f) => f.isRecipe && f.recipe != null).toList();

  List<FoodFavoriteModel> get favoriteIngredients =>
      _favorites.where((f) => f.isIngredient).toList();

  /// Obtiene el lunes (00:00) de cualquier fecha
  static DateTime getMonday(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final weekday = clean.weekday; // 1 = Lunes, 7 = Domingo
    return clean.subtract(Duration(days: weekday - 1));
  }

  /// Retorna la fecha exacta correspondiente al día de la semana (1 = Lunes .. 7 = Domingo)
  DateTime getDateForDayOfWeek(int dayOfWeek) {
    return _currentMonday.add(Duration(days: (dayOfWeek - 1).clamp(0, 6)));
  }

  /// Obtiene el slot del calendario para una fecha y tipo de comida
  ActiveCalendarSlotModel? getSlot(DateTime date, MealType mealType) {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final key = '${dateStr}_${mealType.dbValue}';
    return _slotsMap[key];
  }

  // ---------------------------------------------------------------------------
  // INICIALIZACIÓN Y ENTORNO
  // ---------------------------------------------------------------------------
  Future<void> initialize({
    required String environmentId,
    required String userId,
    DateTime? weekDate,
  }) async {
    _currentEnvironmentId = environmentId;
    _currentUserId = userId;
    if (weekDate != null) {
      _currentMonday = getMonday(weekDate);
    }

    _setupRealtime();

    await Future.wait([
      loadActiveCalendar(),
      loadSavedMenus(),
      loadFavorites(),
    ]);
  }

  Future<void> setEnvironmentId(String environmentId) async {
    if (_currentEnvironmentId == environmentId) return;
    _currentEnvironmentId = environmentId;
    _setupRealtime();

    await Future.wait([
      loadActiveCalendar(),
      loadSavedMenus(),
      loadFavorites(),
    ]);
  }

  void _setupRealtime() {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) return;

    if (_realtimeSubscription != null) {
      _repository.unsubscribe(_realtimeSubscription);
      _realtimeSubscription = null;
    }

    try {
      _realtimeSubscription = _repository.subscribeToActiveCalendar(
        envId,
        () {
          // Recargar silenciosamente el calendario activo ante cambios remotos
          loadActiveCalendar(silent: true);
        },
      );
      _isRealtimeConnected = true;
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Realtime no disponible: $e');
      _isRealtimeConnected = false;
    }
  }

  // ---------------------------------------------------------------------------
  // NAVEGACIÓN SEMANAL
  // ---------------------------------------------------------------------------
  void nextWeek() {
    _currentMonday = _currentMonday.add(const Duration(days: 7));
    loadActiveCalendar();
  }

  void previousWeek() {
    _currentMonday = _currentMonday.subtract(const Duration(days: 7));
    loadActiveCalendar();
  }

  void goToToday() {
    final todayMonday = getMonday(DateTime.now());
    if (_currentMonday != todayMonday) {
      _currentMonday = todayMonday;
      loadActiveCalendar();
    }
  }

  // ---------------------------------------------------------------------------
  // CARGA DE DATOS
  // ---------------------------------------------------------------------------
  Future<void> loadActiveCalendar({bool silent = false}) async {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) return;

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final sunday = currentSunday;
      _activeSlots = await _repository.getActiveCalendarSlots(
        environmentId: envId,
        startDate: _currentMonday,
        endDate: sunday,
      );

      _slotsMap.clear();
      for (final slot in _activeSlots) {
        final key = '${slot.dateString}_${slot.mealType.dbValue}';
        _slotsMap[key] = slot;
      }
    } catch (e) {
      _errorMessage = 'Error al cargar calendario: $e';
      debugPrint('[WeeklyMenuPlannerController] loadActiveCalendar error: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadSavedMenus() async {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) return;

    try {
      _savedMenus = await _repository.getSavedWeeklyMenus(envId);
      notifyListeners();
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] loadSavedMenus error: $e');
    }
  }

  Future<void> loadFavorites() async {
    final envId = _currentEnvironmentId;
    if (envId == null || envId.isEmpty) return;

    try {
      _favorites = await _repository.getFavorites(envId);
      notifyListeners();
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] loadFavorites error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ASIGNACIÓN Y GESTIÓN DE SLOTS EN CALENDARIO ACTIVO
  // ---------------------------------------------------------------------------
  Future<void> setSlotRecipe(DateTime date, MealType mealType, RecipeModel recipe) async {
    final envId = _currentEnvironmentId;
    if (envId == null) return;

    final existing = getSlot(date, mealType);
    final slot = ActiveCalendarSlotModel(
      id: existing?.id ?? '',
      environmentId: envId,
      date: date,
      mealType: mealType,
      itemType: SlotItemType.recipe,
      recipeId: recipe.id,
      customName: null,
      recipe: recipe,
    );

    // Optimistic update
    final key = '${slot.dateString}_${mealType.dbValue}';
    _slotsMap[key] = slot;
    notifyListeners();

    try {
      final saved = await _repository.upsertActiveCalendarSlot(slot);
      _slotsMap[key] = saved;
      final idx = _activeSlots.indexWhere((s) => s.id == saved.id);
      if (idx != -1) {
        _activeSlots[idx] = saved;
      } else {
        _activeSlots.add(saved);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al asignar receta a slot: $e');
      await loadActiveCalendar();
    }
  }

  Future<void> setSlotSingleIngredient(DateTime date, MealType mealType, String customName) async {
    final envId = _currentEnvironmentId;
    if (envId == null) return;

    final cleanName = customName.trim();
    if (cleanName.isEmpty) return;

    final existing = getSlot(date, mealType);
    final slot = ActiveCalendarSlotModel(
      id: existing?.id ?? '',
      environmentId: envId,
      date: date,
      mealType: mealType,
      itemType: SlotItemType.singleIngredient,
      recipeId: null,
      customName: cleanName,
    );

    // Optimistic update
    final key = '${slot.dateString}_${mealType.dbValue}';
    _slotsMap[key] = slot;
    notifyListeners();

    try {
      final saved = await _repository.upsertActiveCalendarSlot(slot);
      _slotsMap[key] = saved;
      final idx = _activeSlots.indexWhere((s) => s.id == saved.id);
      if (idx != -1) {
        _activeSlots[idx] = saved;
      } else {
        _activeSlots.add(saved);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al asignar alimento a slot: $e');
      await loadActiveCalendar();
    }
  }

  Future<void> clearSlot(DateTime date, MealType mealType) async {
    final existing = getSlot(date, mealType);
    if (existing == null) return;

    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final key = '${dateStr}_${mealType.dbValue}';

    // Optimistic remove
    _slotsMap.remove(key);
    _activeSlots.removeWhere((s) => s.id == existing.id);
    notifyListeners();

    try {
      if (existing.id.isNotEmpty) {
        await _repository.deleteActiveCalendarSlot(existing.id);
      }
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al vaciar slot: $e');
      await loadActiveCalendar();
    }
  }

  // ---------------------------------------------------------------------------
  // VOLCADO Y GUARDADO DE PRESETS DE MENÚS
  // ---------------------------------------------------------------------------
  Future<void> applyPresetToCurrentWeek(
    String savedMenuId, {
    bool overwrite = true,
  }) async {
    final envId = _currentEnvironmentId;
    if (envId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _repository.applySavedMenuToCalendar(
        environmentId: envId,
        savedMenuId: savedMenuId,
        mondayStartDate: _currentMonday,
        overwrite: overwrite,
      );

      await loadActiveCalendar();
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al aplicar preset: $e');
      _errorMessage = 'No se pudo aplicar el menú guardado: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SavedWeeklyMenuModel> saveCurrentWeekAsPreset({
    required String name,
    String? description,
  }) async {
    final envId = _currentEnvironmentId;
    if (envId == null) {
      throw StateError('Debes seleccionar un entorno antes de guardar el menú.');
    }

    try {
      final created = await _repository.saveActiveWeekAsMenu(
        environmentId: envId,
        name: name,
        description: description,
        mondayStartDate: _currentMonday,
      );

      _savedMenus.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al guardar semana como preset: $e');
      rethrow;
    }
  }

  Future<SavedWeeklyMenuModel> createPreset({
    required String name,
    String? description,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async {
    final envId = _currentEnvironmentId;
    if (envId == null) throw StateError('Entorno no seleccionado');

    try {
      final created = await _repository.createSavedWeeklyMenu(
        menu: SavedWeeklyMenuModel(
          id: '',
          environmentId: envId,
          name: name.trim(),
          description: description?.trim().isNotEmpty == true ? description!.trim() : null,
          createdAt: DateTime.now(),
        ),
        slots: slots,
      );

      _savedMenus.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al crear preset: $e');
      rethrow;
    }
  }

  Future<SavedWeeklyMenuModel> updatePreset({
    required SavedWeeklyMenuModel menu,
    required List<SavedWeeklyMenuSlotModel> slots,
  }) async {
    try {
      final updated = await _repository.updateSavedWeeklyMenu(
        menu: menu,
        slots: slots,
      );

      final idx = _savedMenus.indexWhere((m) => m.id == updated.id);
      if (idx != -1) {
        _savedMenus[idx] = updated;
      }
      if (_selectedPreset?.id == updated.id) {
        _selectedPreset = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al actualizar preset: $e');
      rethrow;
    }
  }

  Future<void> renamePreset(String menuId, String newName, String? newDescription) async {
    try {
      final updated = await _repository.renameSavedWeeklyMenu(
        menuId: menuId,
        newName: newName,
        newDescription: newDescription,
      );

      final idx = _savedMenus.indexWhere((m) => m.id == menuId);
      if (idx != -1) {
        _savedMenus[idx] = updated;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al renombrar preset: $e');
      rethrow;
    }
  }

  Future<void> deletePreset(String menuId) async {
    try {
      await _repository.deleteSavedWeeklyMenu(menuId);
      _savedMenus.removeWhere((m) => m.id == menuId);
      if (_selectedPreset?.id == menuId) {
        _selectedPreset = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[WeeklyMenuPlannerController] Error al eliminar preset: $e');
      rethrow;
    }
  }

  void selectPresetForPreview(SavedWeeklyMenuModel? preset) {
    _selectedPreset = preset;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_realtimeSubscription != null) {
      _repository.unsubscribe(_realtimeSubscription);
    }
    super.dispose();
  }
}
