import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../../core/widgets/marth_app_logo.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../domain/models/leisure_media_details.dart';
import '../controllers/leisure_controller.dart';
import '../widgets/leisure_detail_sheet.dart';
import '../widgets/leisure_media_card.dart';
import '../widgets/leisure_media_type_selector.dart';
import '../widgets/leisure_shared_lists_sheet.dart';

/// Pantalla principal interactiva del módulo de Ocio (Leisure):
/// - Búsqueda en tiempo real con debounce
/// - Filtros por tipo de medio (Películas, Series, Libros, Videojuegos)
/// - Sub-pestañas: Explorar Catálogo vs Mis Guardados
/// - Indicadores visuales de ruleta y listas compartidas de entorno
class LeisureScreen extends StatefulWidget {
  final LeisureController controller;
  final EnvironmentController? environmentController;

  const LeisureScreen({
    super.key,
    required this.controller,
    this.environmentController,
  });

  @override
  State<LeisureScreen> createState() => _LeisureScreenState();
}

class _LeisureScreenState extends State<LeisureScreen> {
  final _searchFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    widget.environmentController?.addListener(_onEnvironmentChange);
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _onEnvironmentChange() {
    final env = widget.environmentController?.activeEnvironment;
    final isPersonal = env?.isPersonal ?? true;
    widget.controller.setEnvironment(env?.id, isPersonal: isPersonal);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    widget.environmentController?.removeListener(_onEnvironmentChange);
    _searchFieldController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchFieldController.clear();
    widget.controller.clearSearch();
  }

  void _showRouletteNotice(BuildContext context) {
    final count = widget.controller.rouletteCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? '$count título(s) listos para la Ruleta'
              : 'Selecciona títulos tocando el icono de dado/ruleta para jugar.',
        ),
        backgroundColor: AppTheme.surfaceDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isSearching = controller.searchQuery.isNotEmpty;
    final displayItems = isSearching
        ? controller.searchResults
        : (controller.selectedSubFilter == 0
            ? controller.catalogItems
            : _filterUserSavedItems());

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppTheme.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            MarthAppLogo.badge(badgeSize: 32, logoSize: 18),
            const SizedBox(width: 8),
            Text(
              'Ocio & Cultura',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Botón indicador de ruleta
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Ruleta de Ocio',
                icon: const Icon(Icons.casino_rounded),
                color: controller.rouletteCount > 0
                    ? AppTheme.accentCoral
                    : AppTheme.textSecondary,
                onPressed: () => _showRouletteNotice(context),
              ),
              if (controller.rouletteCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCoral,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${controller.rouletteCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Botón de Listas del Entorno
          IconButton(
            tooltip: 'Listas del entorno',
            icon: const Icon(Icons.playlist_play_rounded),
            color: AppTheme.textPrimary,
            onPressed: () =>
                LeisureSharedListsSheet.show(context, controller: controller),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Barra de búsqueda con Debounce (400ms)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AppContainer(
                  borderRadius: 16.0,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  baseColor: AppTheme.surfaceDark,
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          color: AppTheme.textSecondary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchFieldController,
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText:
                                'Buscar ${controller.selectedType.label.toLowerCase()}...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) =>
                              controller.onSearchQueryChanged(val),
                        ),
                      ),
                      if (controller.searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: AppTheme.textSecondary,
                          onPressed: _clearSearch,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Selector de Tipo de Medio (Películas, Series, Libros, Videojuegos)
              LeisureMediaTypeSelector(
                selectedType: controller.selectedType,
                onTypeChanged: (type) {
                  _searchFieldController.clear();
                  controller.setMediaType(type);
                },
              ),
              const SizedBox(height: 12),

              // Sub-pestañas: Catálogo vs Mis Guardados (oculto durante búsqueda)
              if (!isSearching) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildSubTab(
                        title: 'Explorar Catálogo',
                        isSelected: controller.selectedSubFilter == 0,
                        onTap: () => controller.setSubFilter(0),
                      ),
                      const SizedBox(width: 10),
                      _buildSubTab(
                        title: 'Mis Guardados',
                        isSelected: controller.selectedSubFilter == 1,
                        onTap: () => controller.setSubFilter(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Contenido Principal: Grid de Medios con Pull-to-Refresh
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primaryLiquid,
                  backgroundColor: AppTheme.surfaceDark,
                  onRefresh: () async {
                    if (isSearching) {
                      controller.onSearchQueryChanged(controller.searchQuery);
                    } else {
                      await controller.loadCatalog();
                      await controller.loadUserItems();
                    }
                  },
                  child: _buildMediaGrid(displayItems),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLiquid.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryLiquid
                : AppTheme.cardBorderColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaGrid(List<LeisureMediaDetails> items) {
    final controller = widget.controller;

    if (controller.isLoading || controller.isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 40, color: AppTheme.accentCoral),
              const SizedBox(height: 12),
              Text(
                controller.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLiquid),
                onPressed: () => controller.loadCatalog(),
                child: const Text('Reintentar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              Text(
                controller.searchQuery.isNotEmpty
                    ? 'No se encontraron resultados para "${controller.searchQuery}"'
                    : 'No hay títulos para mostrar en este momento.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Grid responsivo según el ancho disponible
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 650) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 450) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final media = items[index];
            final userItem =
                controller.getUserItem(media.mediaType, media.mediaId);
            final isRoulette =
                controller.isRouletteSelected(media.mediaType, media.mediaId);

            return LeisureMediaCard(
              media: media,
              userItem: userItem,
              isRouletteSelected: isRoulette,
              onTap: () {
                LeisureDetailSheet.show(
                  context,
                  media: media,
                  controller: controller,
                );
              },
              onRouletteToggle: () {
                controller.toggleRouletteItem(media);
              },
            );
          },
        );
      },
    );
  }

  List<LeisureMediaDetails> _filterUserSavedItems() {
    final controller = widget.controller;
    return controller.catalogItems.where((media) {
      final item = controller.getUserItem(media.mediaType, media.mediaId);
      return item != null && item.status != null;
    }).toList();
  }
}
