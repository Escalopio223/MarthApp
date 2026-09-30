import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/food_category_model.dart';
import '../../domain/models/recipe_model.dart';

/// Modal interactivo para visualizar los detalles completos de una receta:
/// - Listado de ingredientes limpios con el icono y color de su categoría
/// - Pestañas dedicadas para instrucciones de Horno, Airfryer y Microondas
class RecipeDetailSheet extends StatefulWidget {
  final RecipeModel recipe;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const RecipeDetailSheet({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  static Future<void> show(
    BuildContext context, {
    required RecipeModel recipe,
    required bool isFavorite,
    required VoidCallback onToggleFavorite,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecipeDetailSheet(
        recipe: recipe,
        isFavorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
      ),
    );
  }

  @override
  State<RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends State<RecipeDetailSheet> with SingleTickerProviderStateMixin {
  late final List<String> _availableTabs;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _availableTabs = ['Ingredientes'];
    if (widget.recipe.hasAirfryer) _availableTabs.add('Airfryer');
    if (widget.recipe.hasOven) _availableTabs.add('Horno');
    if (widget.recipe.hasMicrowave) _availableTabs.add('Microondas');

    // Si no tiene ningún método explícito de electrodoméstico pero tiene notas, agregamos Preparación
    if (_availableTabs.length == 1) {
      _availableTabs.add('Preparación');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.0),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de arrastre superior
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Cabecera con Título, País y botón de Favorito
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recipe.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildHeaderBadge(
                            icon: Icons.public_rounded,
                            label: widget.recipe.country,
                            color: AppTheme.primaryLiquid,
                          ),
                          _buildHeaderBadge(
                            icon: Icons.restaurant_rounded,
                            label: widget.recipe.cuisineType,
                            color: AppTheme.secondaryAccent,
                          ),
                          if (!widget.recipe.isGlobal)
                            _buildHeaderBadge(
                              icon: Icons.home_rounded,
                              label: 'Receta casera',
                              color: const Color(0xFF10B981),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: widget.isFavorite ? const Color(0xFFFBBF24) : AppTheme.textSecondary,
                    size: 28,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onToggleFavorite();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // Selector de Pestañas (Ingredientes / Airfryer / Horno / Microondas)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_availableTabs.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  final title = _availableTabs[index];
                  final icon = _getTabIcon(title);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTabIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryLiquid.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryLiquid : AppTheme.cardBorderColor,
                            width: isSelected ? 1.4 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
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

          // Contenido de la pestaña activa
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTabIcon(String tabName) {
    switch (tabName) {
      case 'Ingredientes':
        return Icons.shopping_basket_rounded;
      case 'Airfryer':
        return Icons.air_rounded;
      case 'Horno':
        return Icons.outdoor_grill_rounded;
      case 'Microondas':
        return Icons.microwave_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  Widget _buildHeaderBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final activeTab = _availableTabs[_selectedTabIndex];

    if (activeTab == 'Ingredientes') {
      return _buildIngredientsList();
    } else if (activeTab == 'Airfryer') {
      return _buildPreparationBlock(
        applianceName: 'Freidora de Aire (Airfryer)',
        instructions: widget.recipe.prepAirfryer ?? 'No se especificaron instrucciones particulares para freidora de aire.',
        accentColor: const Color(0xFFF97316),
        icon: Icons.air_rounded,
      );
    } else if (activeTab == 'Horno') {
      return _buildPreparationBlock(
        applianceName: 'Horno Convencional',
        instructions: widget.recipe.prepOven ?? 'No se especificaron instrucciones particulares para horno.',
        accentColor: const Color(0xFFEF4444),
        icon: Icons.outdoor_grill_rounded,
      );
    } else if (activeTab == 'Microondas') {
      return _buildPreparationBlock(
        applianceName: 'Microondas',
        instructions: widget.recipe.prepMicrowave ?? 'No se especificaron instrucciones particulares para microondas.',
        accentColor: const Color(0xFF06B6D4),
        icon: Icons.microwave_rounded,
      );
    } else {
      return _buildPreparationBlock(
        applianceName: 'Preparación Tradicional',
        instructions: 'Cocinar los ingredientes integrando según la receta.',
        accentColor: AppTheme.primaryLiquid,
        icon: Icons.soup_kitchen_rounded,
      );
    }
  }

  Widget _buildIngredientsList() {
    final ingredients = widget.recipe.ingredients;

    if (ingredients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(
                'No se han registrado ingredientes detallados para esta receta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${ingredients.length} INGREDIENTES NECESARIOS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...ingredients.map((ing) {
          final category = ing.category;
          final iconSlug = category?.iconSlug ?? FoodCategorySlug.vegetable;
          final catColor = iconSlug.color;
          final catIcon = iconSlug.iconData;
          final catName = category?.name ?? iconSlug.displayName;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: catColor.withValues(alpha: 0.35), width: 1.0),
                    ),
                    child: Icon(catIcon, color: catColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ing.name[0].toUpperCase() + ing.name.substring(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          catName,
                          style: TextStyle(
                            fontSize: 11,
                            color: catColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPreparationBlock({
    required String applianceName,
    required String instructions,
    required Color accentColor,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applianceName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      'Instrucciones y parámetros de cocción específicos',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            instructions,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
