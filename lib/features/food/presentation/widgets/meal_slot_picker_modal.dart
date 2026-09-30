import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/models/food_favorite_model.dart';
import '../../domain/models/recipe_model.dart';
import '../../domain/repositories/i_food_repository.dart';
import '../../infrastructure/services/food_service.dart';

/// Resultado devuelto por el modal de selección de slot
sealed class SlotPickerResult {
  const SlotPickerResult();
}

class RecipeSlotResult extends SlotPickerResult {
  final RecipeModel recipe;
  const RecipeSlotResult(this.recipe);
}

class SingleIngredientSlotResult extends SlotPickerResult {
  final String name;
  const SingleIngredientSlotResult(this.name);
}

class ClearSlotResult extends SlotPickerResult {
  const ClearSlotResult();
}

/// Modal ergonómico para asignar recetas del catálogo, favoritos de 1-tap o alimentos libres a un slot semanal
class MealSlotPickerModal extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IFoodRepository repository;
  final String? environmentId;
  final List<FoodFavoriteModel> favorites;
  final bool hasExistingItem;

  const MealSlotPickerModal({
    super.key,
    required this.title,
    this.subtitle,
    required this.repository,
    this.environmentId,
    this.favorites = const [],
    this.hasExistingItem = false,
  });

  static Future<SlotPickerResult?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    IFoodRepository? repository,
    String? environmentId,
    List<FoodFavoriteModel> favorites = const [],
    bool hasExistingItem = false,
  }) {
    return showModalBottomSheet<SlotPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MealSlotPickerModal(
        title: title,
        subtitle: subtitle,
        repository: repository ?? FoodService(),
        environmentId: environmentId,
        favorites: favorites,
        hasExistingItem: hasExistingItem,
      ),
    );
  }

  @override
  State<MealSlotPickerModal> createState() => _MealSlotPickerModalState();
}

class _MealSlotPickerModalState extends State<MealSlotPickerModal> {
  int _activeTabIndex = 0; // 0: Favoritos, 1: Catálogo, 2: Alimento Suelto

  // Controlador de búsqueda en catálogo
  final TextEditingController _catalogSearchController = TextEditingController();
  Timer? _debounceTimer;
  List<RecipeModel> _catalogRecipes = [];
  bool _isLoadingCatalog = false;
  String _selectedCuisine = 'Todas';

  // Controlador de alimento suelto
  final TextEditingController _customFoodController = TextEditingController();

  final List<String> _quickFoodChips = [
    'Café y tostada',
    'Yogur con nueces',
    'Fruta fresca (Pera/Plátano)',
    'Bocadillo de jamón',
    'Ensalada mixta',
    'Batido de proteínas',
    'Tortilla francesa',
    'Frutos secos variados',
  ];

  final List<String> _cuisineChips = [
    'Todas',
    'Mediterránea',
    'Rápida',
    'Saludable',
    'Airfryer',
    'Italiana',
    'Tradicional',
  ];

