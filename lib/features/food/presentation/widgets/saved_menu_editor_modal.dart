import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/models/saved_weekly_menu_model.dart';
import '../../domain/models/saved_weekly_menu_slot_model.dart';
import '../controllers/weekly_menu_planner_controller.dart';
import 'meal_slot_picker_modal.dart';

/// Editor completo de menú guardado (Preset):
/// Permite configurar los 7 días de la semana con hasta 5 slots opcionales por día
class SavedMenuEditorModal extends StatefulWidget {
  final WeeklyMenuPlannerController controller;
  final SavedWeeklyMenuModel? initialMenu;

  const SavedMenuEditorModal({
    super.key,
    required this.controller,
    this.initialMenu,
  });

  static Future<SavedWeeklyMenuModel?> show(
    BuildContext context, {
    required WeeklyMenuPlannerController controller,
    SavedWeeklyMenuModel? initialMenu,
  }) {
    return showModalBottomSheet<SavedWeeklyMenuModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SavedMenuEditorModal(
        controller: controller,
        initialMenu: initialMenu,
      ),
    );
  }

  @override
  State<SavedMenuEditorModal> createState() => _SavedMenuEditorModalState();
}

class _SavedMenuEditorModalState extends State<SavedMenuEditorModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  int _selectedDayOfWeek = 1; // 1 = Lunes .. 7 = Domingo
  final Map<String, SavedWeeklyMenuSlotModel> _draftSlots = {};
  bool _isSaving = false;

  final List<MealType> _allMealTypes = [
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
    _nameController = TextEditingController(text: widget.initialMenu?.name ?? '');
    _descController = TextEditingController(text: widget.initialMenu?.description ?? '');

    // Cargar slots existentes si editamos
    if (widget.initialMenu != null) {
      for (final slot in widget.initialMenu!.slots) {
        final key = '${slot.dayOfWeek}_${slot.mealType.dbValue}';
        _draftSlots[key] = slot;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  int _countSlotsForDay(int dayOfWeek) {
    int count = 0;
    for (final meal in _allMealTypes) {
      if (_draftSlots.containsKey('${dayOfWeek}_${meal.dbValue}')) {
        count++;
      }
    }
    return count;
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

  Future<void> _openSlotPicker(int dayOfWeek, MealType mealType) async {
    final key = '${dayOfWeek}_${mealType.dbValue}';
    final existing = _draftSlots[key];
    final dayName = _dayNames[dayOfWeek - 1];

    final result = await MealSlotPickerModal.show(
      context,
      title: '$dayName • ${mealType.displayName}',
      subtitle: 'Elige una receta, favorito o alimento libre para la plantilla',
      repository: widget.controller.repository,
      environmentId: widget.controller.currentEnvironmentId,
      favorites: widget.controller.favorites,
      hasExistingItem: existing != null,
    );

    if (result == null) return;

    setState(() {
      if (result is RecipeSlotResult) {
        _draftSlots[key] = SavedWeeklyMenuSlotModel(
          id: existing?.id ?? '',
          savedMenuId: widget.initialMenu?.id ?? '',
          dayOfWeek: dayOfWeek,
          mealType: mealType,
          itemType: SlotItemType.recipe,
          recipeId: result.recipe.id,
          customName: null,
          recipe: result.recipe,
        );
      } else if (result is SingleIngredientSlotResult) {
        _draftSlots[key] = SavedWeeklyMenuSlotModel(
          id: existing?.id ?? '',
          savedMenuId: widget.initialMenu?.id ?? '',
          dayOfWeek: dayOfWeek,
          mealType: mealType,
          itemType: SlotItemType.singleIngredient,
          recipeId: null,
          customName: result.name,
        );
      } else if (result is ClearSlotResult) {
        _draftSlots.remove(key);
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    setState(() => _isSaving = true);
    try {
      SavedWeeklyMenuModel result;
      final slotsList = _draftSlots.values.toList();

      if (widget.initialMenu != null) {
        result = await widget.controller.updatePreset(
          menu: widget.initialMenu!.copyWith(
            name: name,
            description: desc.isNotEmpty ? desc : null,
          ),
          slots: slotsList,
        );
      } else {
        result = await widget.controller.createPreset(
          name: name,
          description: desc.isNotEmpty ? desc : null,
          slots: slotsList,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.initialMenu != null
                      ? 'Menú "$name" actualizado correctamente.'
                      : 'Menú "$name" guardado en la biblioteca.',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentCoral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Error al guardar el menú: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.92;
    final totalPlannedMeals = _draftSlots.length;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLiquid.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_stories_rounded, color: AppTheme.primaryLiquid, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.initialMenu != null ? 'Editar Menú Guardado' : 'Nuevo Menú Guardado',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: AppTheme.cardBorderColor),

            // Inputs de Nombre y Descripción
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresa un nombre para el menú (ej. Semana rápida)';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Nombre del Menú *',
                      labelStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      hintText: 'Ej. Semana saludable, Menú exprés airfryer...',
                      hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      prefixIcon: Icon(Icons.title_rounded, size: 20, color: AppTheme.primaryLiquid),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Descripción u objetivo (opcional)',
                      labelStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      hintText: 'Ej. Menú bajo en carbohidratos para semanas con poco tiempo...',
                      hintStyle: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selector horizontal de días (Lunes a Domingo)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(7, (i) {
                    final dayNum = i + 1;
                    final isSel = _selectedDayOfWeek == dayNum;
                    final filledCount = _countSlotsForDay(dayNum);

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDayOfWeek = dayNum);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.primaryLiquid
                                : Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? AppTheme.primaryLiquid : AppTheme.cardBorderColor,
                              width: 0.8,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayShortNames[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$filledCount/5',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : AppTheme.textSecondary,
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
            ),

            Divider(height: 1, color: AppTheme.cardBorderColor),

            // Lista de los 5 slots para el día seleccionado
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_dayNames[_selectedDayOfWeek - 1]} • 5 Comidas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Toca un slot para asignar',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ..._allMealTypes.map((mealType) {
                    final key = '${_selectedDayOfWeek}_${mealType.dbValue}';
                    final slot = _draftSlots[key];
                    return _buildSlotEditorTile(
                      dayOfWeek: _selectedDayOfWeek,
                      mealType: mealType,
                      slot: slot,
                    );
                  }),
                ],
              ),
            ),

            // Footer con Total y Botón Guardar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                border: Border(top: BorderSide(color: AppTheme.cardBorderColor, width: 0.8)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total comidas:',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      Text(
                        '$totalPlannedMeals / 35',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppButton(
                      text: widget.initialMenu != null ? 'Guardar Cambios' : 'Guardar Plantilla',
                      isLoading: _isSaving,
                      icon: Icons.check_rounded,
                      onPressed: _handleSave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotEditorTile({
    required int dayOfWeek,
    required MealType mealType,
    required SavedWeeklyMenuSlotModel? slot,
  }) {
    final mealIcon = _getMealIcon(mealType);
    final isFilled = slot != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openSlotPicker(dayOfWeek, mealType),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isFilled ? AppTheme.surfaceDark : Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFilled ? AppTheme.primaryLiquid.withValues(alpha: 0.5) : AppTheme.cardBorderColor,
              width: isFilled ? 1.0 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFilled
                      ? AppTheme.primaryLiquid.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  mealIcon,
                  size: 18,
                  color: isFilled ? AppTheme.primaryLiquid : AppTheme.textSecondary,
                ),
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
                    const SizedBox(height: 2),
                    Text(
                      isFilled ? slot.displayTitle : '+ Asignar plato o alimento',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isFilled ? FontWeight.bold : FontWeight.w500,
                        color: isFilled ? AppTheme.textPrimary : AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isFilled) ...[
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.accentCoral),
                  tooltip: 'Borrar slot',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _draftSlots.remove('${dayOfWeek}_${mealType.dbValue}');
                    });
                  },
                ),
              ] else ...[
                Icon(Icons.add_rounded, size: 20, color: AppTheme.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
