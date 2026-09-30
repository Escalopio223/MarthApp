import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../controllers/food_catalog_controller.dart';
import '../widgets/quick_favorites_view.dart';
import '../widgets/quick_recipe_modal.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_detail_sheet.dart';
import 'weekly_menu_planner_screen.dart';

/// Pantalla principal para explorar el catálogo de recetas y gestionar favoritos
class FoodCatalogScreen extends StatefulWidget {
  final FoodCatalogController? controller;
  final EnvironmentController? environmentController;
  final bool asTab;

  const FoodCatalogScreen({
    super.key,
    this.controller,
    this.environmentController,
    this.asTab = false,
  });

  @override
  State<FoodCatalogScreen> createState() => _FoodCatalogScreenState();
}

class _FoodCatalogScreenState extends State<FoodCatalogScreen> {
  late final FoodCatalogController _controller;
  late final TextEditingController _searchFieldController;

  final List<String> _cuisineFilterOptions = [
    'Todas',
    'Mediterránea',
    'Tradicional',
    'Italiana',
    'Asiática',
    'Mexicana',
    'Saludable',
    'Airfryer',
    'Desayunos',
    'Horno',
    'Repostería',
    'Rápida',
  ];

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FoodCatalogController();
    _searchFieldController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_onControllerUpdate);

    // Inicializar con el entorno activo si está disponible
    final envId = widget.environmentController?.activeEnvironment?.id ?? 'default-env';
    _controller.initialize(
      environmentId: envId,
      userId: widget.environmentController?.currentUserId ?? 'user',
    );

    widget.environmentController?.addListener(_onEnvironmentChanged);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onEnvironmentChanged() {
    final newEnvId = widget.environmentController?.activeEnvironment?.id;
    if (newEnvId != null && newEnvId != _controller.currentEnvironmentId) {
      _controller.setEnvironmentId(newEnvId);
    }
  }

  @override
  void dispose() {
    widget.environmentController?.removeListener(_onEnvironmentChanged);
    _controller.removeListener(_onControllerUpdate);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _searchFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // 1. Selector Superior de Vista: Catálogo vs Favoritos
        _buildSegmentedTabSelector(),

        // 2. Contenido según la pestaña activa
        Expanded(
          child: _controller.activeViewIndex == 0
              ? _buildCatalogView()
              : QuickFavoritesView(controller: _controller),
        ),
      ],
    );

    if (widget.asTab) {
      return content;
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppTheme.actionGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Cocina & Recetas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            // Botón de acceso al Planificador Semanal y Calendario
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded, size: 22),
              tooltip: 'Planificador Semanal',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WeeklyMenuPlannerScreen(
                      environmentController: widget.environmentController,
                    ),
                  ),
                );
              },
            ),
            // Botón de creación rápida (<20s)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
              tooltip: 'Nueva receta casera',
              onPressed: () => QuickRecipeModal.show(context, controller: _controller),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: content,
        floatingActionButton: _controller.activeViewIndex == 0
            ? FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryLiquid,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Crear receta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => QuickRecipeModal.show(context, controller: _controller),
              )
            : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SELECTOR SEGMENTADO (Catálogo vs Favoritos)
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedTabSelector() {
    final activeIndex = _controller.activeViewIndex;
    final favCount = _controller.favorites.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSegmentButton(
                index: 0,
                icon: Icons.explore_rounded,
                label: 'Explorar Catálogo',
                isSelected: activeIndex == 0,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildSegmentButton(
                index: 1,
                icon: Icons.star_rounded,
                label: 'Favoritos Rápidos',
                badgeCount: favCount,
                isSelected: activeIndex == 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
    required bool isSelected,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _controller.setActiveViewIndex(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceDark : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primaryLiquid.withValues(alpha: 0.5), width: 1.0)
              : null,
          boxShadow: isSelected ? AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFBBF24) : AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black87 : Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISTA EXPLORAR CATÁLOGO
  // ---------------------------------------------------------------------------
  Widget _buildCatalogView() {
    return Column(
      children: [
        // 1. Barra de Búsqueda con debounce
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchFieldController,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar recetas, países, ingredientes...',
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
              suffixIcon: _searchFieldController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchFieldController.clear();
                        _controller.clearSearch();
                      },
                    )
                  : (_controller.isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
            onChanged: _controller.onSearchQueryChanged,
          ),
        ),

        const SizedBox(height: 10),

        // 2. Filtros Horizontales (Electrodomésticos + Cocinas)
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Filtro Airfryer Toggle
              _buildFilterChip(
                label: 'Airfryer',
                icon: Icons.air_rounded,
                isSelected: _controller.filterAirfryer,
                activeColor: const Color(0xFFF97316),
                onTap: _controller.toggleAirfryerFilter,
              ),
              const SizedBox(width: 6),

              // Filtro Horno Toggle
              _buildFilterChip(
                label: 'Horno',
                icon: Icons.outdoor_grill_rounded,
                isSelected: _controller.filterOven,
                activeColor: const Color(0xFFEF4444),
                onTap: _controller.toggleOvenFilter,
              ),
              const SizedBox(width: 6),

              // Filtro Microondas Toggle
              _buildFilterChip(
                label: 'Microondas',
                icon: Icons.microwave_rounded,
                isSelected: _controller.filterMicrowave,
                activeColor: const Color(0xFF06B6D4),
                onTap: _controller.toggleMicrowaveFilter,
              ),
              const SizedBox(width: 8),

              // Divisor vertical sutil
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                width: 1,
                color: AppTheme.cardBorderColor,
              ),
              const SizedBox(width: 8),

              // Chips de tipos de cocina
              ..._cuisineFilterOptions.map((cuisine) {
                final isSelected = cuisine == 'Todas'
                    ? _controller.selectedCuisine == null
                    : _controller.selectedCuisine == cuisine;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildFilterChip(
                    label: cuisine,
                    isSelected: isSelected,
                    activeColor: AppTheme.primaryLiquid,
                    onTap: () {
                      _controller.selectCuisine(cuisine == 'Todas' ? null : cuisine);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3. Listado de Recetas o Estados
        Expanded(
          child: _buildRecipesListState(),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.cardBorderColor,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? activeColor : AppTheme.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesListState() {
    if (_controller.isLoading && _controller.recipes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_controller.errorMessage != null && _controller.recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 44, color: AppTheme.accentCoral),
              const SizedBox(height: 12),
              Text(
                _controller.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                onPressed: _controller.loadRecipes,
              ),
            ],
          ),
        ),
      );
    }

    final recipes = _controller.recipes;

    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              const Text(
                'No se encontraron recetas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Prueba a buscar con otro término o limpia los filtros activos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Restablecer filtros'),
                onPressed: () {
                  _searchFieldController.clear();
                  _controller.resetFilters();
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
      itemCount: recipes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final recipe = recipes[index];
        final isFav = _controller.isRecipeFavorite(recipe.id);

        return RecipeCard(
          recipe: recipe,
          isFavorite: isFav,
          onTap: () {
            RecipeDetailSheet.show(
              context,
              recipe: recipe,
              isFavorite: isFav,
              onToggleFavorite: () => _controller.toggleFavoriteRecipe(recipe),
            );
          },
          onToggleFavorite: () => _controller.toggleFavoriteRecipe(recipe),
        );
      },
    );
  }
}
