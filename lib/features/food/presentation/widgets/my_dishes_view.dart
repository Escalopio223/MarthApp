import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/dish_model.dart';
import '../controllers/food_controller.dart';
import 'edit_dish_modal.dart';

class MyDishesView extends StatefulWidget {
  final FoodController controller;

  const MyDishesView({super.key, required this.controller});

  @override
  State<MyDishesView> createState() => _MyDishesViewState();
}

class _MyDishesViewState extends State<MyDishesView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.controller.dishes.where((d) {
      if (_query.trim().isEmpty) return true;
      return d.name.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();

    return Column(
      children: [
        // Buscador y botón para nuevo plato
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _query = val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar en mis platos...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white60, size: 18),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Crear nuevo plato',
                onPressed: () {
                  EditDishModal.show(
                    context,
                    onSave: (name, defaultServings, ingredients) {
                      widget.controller.saveDish(
                        name: name,
                        defaultServings: defaultServings,
                        ingredients: ingredients,
                      );
                    },
                  );
                },
                icon: Icon(Icons.add_circle, color: AppTheme.primaryLiquid, size: 28),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white10, height: 1),

        // Lista limpia de platos
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty
                            ? 'No tienes platos guardados todavía.\nPúlsale a + para crear el primero.'
                            : 'No se encontraron platos con ese nombre.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final dish = filtered[index];
                    return _buildDishCard(context, dish);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDishCard(BuildContext context, DishModel dish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dish.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${dish.defaultServings} rac.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              // Menú contextual: Editar o Eliminar
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                color: AppTheme.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                ),
                onSelected: (val) {
                  if (val == 'edit') {
                    EditDishModal.show(
                      context,
                      initialDish: dish,
                      onSave: (name, defaultServings, ingredients) {
                        widget.controller.saveDish(
                          id: dish.id,
                          name: name,
                          defaultServings: defaultServings,
                          ingredients: ingredients,
                        );
                      },
                    );
                  } else if (val == 'delete') {
                    widget.controller.deleteDish(dish.id);
                  } else if (val == 'send_ingredients') {
                    widget.controller.sendDishIngredients(dish);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ingredientes de "${dish.name}" añadidos a la compra'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'send_ingredients',
                    child: Row(
                      children: [
                        Icon(Icons.add_shopping_cart, size: 16, color: AppTheme.primaryLiquid),
                        const SizedBox(width: 8),
                        const Text('Enviar a la compra', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                        SizedBox(width: 8),
                        Text('Editar plato', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Chips sutiles de ingredientes
          if (dish.ingredients.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: dish.ingredients.map((ing) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ing,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
