import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/recipe_model.dart';

/// Tarjeta visual ergonómica y claymórfica para recetas culinarias
class RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.isFavorite = false,
    this.onTap,
    this.onToggleFavorite,
  });

  IconData _resolveCuisineIcon(String cuisine) {
    final lower = cuisine.toLowerCase();
    if (lower.contains('italiana')) return Icons.local_pizza_rounded;
    if (lower.contains('asiática') || lower.contains('japón') || lower.contains('china')) {
      return Icons.ramen_dining_rounded;
    }
    if (lower.contains('mexicana')) return Icons.lunch_dining_rounded;
    if (lower.contains('saludable') || lower.contains('fitness')) return Icons.eco_rounded;
    if (lower.contains('airfryer')) return Icons.air_rounded;
    if (lower.contains('desayuno')) return Icons.bakery_dining_rounded;
    if (lower.contains('horno')) return Icons.outdoor_grill_rounded;
    if (lower.contains('repostería')) return Icons.cake_rounded;
    return Icons.restaurant_menu_rounded;
  }

  Color _resolveCuisineColor(String cuisine) {
    final lower = cuisine.toLowerCase();
    if (lower.contains('italiana')) return const Color(0xFF10B981);
    if (lower.contains('asiática')) return const Color(0xFFEF4444);
    if (lower.contains('mexicana')) return const Color(0xFFF59E0B);
    if (lower.contains('saludable')) return const Color(0xFF06B6D4);
    if (lower.contains('airfryer')) return const Color(0xFFF97316);
    if (lower.contains('desayuno')) return const Color(0xFFEAB308);
    return AppTheme.primaryLiquid;
  }

  @override
  Widget build(BuildContext context) {
    final cuisineColor = _resolveCuisineColor(recipe.cuisineType);
    final cuisineIcon = _resolveCuisineIcon(recipe.cuisineType);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Placeholder/Icono, Info y Botón Favorito
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono / Thumbnail con micro-gradiente
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cuisineColor.withValues(alpha: 0.3),
                      cuisineColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cuisineColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  cuisineIcon,
                  color: cuisineColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Título y País / Cocina
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            recipe.country,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cuisineColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' • ${recipe.cuisineType}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botón de estrella animado
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    key: ValueKey<bool>(isFavorite),
                    color: isFavorite ? const Color(0xFFFBBF24) : AppTheme.textSecondary,
                    size: 26,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onToggleFavorite?.call();
                },
                tooltip: isFavorite ? 'Quitar de favoritos' : 'Marcar como favorito',
                splashRadius: 20,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Badges de electrodomésticos y conteo de ingredientes
          Row(
            children: [
              // Badge Airfryer
              if (recipe.hasAirfryer) ...[
                _buildApplianceBadge(
                  icon: Icons.air_rounded,
                  label: 'Airfryer',
                  accentColor: const Color(0xFFF97316),
                ),
                const SizedBox(width: 6),
              ],

              // Badge Horno
              if (recipe.hasOven) ...[
                _buildApplianceBadge(
                  icon: Icons.outdoor_grill_rounded,
                  label: 'Horno',
                  accentColor: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
              ],

              // Badge Microondas
              if (recipe.hasMicrowave) ...[
                _buildApplianceBadge(
                  icon: Icons.microwave_rounded,
                  label: 'Micro',
                  accentColor: const Color(0xFF06B6D4),
                ),
                const SizedBox(width: 6),
              ],

              const Spacer(),

              // Contador de ingredientes si están cargados
              if (recipe.ingredients.isNotEmpty)
                Text(
                  '${recipe.ingredients.length} ing.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplianceBadge({
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accentColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
