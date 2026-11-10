import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/weekly_menu_slot_model.dart';
import '../controllers/food_controller.dart';
import 'select_dish_modal.dart';

class WeeklyMenuView extends StatelessWidget {
  final FoodController controller;

  const WeeklyMenuView({super.key, required this.controller});

  String _formatWeekRange(DateTime start, DateTime end) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]}';
  }

  String _dayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = controller.weekStartDate;
    final end = controller.weekEndDate;
    final now = DateTime.now();

    return Column(
      children: [
        // Cabecera de semana con selector despejado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () => controller.changeWeek(-1),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.goToCurrentWeek(),
                  child: Column(
                    children: [
                      Text(
                        _formatWeekRange(start, end),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Toca para ir a esta semana',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () => controller.changeWeek(1),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              // Botón rápido para enviar todos los ingredientes de la semana al carrito
              IconButton(
                tooltip: 'Enviar ingredientes de la semana a la compra',
                icon: Icon(Icons.add_shopping_cart, color: AppTheme.primaryLiquid, size: 20),
                onPressed: () async {
                  final count = await controller.sendEntireWeekIngredients();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          count > 0
                              ? 'Se añadieron $count ingredientes a la compra'
                              : 'No hay ingredientes nuevos para añadir',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white10, height: 1),

        // Lista limpia de 7 días (Lunes a Domingo)
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dayDate = start.add(Duration(days: index));
              final isToday = dayDate.year == now.year &&
                  dayDate.month == now.month &&
                  dayDate.day == now.day;

              final lunchSlot = controller.getSlot(dayDate, MealType.lunch);
              final dinnerSlot = controller.getSlot(dayDate, MealType.dinner);

              return _buildDayCard(
                context: context,
                date: dayDate,
                isToday: isToday,
                lunchSlot: lunchSlot,
                dinnerSlot: dinnerSlot,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard({
    required BuildContext context,
    required DateTime date,
    required bool isToday,
    required WeeklyMenuSlotModel? lunchSlot,
    required WeeklyMenuSlotModel? dinnerSlot,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday
            ? AppTheme.primaryLiquid.withValues(alpha: 0.05)
            : AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? AppTheme.primaryLiquid.withValues(alpha: 0.3)
              : AppTheme.cardBorderColor,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del día
          Row(
            children: [
              Text(
                '${_dayLabel(date.weekday)} ${date.day}',
                style: TextStyle(
                  color: isToday ? AppTheme.primaryLiquid : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HOY',
                    style: TextStyle(
                      color: AppTheme.primaryLiquid,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // 2 ranuras: Almuerzo y Cena
          Row(
            children: [
              // Almuerzo
              Expanded(
                child: _buildMealSlotCell(
                  context: context,
                  date: date,
                  mealType: MealType.lunch,
                  slot: lunchSlot,
                ),
              ),
              const SizedBox(width: 10),
              // Cena
              Expanded(
                child: _buildMealSlotCell(
                  context: context,
                  date: date,
                  mealType: MealType.dinner,
                  slot: dinnerSlot,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealSlotCell({
    required BuildContext context,
    required DateTime date,
    required MealType mealType,
    required WeeklyMenuSlotModel? slot,
  }) {
    final hasDish = slot != null && !slot.isEmpty;

    return GestureDetector(
      onTap: () {
        SelectDishModal.show(
          context,
          date: date,
          mealType: mealType,
          dishes: controller.dishes,
          currentSlot: slot,
          onSelect: (dish, customName, servingsNote, syncIngredients, repeatDates) async {
            await controller.assignDishToSlot(
              date: date,
              mealType: mealType,
              dish: dish,
              customDishName: customName,
              servingsNote: servingsNote,
              syncIngredientsToShopping: syncIngredients,
            );

            // Si seleccionó días para batch cooking rápido
            if (repeatDates.isNotEmpty) {
              await controller.copyDishToDays(
                sourceDate: date,
                mealType: mealType,
                targetDates: repeatDates,
              );
            }
          },
          onCreateNewDish: (name, servings, ingredients) async {
            final savedDish = await controller.saveDish(
              name: name,
              defaultServings: servings,
              ingredients: ingredients,
            );
            await controller.assignDishToSlot(
              date: date,
              mealType: mealType,
              dish: savedDish,
              servingsNote: '$servings rac.',
              syncIngredientsToShopping: true,
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasDish
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasDish ? Colors.white12 : Colors.white10,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Text(
              mealType.iconEmoji,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: hasDish
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (slot.servingsNote != null && slot.servingsNote!.isNotEmpty)
                          Text(
                            slot.servingsNote!,
                            style: TextStyle(
                              color: AppTheme.primaryLiquid.withValues(alpha: 0.8),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    )
                  : Text(
                      '+ Añadir',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
            ),
            if (hasDish)
              GestureDetector(
                onTap: () => controller.clearSlot(date, mealType),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
