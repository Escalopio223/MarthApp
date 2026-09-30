import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../domain/models/active_calendar_slot_model.dart';
import '../../domain/models/saved_weekly_menu_slot_model.dart';
import '../controllers/weekly_menu_planner_controller.dart';
import '../widgets/load_menu_preset_modal.dart';
import '../widgets/meal_slot_picker_modal.dart';
import '../widgets/recipe_detail_sheet.dart';
import '../widgets/saved_menus_library_view.dart';
import 'food_catalog_screen.dart';

/// Pantalla principal para la planificación semanal:
/// - Calendario Semanal Activo (Lunes a Domingo con 5 slots diarios y Realtime)
/// - Biblioteca de Menús Guardados (Presets)
/// - Acción de volcado de presets hacia el calendario activo
class WeeklyMenuPlannerScreen extends StatefulWidget {
  final WeeklyMenuPlannerController? controller;
  final EnvironmentController? environmentController;
  final bool asTab;

  const WeeklyMenuPlannerScreen({
    super.key,
    this.controller,
    this.environmentController,
    this.asTab = false,
  });

  @override
  State<WeeklyMenuPlannerScreen> createState() => _WeeklyMenuPlannerScreenState();
}

class _WeeklyMenuPlannerScreenState extends State<WeeklyMenuPlannerScreen> {
  late final WeeklyMenuPlannerController _controller;
  int _activeTopTabIndex = 0; // 0: Calendario Activo, 1: Biblioteca de Menús
  int _selectedDayIndex = 0; // 0 = Lunes .. 6 = Domingo
  bool _isFullWeekView = false; // Alternar entre vista de un día vs semana completa

  final List<MealType> _mealTypes = [
    MealType.breakfast,
    MealType.midMorning,
    MealType.lunch,
    MealType.snack,
    MealType.dinner,
  ];

  final List<String> _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  final List<String> _dayShortNames = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? WeeklyMenuPlannerController();
    _controller.addListener(_onControllerChanged);

    // Ajustar el día seleccionado según el día de hoy
    final today = DateTime.now();
    _selectedDayIndex = (today.weekday - 1).clamp(0, 6);

    // Inicializar con el entorno activo
    final envId = widget.environmentController?.activeEnvironment?.id ?? 'default-env';
    final userId = widget.environmentController?.currentUserId ?? 'user';

    _controller.initialize(
      environmentId: envId,
      userId: userId,
    );

    widget.environmentController?.addListener(_onEnvironmentChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onEnvironmentChanged() {
    final newEnvId = widget.environmentController?.activeEnvironment?.id;
    if (newEnvId != null && newEnvId != _controller.currentEnvironmentId) {
      _controller.setEnvironmentId(newEnvId);
    }
  }

  @override
  void dispose() {
    widget.environmentController?.removeListener(_onEnvironmentChanged);
    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _formatWeekRange(DateTime monday, DateTime sunday) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    if (monday.month == sunday.month) {
      return '${monday.day} - ${sunday.day} ${months[monday.month - 1]} ${monday.year}';
    }
    return '${monday.day} ${months[monday.month - 1]} - ${sunday.day} ${months[sunday.month - 1]} ${sunday.year}';
  }

  bool _isCurrentWeek(DateTime monday) {
    final nowMonday = WeeklyMenuPlannerController.getMonday(DateTime.now());
    return monday.year == nowMonday.year &&
        monday.month == nowMonday.month &&
        monday.day == nowMonday.day;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  IconData _getMealIcon(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return Icons.bakery_dining_rounded;
      case MealType.midMorning:
        return Icons.coffee_rounded;
      case MealType.lunch:
        return Icons.soup_kitchen_rounded;
      case MealType.snack:
        return Icons.apple_rounded;
      case MealType.dinner:
        return Icons.nightlife_rounded;
    }
  }

  Color _getMealColor(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return const Color(0xFFF59E0B);
      case MealType.midMorning:
        return const Color(0xFF06B6D4);
      case MealType.lunch:
        return const Color(0xFF10B981);
      case MealType.snack:
        return const Color(0xFFF97316);
      case MealType.dinner:
        return const Color(0xFF8B5CF6);
    }
  }

  int _countFilledSlotsForDate(DateTime date) {
    int count = 0;
    for (final meal in _mealTypes) {
      if (_controller.getSlot(date, meal) != null) {
        count++;
      }
    }
    return count;
  }

  Future<void> _openSlotPicker(DateTime date, MealType mealType) async {
    final existingSlot = _controller.getSlot(date, mealType);
    final dayName = _dayNames[date.weekday - 1];

    final result = await MealSlotPickerModal.show(
      context,
      title: '$dayName • ${mealType.displayName}',
      subtitle: '${date.day}/${date.month}/${date.year} • Elige una opción',
      repository: _controller.repository,
      environmentId: _controller.currentEnvironmentId,
      favorites: _controller.favorites,
      hasExistingItem: existingSlot != null,
    );

    if (result == null) return;

    if (result is RecipeSlotResult) {
      await _controller.setSlotRecipe(date, mealType, result.recipe);
    } else if (result is SingleIngredientSlotResult) {
      await _controller.setSlotSingleIngredient(date, mealType, result.name);
    } else if (result is ClearSlotResult) {
      await _controller.clearSlot(date, mealType);
    }
  }

  Future<void> _showSaveWeekAsPresetDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.cardBorderColor, width: 1),
        ),
        title: Text(
          'Guardar Semana como Menú',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta semana se guardará en la Biblioteca para que puedas reutilizarla en el futuro con un solo tap.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre del Menú *',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                hintText: 'Ej. Menú rápido de exámenes',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 2,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Descripción u objetivo (opcional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                hintText: 'Ej. Alto en proteínas y recetas en airfryer',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLiquid,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar Menú'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final created = await _controller.saveCurrentWeekAsPreset(
          name: nameController.text.trim(),
          description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentEmerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                'Menú "${created.name}" guardado en la biblioteca con éxito.',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentCoral,
              content: Text('Error al guardar menú: $e', style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // 1. Selector Superior de Pestaña: Calendario vs Biblioteca
        _buildTopSegmentedSelector(),

        // 2. Vista activa
        Expanded(
          child: _activeTopTabIndex == 0
              ? _buildActiveCalendarView()
              : SavedMenusLibraryView(controller: _controller),
        ),
      ],
    );

    if (widget.asTab) {
      return content;
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppTheme.actionGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Planificador Semanal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            // Botón a Catálogo de Recetas
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, size: 22),
              tooltip: 'Catálogo de Recetas',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FoodCatalogScreen(
                      environmentController: widget.environmentController,
                    ),
                  ),
                );
              },
            ),
            // Indicador Realtime
            if (_controller.isRealtimeConnected)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentEmerald.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'En vivo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentEmerald,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: content,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. SELECTOR SUPERIOR (Calendario vs Biblioteca)
  // ---------------------------------------------------------------------------
  Widget _buildTopSegmentedSelector() {
    final activeIndex = _activeTopTabIndex;
    final savedMenuCount = _controller.savedMenus.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTopSegmentButton(
                index: 0,
                icon: Icons.event_note_rounded,
                label: 'Calendario Semanal',
                isSelected: activeIndex == 0,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildTopSegmentButton(
                index: 1,
                icon: Icons.auto_stories_rounded,
                label: 'Biblioteca de Menús',
                badgeCount: savedMenuCount,
                isSelected: activeIndex == 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSegmentButton({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
    required bool isSelected,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTopTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLiquid.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primaryLiquid.withValues(alpha: 0.6), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryLiquid : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. VISTA CALENDARIO ACTIVO
  // ---------------------------------------------------------------------------
  Widget _buildActiveCalendarView() {
    final monday = _controller.currentMonday;
    final sunday = _controller.currentSunday;
    final isCurrent = _isCurrentWeek(monday);

    return Column(
      children: [
        // Barra de Navegación de Semanas
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
            boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
                color: AppTheme.textPrimary,
                tooltip: 'Semana anterior',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _controller.previousWeek();
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatWeekRange(monday, sunday),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isCurrent)
                      Text(
                        'Semana actual',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentEmerald,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.goToToday();
                        },
                        child: Text(
                          'Ir a hoy',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryLiquid,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 26),
                color: AppTheme.textPrimary,
                tooltip: 'Semana siguiente',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _controller.nextWeek();
                },
              ),
            ],
          ),
        ),

        // Barra de Acciones de la Semana: Cargar Menú / Guardar Semana / Vista
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLiquid,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text(
                    'Cargar Menú',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => LoadMenuPresetModal.show(context, controller: _controller),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text(
                    'Guardar Menú',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _showSaveWeekAsPresetDialog,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceDark,
                  side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  _isFullWeekView ? Icons.view_day_rounded : Icons.view_week_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                tooltip: _isFullWeekView ? 'Vista día a día' : 'Vista semana completa',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isFullWeekView = !_isFullWeekView);
                },
              ),
            ],
          ),
        ),

        // Selector Horizontal de Días (Lunes a Domingo)
        if (!_isFullWeekView) _buildDaysSelectorStrip(),

        // Contenido: Slots del día seleccionado o vista completa
        Expanded(
          child: _controller.isLoading
              ? Center(child: CircularProgressIndicator(color: AppTheme.primaryLiquid))
              : _isFullWeekView
                  ? _buildFullWeekView()
                  : _buildSingleDaySlotsView(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SELECTOR HORIZONTAL DE DÍAS (Lun..Dom)
  // ---------------------------------------------------------------------------
  Widget _buildDaysSelectorStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            final dayDate = _controller.getDateForDayOfWeek(index + 1);
            final isSelected = _selectedDayIndex == index;
            final isToday = _isToday(dayDate);
            final filledCount = _countFilledSlotsForDate(dayDate);

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDayIndex = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryLiquid
                        : isToday
                            ? AppTheme.primaryLiquid.withValues(alpha: 0.12)
                            : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryLiquid
                          : isToday
                              ? AppTheme.primaryLiquid.withValues(alpha: 0.5)
                              : AppTheme.cardBorderColor,
                      width: isSelected || isToday ? 1.2 : 0.8,
                    ),
                    boxShadow: isSelected ? null : AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dayShortNames[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 3),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppTheme.accentEmerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dayDate.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$filledCount/5',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SLOTS DEL DÍA SELECCIONADO (5 Slots)
  // ---------------------------------------------------------------------------
  Widget _buildSingleDaySlotsView() {
    final selectedDate = _controller.getDateForDayOfWeek(_selectedDayIndex + 1);
    final dayName = _dayNames[_selectedDayIndex];
    final isToday = _isToday(selectedDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      children: [
        // Subcabecera del día
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '$dayName ${selectedDate.day}/${selectedDate.month}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'HOY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentEmerald,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${_countFilledSlotsForDate(selectedDate)} de 5 planificados',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        // 5 Ranuras
        ..._mealTypes.map((mealType) {
          final slot = _controller.getSlot(selectedDate, mealType);
          return _buildMealSlotCard(
            date: selectedDate,
            mealType: mealType,
            slot: slot,
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VISTA DE SEMANA COMPLETA (Scrollable 7 días x 5 slots)
  // ---------------------------------------------------------------------------
  Widget _buildFullWeekView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      itemCount: 7,
      itemBuilder: (ctx, index) {
        final dayDate = _controller.getDateForDayOfWeek(index + 1);
        final dayName = _dayNames[index];
        final isToday = _isToday(dayDate);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isToday ? AppTheme.primaryLiquid.withValues(alpha: 0.6) : AppTheme.cardBorderColor,
              width: isToday ? 1.2 : 0.8,
            ),
            boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera del día
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$dayName ${dayDate.day}/${dayDate.month}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmerald.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HOY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentEmerald,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${_countFilledSlotsForDate(dayDate)}/5',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppTheme.cardBorderColor),

              // Slots
              ..._mealTypes.map((mealType) {
                final slot = _controller.getSlot(dayDate, mealType);
                return _buildMealSlotCard(
                  date: dayDate,
                  mealType: mealType,
                  slot: slot,
                  compact: true,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TARJETA DE RANURA INDIVIDUAL (SLOT CARD)
  // ---------------------------------------------------------------------------
  Widget _buildMealSlotCard({
    required DateTime date,
    required MealType mealType,
    required ActiveCalendarSlotModel? slot,
    bool compact = false,
  }) {
    final isFilled = slot != null;
    final mealIcon = _getMealIcon(mealType);
    final mealColor = _getMealColor(mealType);

    if (!isFilled) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => _openSlotPicker(date, mealType),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorderColor.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: mealColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(mealIcon, size: 16, color: mealColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealType.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '+ Planificar ${mealType.displayName.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      );
    }

    // Slot lleno: Receta o Alimento suelto
    final isRecipe = slot.itemType == SlotItemType.recipe && slot.recipe != null;
    final recipe = slot.recipe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: mealColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
          boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _openSlotPicker(date, mealType),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: mealColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(mealIcon, size: 20, color: mealColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              mealType.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: mealColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isRecipe ? 'Receta' : 'Alimento',
                                style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          slot.displayTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isRecipe && recipe != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                recipe.cuisineType,
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              if (recipe.hasAirfryer) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.air_rounded, size: 12, color: Color(0xFF06B6D4)),
                              ],
                              if (recipe.hasOven) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFF97316)),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Botón "Ver receta" si es receta
                  if (isRecipe && recipe != null)
                    IconButton(
                      icon: const Icon(Icons.menu_book_rounded, size: 20),
                      color: AppTheme.primaryLiquid,
                      tooltip: 'Ver receta completa',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        RecipeDetailSheet.show(
                          context,
                          recipe: recipe,
                          isFavorite: _controller.favorites.any((f) => f.recipeId == recipe.id),
                          onToggleFavorite: () async {
                            final isFav = _controller.favorites.any((f) => f.recipeId == recipe.id);
                            if (isFav) {
                              final fav = _controller.favorites.firstWhere((f) => f.recipeId == recipe.id);
                              await _controller.repository.removeFavorite(fav.id);
                            } else {
                              final envId = _controller.currentEnvironmentId;
                              if (envId != null) {
                                await _controller.repository.addFavoriteRecipe(
                                  environmentId: envId,
                                  recipeId: recipe.id,
                                );
                              }
                            }
                            await _controller.loadFavorites();
                          },
                        );
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.accentCoral),
                    tooltip: 'Vaciar slot',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _controller.clearSlot(date, mealType);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