  @override
  void initState() {
    super.initState();
    // Si no hay favoritos, abrimos directamente el catálogo
    if (widget.favorites.isEmpty) {
      _activeTabIndex = 1;
    }
    _loadCatalog();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _catalogSearchController.dispose();
    _customFoodController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadCatalog();
    });
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final recipes = await widget.repository.getRecipes(
        query: _catalogSearchController.text.trim().isEmpty ? null : _catalogSearchController.text.trim(),
        cuisineType: _selectedCuisine == 'Todas' ? null : _selectedCuisine,
        environmentId: widget.environmentId,
        limit: 30,
      );
      if (mounted) {
        setState(() {
          _catalogRecipes = recipes;
          _isLoadingCatalog = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
      }
    }
  }

  void _selectRecipe(RecipeModel recipe) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(RecipeSlotResult(recipe));
  }

  void _selectSingleIngredient(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(SingleIngredientSlotResult(clean));
  }

  void _clearSlot() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(const ClearSlotResult());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Segmented Tab Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      index: 0,
                      icon: Icons.star_rounded,
                      label: 'Favoritos',
                      badgeCount: widget.favorites.length,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabButton(
                      index: 1,
                      icon: Icons.menu_book_rounded,
                      label: 'Catálogo',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabButton(
                      index: 2,
                      icon: Icons.apple_rounded,
                      label: 'Suelto',
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: AppTheme.cardBorderColor),

          // Tab Content
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildTabContent(),
            ),
          ),

          // Footer: Vaciar ranura si ya tiene contenido
          if (widget.hasExistingItem) ...[
            Divider(height: 1, color: AppTheme.cardBorderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentCoral,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Vaciar este slot de comida',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: _clearSlot,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _activeTabIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLiquid.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppTheme.primaryLiquid.withValues(alpha: 0.5), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryLiquid : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildFavoritesTab();
      case 1:
        return _buildCatalogTab();
      case 2:
      default:
        return _buildCustomFoodTab();
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 1: FAVORITOS RÁPIDOS (1-tap)
  // ---------------------------------------------------------------------------
  Widget _buildFavoritesTab() {
    final favoriteRecipes = widget.favorites.where((f) => f.isRecipe && f.recipe != null).toList();
    final favoriteIngredients = widget.favorites.where((f) => f.isIngredient).toList();

    if (favoriteRecipes.isEmpty && favoriteIngredients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_border_rounded, size: 44, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(
                'Sin favoritos aún',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Marca recetas con estrella o añade ingredientes habituales en Favoritos para seleccionarlos con 1 tap.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLiquid,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.explore_rounded, size: 16),
                label: const Text('Explorar catálogo'),
                onPressed: () => setState(() => _activeTabIndex = 1),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (favoriteIngredients.isNotEmpty) ...[
          Text(
            'Ingredientes y Alimentos habituales (1 tap)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: favoriteIngredients.map((fav) {
              return ActionChip(
                backgroundColor: AppTheme.surfaceDark,
                side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                avatar: const Icon(Icons.apple_rounded, size: 14, color: Color(0xFFF97316)),
                label: Text(
                  fav.ingredientName ?? 'Alimento',
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                ),
                onPressed: () => _selectSingleIngredient(fav.ingredientName ?? ''),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        if (favoriteRecipes.isNotEmpty) ...[
          Text(
            'Recetas Favoritas (1 tap)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          ...favoriteRecipes.map((fav) {
            final recipe = fav.recipe!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _selectRecipe(recipe),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.restaurant_rounded, size: 20, color: AppTheme.primaryLiquid),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  recipe.cuisineType,
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                if (recipe.hasAirfryer) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.air_rounded, size: 12, color: Color(0xFF06B6D4)),
                                ],
                                if (recipe.hasOven) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFF97316)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryLiquid, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: CATÁLOGO DE RECETAS
  // ---------------------------------------------------------------------------
  Widget _buildCatalogTab() {
    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _catalogSearchController,
            onChanged: _onSearchChanged,
            style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar en el catálogo (ej. Pasta, Pollo, Ensalada)...',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
              suffixIcon: _catalogSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _catalogSearchController.clear();
                        _loadCatalog();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.2),
              ),
            ),
          ),
        ),

        // Filtro por cocina
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: _cuisineChips.map((c) {
              final isSel = _selectedCuisine == c;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? Colors.white : AppTheme.textSecondary,
                  ),
                  selected: isSel,
                  selectedColor: AppTheme.primaryLiquid,
                  backgroundColor: AppTheme.surfaceDark,
                  side: BorderSide(
                    color: isSel ? AppTheme.primaryLiquid : AppTheme.cardBorderColor,
                    width: 0.8,
                  ),
                  onSelected: (val) {
                    setState(() => _selectedCuisine = c);
                    _loadCatalog();
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Lista de recetas
        Expanded(
          child: _isLoadingCatalog
              ? Center(child: CircularProgressIndicator(color: AppTheme.primaryLiquid))
              : _catalogRecipes.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron recetas con ese filtro.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _catalogRecipes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final recipe = _catalogRecipes[index];
                        return InkWell(
                          onTap: () => _selectRecipe(recipe),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.restaurant_rounded, size: 20, color: AppTheme.primaryLiquid),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recipe.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            recipe.cuisineType,
                                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                          if (recipe.country.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '• ${recipe.country}',
                                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                          if (recipe.hasAirfryer) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.air_rounded, size: 12, color: Color(0xFF06B6D4)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryLiquid, size: 22),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: ALIMENTO SUELTO / TEXTO DIRECTO
  // ---------------------------------------------------------------------------
  Widget _buildCustomFoodTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alimento o Comida Rápida',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Escribe directamente lo que vas a comer sin necesidad de asociarlo a una receta.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          // Campo de texto
          TextField(
            controller: _customFoodController,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ej. Bocadillo de jamón, Pera, Ensalada verde...',
              hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              prefixIcon: Icon(Icons.edit_note_rounded, size: 22, color: AppTheme.primaryLiquid),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.2),
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                _selectSingleIngredient(val);
              }
            },
          ),

          const SizedBox(height: 16),
          Text(
            'Sugerencias habituales (1 tap):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickFoodChips.map((chipText) {
              return ActionChip(
                backgroundColor: AppTheme.surfaceDark,
                side: BorderSide(color: AppTheme.cardBorderColor, width: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                label: Text(
                  chipText,
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                ),
                onPressed: () => _selectSingleIngredient(chipText),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          AppButton(
            text: 'Asignar a este slot',
            icon: Icons.check_rounded,
            onPressed: () {
              if (_customFoodController.text.trim().isNotEmpty) {
                _selectSingleIngredient(_customFoodController.text);
              }
            },
          ),
        ],
      ),
    );
  }
}
