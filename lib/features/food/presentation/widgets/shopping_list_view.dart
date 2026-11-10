import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shopping_item_model.dart';
import '../controllers/food_controller.dart';

class ShoppingListView extends StatefulWidget {
  final FoodController controller;

  const ShoppingListView({super.key, required this.controller});

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  final TextEditingController _quickInputController = TextEditingController();

  @override
  void dispose() {
    _quickInputController.dispose();
    super.dispose();
  }

  void _addQuickItem() {
    final text = _quickInputController.text.trim();
    if (text.isNotEmpty) {
      widget.controller.addQuickShoppingItem(text);
      _quickInputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.controller.pendingShoppingItems;
    final completed = widget.controller.completedShoppingItems;

    return Column(
      children: [
        // Input directo estilo To-Do List para añadir libremente
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickInputController,
                  onSubmitted: (_) => _addQuickItem(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '+ Añadir producto a la compra...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
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
                onPressed: _addQuickItem,
                icon: Icon(Icons.add_circle, color: AppTheme.primaryLiquid, size: 28),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Barra de acciones secundarias: contador y botón limpiar completados
        if (completed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${completed.length} completados',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
                GestureDetector(
                  onTap: () => widget.controller.clearCompletedShoppingItems(),
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        'Limpiar completados',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const Divider(color: Colors.white10, height: 1),

        // Lista de la compra tipo checklist de tareas
        Expanded(
          child: pending.isEmpty && completed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text(
                        'Tu lista de la compra está vacía.\nAñade productos arriba o envía los platos del menú.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Ítems pendientes (por comprar)
                    ...pending.map((item) => _buildShoppingRow(item)),

                    // Sección colapsada / sutil de ítems completados
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'COMPRADOS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...completed.map((item) => _buildShoppingRow(item)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildShoppingRow(ShoppingItemModel item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
      ),
      onDismissed: (_) => widget.controller.deleteShoppingItem(item.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorderColor, width: 0.6),
        ),
        child: Row(
          children: [
            // Checkbox rápido
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: item.isChecked,
                activeColor: AppTheme.primaryLiquid,
                checkColor: Colors.black,
                side: BorderSide(
                  color: item.isChecked ? AppTheme.primaryLiquid : Colors.white30,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                onChanged: (val) {
                  widget.controller.toggleShoppingItem(item.id, val ?? false);
                },
              ),
            ),
            const SizedBox(width: 10),

            // Nombre y origen (plato o extra)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: item.isChecked ? Colors.white38 : Colors.white,
                      fontSize: 14,
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.categoryOrSource != null && item.categoryOrSource!.isNotEmpty)
                    Text(
                      item.categoryOrSource!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // Botón eliminar discreto
            IconButton(
              icon: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.3)),
              onPressed: () => widget.controller.deleteShoppingItem(item.id),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
