import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/food_controller.dart';
import '../widgets/my_dishes_view.dart';
import '../widgets/shopping_list_view.dart';
import '../widgets/weekly_menu_view.dart';

class FoodScreen extends StatefulWidget {
  final FoodController controller;

  const FoodScreen({super.key, required this.controller});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  int _currentTab = 0; // 0: Menú, 1: Compra, 2: Mis Platos

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryLiquid),
          );
        }

        final pendingCount = widget.controller.pendingShoppingItems.length;

        return Column(
          children: [
            // Segmented control superior minimalista
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
                ),
                child: Row(
                  children: [
                    _buildTabItem(index: 0, label: '📅 Menú'),
                    _buildTabItem(
                      index: 1,
                      label: pendingCount > 0 ? '🛒 Compra ($pendingCount)' : '🛒 Compra',
                    ),
                    _buildTabItem(index: 2, label: '🍽️ Mis Platos'),
                  ],
                ),
              ),
            ),

            // Contenido de la pestaña activa
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: [
                  WeeklyMenuView(controller: widget.controller),
                  ShoppingListView(controller: widget.controller),
                  MyDishesView(controller: widget.controller),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabItem({required int index, required String label}) {
    final isSelected = _currentTab == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryLiquid.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppTheme.primaryLiquid.withValues(alpha: 0.3), width: 0.8)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryLiquid : Colors.white60,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
