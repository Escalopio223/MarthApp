import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/dish_model.dart';

class EditDishModal extends StatefulWidget {
  final DishModel? initialDish;
  final Function(String name, int defaultServings, List<String> ingredients) onSave;

  const EditDishModal({
    super.key,
    this.initialDish,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    DishModel? initialDish,
    required Function(String name, int defaultServings, List<String> ingredients) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditDishModal(
        initialDish: initialDish,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditDishModal> createState() => _EditDishModalState();
}

class _EditDishModalState extends State<EditDishModal> {
  late TextEditingController _nameController;
  late TextEditingController _ingredientController;
  late int _servings;
  final List<String> _ingredients = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDish?.name ?? '');
    _ingredientController = TextEditingController();
    _servings = widget.initialDish?.defaultServings ?? 2;
    if (widget.initialDish != null) {
      _ingredients.addAll(widget.initialDish!.ingredients);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final text = _ingredientController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_ingredients.any((i) => i.toLowerCase() == text.toLowerCase())) {
          _ingredients.add(text);
        }
      });
      _ingredientController.clear();
    }
  }

  void _submit() {
    // Si quedó texto sin añadir en el input de ingrediente, añadirlo
    _addIngredient();

    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    widget.onSave(name, _servings, _ingredients);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialDish != null;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título de la cabecera
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Editar Plato' : 'Nuevo Plato',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Nombre del plato
          TextField(
            controller: _nameController,
            autofocus: !isEditing,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Nombre del plato (ej. Lentejas estofadas)...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          const SizedBox(height: 14),

          // Selector de raciones por defecto
          Row(
            children: [
              Text(
                'Raciones habituales:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                visualDensity: VisualDensity.compact,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_servings',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                onPressed: () => setState(() => _servings++),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Ingredientes necesarios
          Text(
            'Ingredientes necesarios',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ingredientController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (_) => _addIngredient(),
                  decoration: InputDecoration(
                    hintText: 'Añadir ingrediente y pulsar Enter...',
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
                onPressed: _addIngredient,
                icon: Icon(Icons.add_circle, color: AppTheme.primaryLiquid),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Lista de chips de ingredientes
          if (_ingredients.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _ingredients.map((ing) {
                return Chip(
                  label: Text(ing, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white60),
                  onDeleted: () {
                    setState(() {
                      _ingredients.remove(ing);
                    });
                  },
                );
              }).toList(),
            ),

          const SizedBox(height: 20),

          // Botón Guardar
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLiquid,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isEditing ? 'Guardar Cambios' : 'Crear Plato',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
