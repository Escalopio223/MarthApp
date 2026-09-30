import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../controllers/food_catalog_controller.dart';
import 'recipe_card.dart';
import 'recipe_detail_sheet.dart';

/// Vista agrupada para la gestión y consulta de favoritos rápidos:
/// 1. Recetas favoritas del entorno
/// 2. Ingredientes individuales recurrentes (para asignaciones directas de un tap en menús)
class QuickFavoritesView extends StatefulWidget {
  final FoodCatalogController controller;

  const QuickFavoritesView({
    super.key,
    required this.controller,
  });

  @override
  State<QuickFavoritesView> createState() => _QuickFavoritesViewState();
}

class _QuickFavoritesViewState extends State<QuickFavoritesView> {
  final _ingredientInputController = TextEditingController();

  // Sugerencias populares de un solo tap
  final List<String> _popularIngredientSuggestions = [
    'Yogur griego',
    'Avena en copos',
    'Pera conferencia',
    'Plátano',
    'Huevos camperos',
    'Aguacate',
    'Nueces',
    'Queso fresco batido',
    'Manzana',
    'Pechuga de pavo',
  ];

  @override
  void dispose() {
    _ingredientInputController.dispose();
    super.dispose();
  }

  void _handleAddIngredient(String raw) {
    final value = raw.trim();
    if (value.isNotEmpty) {
      widget.controller.addFavoriteIngredient(value);
      _ingredientInputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteRecipes = widget.controller.favoriteRecipes;
    final favoriteIngredients = widget.controller.favoriteIngredients;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -------------------------------------------------------------------
          // SECCIÓN 1: INGREDIENTES RECURRENTES RÁPIDOS
          // -------------------------------------------------------------------
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ingredientes Rápidos de 1-Tap',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Comodines para desayunos, meriendas o cenas ligeras',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Campo para añadir un nuevo ingrediente favorito
                TextField(
                  controller: _ingredientInputController,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Añadir ingrediente recurrente...',
                    prefixIcon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF10B981)),
                      onPressed: () => _handleAddIngredient(_ingredientInputController.text),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.cardBorderColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: _handleAddIngredient,
                ),

                const SizedBox(height: 12),

                // Chips de ingredientes favoritos ya guardados
                if (favoriteIngredients.isNotEmpty) ...[
                  Text(
                    'TUS FAVORITOS ACTIVOS (${favoriteIngredients.length})',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: favoriteIngredients.map((fav) {
                      final name = fav.displayName;
                      return Chip(
                        avatar: const CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                        ),
                        label: Text(
                          name,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        deleteIcon: const Icon(Icons.cancel_rounded, size: 16),
                        onDeleted: () {
                          HapticFeedback.lightImpact();
                          widget.controller.removeFavoriteIngredient(name);
                        },
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                        side: BorderSide(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Sugerencias populares rápidas
                Text(
                  'SUGERENCIAS POPULARES',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _popularIngredientSuggestions.map((sug) {
                    final isAlreadyFav = widget.controller.isIngredientFavorite(sug);
                    return ActionChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAlreadyFav ? Icons.check_rounded : Icons.add_rounded,
                            size: 13,
                            color: isAlreadyFav ? const Color(0xFF10B981) : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sug,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isAlreadyFav ? const Color(0xFF10B981) : AppTheme.textPrimary,
                              fontWeight: isAlreadyFav ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: isAlreadyFav
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.15),
                      side: BorderSide(
                        color: isAlreadyFav
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : AppTheme.cardBorderColor,
                        width: 0.8,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (isAlreadyFav) {
                          widget.controller.removeFavoriteIngredient(sug);
                        } else {
                          widget.controller.addFavoriteIngredient(sug);
                        }
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // SECCIÓN 2: RECETAS FAVORITAS DEL ENTORNO
          // -------------------------------------------------------------------
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 20),
              const SizedBox(width: 6),
              Text(
                'RECETAS FAVORITAS (${favoriteRecipes.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (favoriteRecipes.isEmpty) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    size: 44,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aún no has guardado recetas favoritas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Explora el catálogo y pulsa la estrella (★) en cualquier plato para tenerlo siempre a mano aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: favoriteRecipes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final fav = favoriteRecipes[index];
                final recipe = fav.recipe!;
                final isFav = widget.controller.isRecipeFavorite(recipe.id);

                return RecipeCard(
                  recipe: recipe,
                  isFavorite: isFav,
                  onTap: () {
                    RecipeDetailSheet.show(
                      context,
                      recipe: recipe,
                      isFavorite: isFav,
                      onToggleFavorite: () => widget.controller.toggleFavoriteRecipe(recipe),
                    );
                  },
                  onToggleFavorite: () => widget.controller.toggleFavoriteRecipe(recipe),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
