import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/leisure_list_sort_option.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';
import '../../domain/models/leisure_shared_list_item_model.dart';
import '../../domain/models/leisure_shared_list_model.dart';
import '../controllers/leisure_controller.dart';
import 'leisure_detail_sheet.dart';

/// Hoja interactiva para gestionar y explorar las listas y matches del entorno activo
class LeisureSharedListsSheet extends StatefulWidget {
  final LeisureController controller;

  const LeisureSharedListsSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context, {
    required LeisureController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeisureSharedListsSheet(controller: controller),
    );
  }

  @override
  State<LeisureSharedListsSheet> createState() =>
      _LeisureSharedListsSheetState();
}

class _LeisureSharedListsSheetState extends State<LeisureSharedListsSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final Set<String> _expandedListIds = {};
  final Set<String> _loadingListIds = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    widget.controller.loadSharedLists();
    if (!widget.controller.isPersonalEnvironment) {
      widget.controller.loadEnvironmentMatches();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleCreateList() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      await widget.controller.createSharedList(
        title,
        _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
      );
      _titleController.clear();
      _descController.clear();
      if (mounted) {
        Navigator.pop(context); // Cierra diálogo
        setState(() => _isCreating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear lista: $e'),
            backgroundColor: AppTheme.surfaceDark,
          ),
        );
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Nueva lista del entorno',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Título de la lista (ej. Películas del finde)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Descripción opcional',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLiquid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isCreating ? null : _handleCreateList,
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleListExpansion(String listId) async {
    final willExpand = !_expandedListIds.contains(listId);
    setState(() {
      if (willExpand) {
        _expandedListIds.add(listId);
        if (!widget.controller.hasCachedListItems(listId)) {
          _loadingListIds.add(listId);
        }
      } else {
        _expandedListIds.remove(listId);
      }
    });

    if (willExpand && !widget.controller.hasCachedListItems(listId)) {
      try {
        await widget.controller.getSharedListItems(listId);
      } finally {
        if (mounted) {
          setState(() {
            _loadingListIds.remove(listId);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharedLists = widget.controller.sharedLists;
    final matches = widget.controller.environmentMatches;
    final hasNoEnvironment = widget.controller.currentEnvironmentId == null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.cardBorderColor, width: 1),
          ),
          child: Column(
            children: [
              // Barra de arrastre
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Título y botón cerrar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Listas del Entorno',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.textSecondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Contenido
              Expanded(
                child: hasNoEnvironment
                    ? _buildNoEnvironmentNotice()
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Botón para crear nueva lista
                          AppButton(
                            text: 'Crear nueva lista',
                            icon: Icons.add_circle_outline_rounded,
                            onPressed: _showCreateDialog,
                          ),
                          const SizedBox(height: 20),

                          // Sección Matches de Gustos (si existen en entornos colaborativos)
                          if (matches.isNotEmpty) ...[
                            Text(
                              'Coincidencias (Watch Party)',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...matches.map((match) {
                              return AppCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite_rounded,
                                      color: Color(0xFFFF4081),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            match.title,
                                            style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${match.matchedUserIds.length} miembros coinciden',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // Listas del Entorno
                          Text(
                            'Listas (${sharedLists.length})',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (sharedLists.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  'Aún no hay listas en este entorno.\n¡Crea una para organizar lo que quieres ver o jugar!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...sharedLists.map((list) => _buildListItem(list)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoEnvironmentNotice() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.layers_clear_rounded,
                  size: 36,
                  color: AppTheme.primaryLiquid,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona un Entorno',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para ver y guardar listas, selecciona un espacio concreto (como Mi espacio o un entorno compartido) desde el selector superior.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(LeisureSharedListModel list) {
    final isExpanded = _expandedListIds.contains(list.id);
    final isLoadingItems = _loadingListIds.contains(list.id);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera interactiva de la lista
          InkWell(
            onTap: () => _toggleListExpansion(list.id),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.playlist_play_rounded,
                    color: AppTheme.primaryLiquid,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (list.description != null &&
                          list.description!.isNotEmpty)
                        Text(
                          list.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        '${list.itemsCount} elemento(s)',
                        style: TextStyle(
                          color: AppTheme.primaryLiquid,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),

          // Despliegue de los elementos dentro de la lista
          if (isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            if (isLoadingItems)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _buildExpandedItems(list.id),
          ],
        ],
      ),
    );
  }

  void _showSortOptionsDialog(String listId) {
    final currentSort = widget.controller.getListSortOption(listId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.cardBorderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ordenar lista por',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppTheme.textSecondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...LeisureListSortOption.values.map((opt) {
                final isSelected = opt == currentSort;
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: isSelected
                      ? AppTheme.primaryLiquid.withValues(alpha: 0.15)
                      : Colors.transparent,
                  leading: Icon(
                    opt.icon,
                    color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryLiquid : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: AppTheme.primaryLiquid, size: 18)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.controller.setListSortOption(listId, opt);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedItems(String listId) {
    final allItems = widget.controller.getCachedListItems(listId);

    if (allItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No hay elementos guardados en esta lista todavía.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final items = widget.controller.getFilteredAndSortedItems(listId);
    final currentSort = widget.controller.getListSortOption(listId);
    final selectedGenre = widget.controller.getListGenreFilter(listId);
    final availableGenres = widget.controller.getAvailableGenresForList(listId);
    final currentSearch = widget.controller.getListSearchQuery(listId);
    final hasGames = widget.controller.hasGamesInList(listId);
    final isF2pSelected = widget.controller.getListF2pFilter(listId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de Ordenación + Buscador rápido
        Row(
          children: [
            // Botón de Ordenación
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showSortOptionsDialog(listId),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: currentSort == LeisureListSortOption.manual
                          ? AppTheme.cardBorderColor
                          : AppTheme.primaryLiquid.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentSort.icon,
                        size: 14,
                        color: currentSort == LeisureListSortOption.manual
                            ? AppTheme.textSecondary
                            : AppTheme.primaryLiquid,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentSort.label,
                        style: TextStyle(
                          color: currentSort == LeisureListSortOption.manual
                              ? AppTheme.textSecondary
                              : AppTheme.primaryLiquid,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded,
                          size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Buscador rápido dentro de la lista
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorderColor),
                ),
                child: TextField(
                  onChanged: (val) => widget.controller.setListSearchQuery(listId, val),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Buscar en la lista...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    prefixIcon: Icon(Icons.search_rounded, size: 14, color: AppTheme.textSecondary),
                    suffixIcon: currentSearch.isNotEmpty
                        ? GestureDetector(
                            onTap: () => widget.controller.setListSearchQuery(listId, ''),
                            child: Icon(Icons.close_rounded, size: 14, color: AppTheme.textSecondary),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 7),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Filtro horizontal por géneros y F2P
        if (availableGenres.isNotEmpty || hasGames) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('Todos (${allItems.length})'),
                    selected: selectedGenre == null && !isF2pSelected,
                    selectedColor: AppTheme.primaryLiquid,
                    backgroundColor: AppTheme.surfaceDark,
                    labelStyle: TextStyle(
                      color: (selectedGenre == null && !isF2pSelected)
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: (selectedGenre == null && !isF2pSelected)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      widget.controller.setListGenreFilter(listId, null);
                      widget.controller.setListF2pFilter(listId, false);
                    },
                  ),
                ),
                if (hasGames)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(
                        Icons.sports_esports_rounded,
                        size: 13,
                        color: isF2pSelected ? Colors.white : AppTheme.accentEmerald,
                      ),
                      label: const Text('Free to Play (F2P)'),
                      selected: isF2pSelected,
                      selectedColor: AppTheme.accentEmerald,
                      backgroundColor: AppTheme.surfaceDark,
                      labelStyle: TextStyle(
                        color: isF2pSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: isF2pSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onSelected: (sel) {
                        widget.controller.setListF2pFilter(listId, sel);
                      },
                    ),
                  ),
                ...availableGenres.map((g) {
                  final isSelected = selectedGenre?.toLowerCase() == g.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(g),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryLiquid,
                      backgroundColor: AppTheme.surfaceDark,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onSelected: (sel) {
                        widget.controller.setListGenreFilter(listId, sel ? g : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // Información de elementos filtrados
        if (selectedGenre != null || currentSearch.isNotEmpty || isF2pSelected) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mostrando ${items.length} de ${allItems.length} elemento(s)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
              GestureDetector(
                onTap: () {
                  widget.controller.clearListFilters(listId);
                },
                child: Text(
                  'Limpiar filtros',
                  style: TextStyle(
                    color: AppTheme.primaryLiquid,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),

        // Listado de ítems (ReorderableListView para orden manual, Column para orden por criterio)
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No hay elementos que coincidan con los filtros.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          )
        else if (currentSort == LeisureListSortOption.manual && selectedGenre == null && currentSearch.isEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            // ignore: deprecated_member_use
            onReorder: (oldIdx, newIdx) {
              widget.controller.reorderSharedListItems(listId, oldIdx, newIdx);
            },
            itemBuilder: (ctx, index) {
              final item = items[index];
              return _buildItemRow(
                item,
                listId,
                index: index,
                isManualSort: true,
                key: ValueKey(item.id),
              );
            },
          )
        else
          Column(
            children: items.map((item) {
              return _buildItemRow(
                item,
                listId,
                index: null,
                isManualSort: false,
                key: ValueKey(item.id),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildItemRow(
    LeisureSharedListItemModel item,
    String listId, {
    int? index,
    required bool isManualSort,
    required Key key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Drag handle a la izquierda si es modo manual
          if (isManualSort && index != null) ...[
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],

          // Miniatura
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 38,
              height: 52,
              child: item.posterUrl != null
                  ? Image.network(
                      item.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _buildMiniFallback(item.mediaType),
                    )
                  : _buildMiniFallback(item.mediaType),
            ),
          ),
          const SizedBox(width: 12),

          // Título, Año, Categoría, Rating y Géneros
          Expanded(
            child: InkWell(
              onTap: () {
                final media = LeisureMediaDetails(
                  mediaId: item.mediaId,
                  mediaType: item.mediaType,
                  title: item.title,
                  posterUrl: item.posterUrl,
                  year: item.year,
                  rating: item.rating,
                  genres: item.genres,
                  isFreeToPlay: item.isF2p,
                );
                LeisureDetailSheet.show(
                  context,
                  media: media,
                  controller: widget.controller,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        item.mediaType.label,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (item.year != null && item.year!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text('•',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10)),
                        const SizedBox(width: 4),
                        Text(
                          item.year!,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (item.rating != null && item.rating! > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 11, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                item.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (item.isF2p) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentEmerald.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.accentEmerald.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded,
                                  size: 10, color: AppTheme.accentEmerald),
                              const SizedBox(width: 2),
                              Text(
                                'F2P',
                                style: TextStyle(
                                  color: AppTheme.accentEmerald,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.genres.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: item.genres.take(2).map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            g,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Botón eliminar de la lista
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppTheme.textSecondary,
            tooltip: 'Quitar de la lista',
            onPressed: () async {
              await widget.controller.removeMediaFromSharedList(
                item.id,
                listId,
              );
              if (mounted) {
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniFallback(LeisureMediaType type) {
    IconData icon;
    switch (type) {
      case LeisureMediaType.movie:
        icon = Icons.movie_rounded;
        break;
      case LeisureMediaType.tv:
        icon = Icons.tv_rounded;
        break;
      case LeisureMediaType.book:
        icon = Icons.book_rounded;
        break;
      case LeisureMediaType.game:
        icon = Icons.sports_esports_rounded;
        break;
    }
    return Container(
      color: AppTheme.surfaceDark,
      child: Center(child: Icon(icon, color: AppTheme.textSecondary, size: 18)),
    );
  }
}
