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

  final List<String> _cuisines = [
    'Todas',
    'Española',
    'Italiana',
    'Mexicana',
    'Turca',
    'Asiática',
    'Árabe / Oriente Medio',
    'Peruana',
    'Americana',
    'Francesa',
    'Griega',
    'Internacional',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.controller.dishes;

    return Column(
      children: [
        // Buscador y botón para nuevo plato
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => widget.controller.setFilters(query: val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar en catálogo (1.500+ platos)...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white60, size: 18),
                    suffixIcon: widget.controller.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white60, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              widget.controller.setFilters(query: '');
                            },
                          )
                        : null,
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
                tooltip: 'Crear nuevo plato casero',
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

        // Filtros Rápidos: Temperatura (Frío/Caliente), Electrodoméstico y Cultura del plato
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtro Temperatura: Frío / Caliente
                _buildFilterChip(
                  label: widget.controller.selectedTemperature == 'Todos'
                      ? '🌡️ Temp.'
                      : (widget.controller.selectedTemperature == 'frío' ? '❄️ Frío' : '🔥 Caliente'),
                  isSelected: widget.controller.selectedTemperature != 'Todos',
                  onTap: () {
                    final curr = widget.controller.selectedTemperature;
                    if (curr == 'Todos') {
                      widget.controller.setFilters(temperature: 'frío');
                    } else if (curr == 'frío') {
                      widget.controller.setFilters(temperature: 'caliente');
                    } else {
                      widget.controller.setFilters(temperature: 'Todos');
                    }
                  },
                ),
                const SizedBox(width: 6),

                // Filtro Electrodoméstico
                _buildFilterChip(
                  label: widget.controller.selectedAppliance == 'Todos'
                      ? '♨️ Aparato'
                      : _applianceLabel(widget.controller.selectedAppliance),
                  isSelected: widget.controller.selectedAppliance != 'Todos',
                  onTap: () {
                    const cycle = ['Todos', 'airfryer', 'oven', 'microwave', 'stovetop'];
                    final nextIdx = (cycle.indexOf(widget.controller.selectedAppliance) + 1) % cycle.length;
                    widget.controller.setFilters(appliance: cycle[nextIdx]);
                  },
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 18, color: Colors.white12),
                const SizedBox(width: 8),

                // Filtro Cultura
                ..._cuisines.map((c) {
                  final isSel = widget.controller.selectedCuisine == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => widget.controller.setFilters(cuisine: c),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppTheme.primaryLiquid.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? AppTheme.primaryLiquid : Colors.white12,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            color: isSel ? AppTheme.primaryLiquid : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 4),
        const Divider(color: Colors.white10, height: 1),

        // Contador y lista de platos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${filtered.length} platos disponibles',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
              ),
              const Spacer(),
              if (widget.controller.selectedCuisine != 'Todas' ||
                  widget.controller.selectedTemperature != 'Todos' ||
                  widget.controller.selectedAppliance != 'Todos' ||
                  widget.controller.searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    widget.controller.resetFilters();
                  },
                  child: Text(
                    'Limpiar filtros',
                    style: TextStyle(color: AppTheme.primaryLiquid.withValues(alpha: 0.9), fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        // Lista de platos
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron platos con esos filtros.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLiquid.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLiquid : Colors.white12,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryLiquid : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _applianceLabel(String app) {
    switch (app) {
      case 'airfryer':
        return '🌀 Airfryer';
      case 'oven':
        return '🔥 Horno';
      case 'microwave':
        return '⚡ Microondas';
      case 'stovetop':
        return '🍳 Fuego';
      default:
        return '♨️ $app';
    }
  }

  Widget _buildDishCard(BuildContext context, DishModel dish) {
    final isCold = dish.servingTemperature == 'frío';

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
              if (dish.cuisine != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dish.cuisine!,
                    style: TextStyle(color: AppTheme.primaryLiquid, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCold
                      ? Colors.lightBlueAccent.withValues(alpha: 0.15)
                      : Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCold ? '❄️ Frío' : '🔥 Caliente',
                  style: TextStyle(
                    color: isCold ? Colors.lightBlueAccent : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Menú contextual
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                color: AppTheme.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                ),
                onSelected: (val) {
                  if (val == 'send_ingredients') {
                    widget.controller.sendDishIngredients(dish);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ingredientes de "${dish.name}" añadidos a la compra'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else if (val == 'delete' && !dish.isGlobal) {
                    widget.controller.deleteDish(dish.id);
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
                  if (!dish.isGlobal)
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
              children: dish.ingredients.take(6).map((ing) {
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
