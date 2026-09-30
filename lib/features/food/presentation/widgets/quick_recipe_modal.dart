import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../controllers/food_catalog_controller.dart';

/// Modal ultra-rápido (<20 segundos) para dar de alta platos caseros
class QuickRecipeModal extends StatefulWidget {
  final FoodCatalogController controller;

  const QuickRecipeModal({
    super.key,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required FoodCatalogController controller,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuickRecipeModal(controller: controller),
    );
  }

  @override
  State<QuickRecipeModal> createState() => _QuickRecipeModalState();
}

class _QuickRecipeModalState extends State<QuickRecipeModal> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _countryController = TextEditingController(text: 'España');
  final _tagController = TextEditingController();

  final _airfryerController = TextEditingController();
  final _ovenController = TextEditingController();
  final _microwaveController = TextEditingController();

  String _selectedCuisine = 'Casera';
  final List<String> _ingredientTags = [];
  bool _showApplianceFields = false;
  bool _isSubmitting = false;

  final List<String> _quickCuisinePresets = [
    'Casera',
    'Rápida',
    'Saludable',
    'Airfryer',
    'Mediterránea',
    'Italiana',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _countryController.dispose();
    _tagController.dispose();
    _airfryerController.dispose();
    _ovenController.dispose();
    _microwaveController.dispose();
    super.dispose();
  }

  void _addTag(String rawValue) {
    final value = rawValue.replaceAll(',', '').trim();
    if (value.isNotEmpty && !_ingredientTags.contains(value.toLowerCase())) {
      HapticFeedback.selectionClick();
      setState(() {
        _ingredientTags.add(value.toLowerCase());
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      _ingredientTags.remove(tag);
    });
  }

  Future<void> _submit() async {
    // Si quedó texto sin confirmar en el input de tags, añadirlo
    if (_tagController.text.trim().isNotEmpty) {
      _addTag(_tagController.text);
    }

    if (!_formKey.currentState!.validate()) return;

    if (_ingredientTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, añade al menos un ingrediente para la receta.'),
          backgroundColor: AppTheme.accentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.controller.createQuickRecipe(
        title: _titleController.text,
        country: _countryController.text,
        cuisineType: _selectedCuisine,
        ingredientNames: _ingredientTags,
        prepAirfryer: _airfryerController.text,
        prepOven: _ovenController.text,
        prepMicrowave: _microwaveController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡"${_titleController.text}" guardada en recetas caseras!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar receta: $e'),
            backgroundColor: AppTheme.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppTheme.cardBorderColor, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera del modal
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.primaryLiquid,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nueva Receta Casera',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Registro ágil (<20 seg) para tu entorno',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 1. Nombre del plato (autofocus)
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Nombre del plato *',
                    hintText: 'Ej. Tortilla exprés de calabacín',
                    prefixIcon: const Icon(Icons.restaurant_rounded, size: 20),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.cardBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Indica un nombre para el plato';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // 2. País / Cultura y Selector de Cocina
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _countryController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'País / Región',
                          prefixIcon: const Icon(Icons.public_rounded, size: 18),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.cardBorderColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCuisine,
                            isExpanded: true,
                            dropdownColor: AppTheme.surfaceDark,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                            items: _quickCuisinePresets.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCuisine = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Input de ingredientes por tags
                Text(
                  'INGREDIENTES (escribe y pulsa Enter o coma)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _tagController,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Añadir ingrediente (ej. calabacín, huevo...)',
                    prefixIcon: const Icon(Icons.shopping_basket_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: Colors.white70),
                      onPressed: () => _addTag(_tagController.text),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.cardBorderColor),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.endsWith(',')) {
                      _addTag(val);
                    }
                  },
                  onSubmitted: _addTag,
                ),

                if (_ingredientTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _ingredientTags.map((tag) {
                      return Chip(
                        label: Text(
                          tag[0].toUpperCase() + tag.substring(1),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                        deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        onDeleted: () => _removeTag(tag),
                        side: BorderSide(
                          color: AppTheme.primaryLiquid.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 14),

                // 4. Acordeón para métodos opcionales de cocción
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showApplianceFields = !_showApplianceFields);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _showApplianceFields
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tiempos / Electrodomésticos (opcional)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showApplianceFields) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _airfryerController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Airfryer (ej. 180°C durante 12 min)',
                      prefixIcon: const Icon(Icons.air_rounded, color: Color(0xFFF97316), size: 18),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ovenController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Horno (ej. 190°C durante 25 min)',
                      prefixIcon: const Icon(Icons.outdoor_grill_rounded, color: Color(0xFFEF4444), size: 18),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _microwaveController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Microondas (ej. 750W durante 3 min)',
                      prefixIcon: const Icon(Icons.microwave_rounded, color: Color(0xFF06B6D4), size: 18),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Botón Guardar
                AppButton(
                  text: 'Guardar Receta Casera',
                  icon: Icons.check_circle_rounded,
                  isLoading: _isSubmitting,
                  gradient: AppTheme.actionGradient,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
