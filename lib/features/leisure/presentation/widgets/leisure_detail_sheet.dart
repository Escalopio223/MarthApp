import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_container.dart';
import '../../domain/models/book_edition_dto.dart';
import '../../domain/models/leisure_item_status.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';
import '../../domain/models/tv_season_details_dto.dart';
import '../../infrastructure/services/open_library_service.dart';
import '../controllers/leisure_controller.dart';
import 'leisure_accordion.dart';
import 'leisure_rating_slider.dart';

/// Modal detallado Claymórfico para inspeccionar y calificar un medio:
/// - Selector continuo de calificación 1.0 a 10.0 con háptica
/// - Acordeones colapsables para Reparto, Temporadas TV y Ediciones de libros
/// - Fila de proveedores de streaming en España
/// - Botón explícito para añadir/quitar de la Ruleta
/// - Integración con listas compartidas según el entorno activo
class LeisureDetailSheet extends StatefulWidget {
  final LeisureMediaDetails initialMedia;
  final LeisureController controller;

  const LeisureDetailSheet({
    super.key,
    required this.initialMedia,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required LeisureMediaDetails media,
    required LeisureController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeisureDetailSheet(
        initialMedia: media,
        controller: controller,
      ),
    );
  }

  @override
  State<LeisureDetailSheet> createState() => _LeisureDetailSheetState();
}

class _LeisureDetailSheetState extends State<LeisureDetailSheet> {
  late LeisureMediaDetails _media;

  // Estado para series TV
  int _selectedSeason = 1;
  TvSeasonDetailsDto? _seasonDetails;
  bool _isLoadingSeason = false;

  // Estado para libros
  List<BookEditionDto>? _bookEditions;
  bool _isLoadingEditions = false;

  // Estado para plataformas de streaming
  bool _isLoadingDetails = true;
  String _selectedRegion = 'ES';
  bool _isLoadingProviders = false;

  @override
  void initState() {
    super.initState();
    _media = widget.initialMedia;
    _selectedRegion = widget.controller.selectedRegion;
    _fetchFullDetails();
  }

  Future<void> _fetchFullDetails() async {
    try {
      final detailed = await widget.controller.getMediaDetails(
        _media.mediaId,
        _media.mediaType,
      );
      if (mounted) {
        setState(() {
          _media = detailed.copyWith(
            year: (detailed.year != null && detailed.year!.isNotEmpty)
                ? detailed.year
                : _media.year,
            releaseDate: (detailed.releaseDate != null && detailed.releaseDate!.isNotEmpty)
                ? detailed.releaseDate
                : _media.releaseDate,
            rating: detailed.rating ?? _media.rating,
            voteCount: detailed.voteCount ?? _media.voteCount,
            creatorOrDirector: detailed.creatorOrDirector ?? _media.creatorOrDirector,
            posterUrl: detailed.posterUrl ?? _media.posterUrl,
            isFreeToPlay: detailed.isFreeToPlay ?? _media.isFreeToPlay,
            gameStores: detailed.gameStores.isNotEmpty ? detailed.gameStores : _media.gameStores,
            gameDuration: detailed.gameDuration ?? _media.gameDuration,
          );
          _isLoadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _changeRegion(String newRegion) async {
    if (_selectedRegion == newRegion || _isLoadingProviders) return;
    setState(() {
      _selectedRegion = newRegion;
      _isLoadingProviders = true;
    });

    try {
      final providers = await widget.controller.getWatchProviders(
        _media.mediaId,
        _media.mediaType,
        region: newRegion,
      );
      if (mounted) {
        setState(() {
          _media = _media.copyWith(watchProviders: providers);
          _isLoadingProviders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProviders = false);
    }
  }

  Future<void> _loadSeasonDetails(int seasonNum) async {
    setState(() {
      _selectedSeason = seasonNum;
      _isLoadingSeason = true;
    });

    try {
      final details = await widget.controller.getTvSeasonDetails(
        _media.mediaId,
        seasonNum,
      );
      if (mounted) {
        setState(() {
          _seasonDetails = details;
          _isLoadingSeason = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSeason = false);
    }
  }

  Future<void> _loadBookEditions() async {
    if (_bookEditions != null || _isLoadingEditions) return;
    setState(() => _isLoadingEditions = true);
    try {
      final editions = await widget.controller.getBookEditions(_media.mediaId);
      if (mounted) {
        setState(() {
          _bookEditions = editions;
          _isLoadingEditions = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEditions = false);
    }
  }

  void _onStatusToggled(LeisureItemStatus targetStatus) {
    HapticFeedback.mediumImpact();
    final userItem = widget.controller.getUserItem(_media.mediaType, _media.mediaId);
    final isAlreadySame = userItem?.status == targetStatus;

    widget.controller.setUserItemStatus(
      media: _media,
      newStatus: isAlreadySame ? null : targetStatus,
    );
    setState(() {});
  }

  void _onRatingChanged(double? newRating) {
    widget.controller.updateRating(_media, newRating);
    setState(() {});
  }

  void _showQuickCreateListDialog(BuildContext parentCtx) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Nueva lista y guardar',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Título de la lista',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLiquid,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isCreating
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;
                          final messenger = ScaffoldMessenger.of(context);
                          setDlgState(() => isCreating = true);
                          try {
                            final list = await widget.controller.createSharedList(title, null);
                            await widget.controller.addMediaToSharedList(list.id, _media);
                            if (dlgCtx.mounted) {
                              Navigator.pop(dlgCtx);
                            }
                            if (parentCtx.mounted) {
                              Navigator.pop(parentCtx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Guardado en la nueva lista "${list.title}"'),
                                  backgroundColor: AppTheme.surfaceDark,
                                ),
                              );
                            }
                          } catch (e) {
                            if (dlgCtx.mounted) {
                              setDlgState(() => isCreating = false);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear y Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddToListDialog() {
    final sharedLists = widget.controller.sharedLists;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
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
                    'Guardar en lista del entorno',
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
              const SizedBox(height: 12),
              if (sharedLists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No hay listas creadas en este entorno todavía.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                ...sharedLists.map((list) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.bookmark_add_rounded,
                        color: AppTheme.primaryLiquid),
                    title: Text(list.title,
                        style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text('${list.itemsCount} elemento(s)',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await widget.controller
                          .addMediaToSharedList(list.id, _media);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Añadido a "${list.title}"'),
                            backgroundColor: AppTheme.surfaceDark,
                          ),
                        );
                      }
                    },
                  );
                }),
              const SizedBox(height: 8),
              AppButton(
                text: 'Crear nueva lista y guardar',
                icon: Icons.add_circle_outline_rounded,
                onPressed: () => _showQuickCreateListDialog(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userItem = widget.controller.getUserItem(_media.mediaType, _media.mediaId);
    final isRouletteSelected =
        widget.controller.isRouletteSelected(_media.mediaType, _media.mediaId);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.cardBorderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barra de arrastre superior
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Contenido Scrolleable
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                  children: [
                    // Fila de acciones superiores (Cerrar y Ruleta)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botón de Ruleta
                        AppContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          baseColor: isRouletteSelected
                              ? AppTheme.accentCoral
                              : AppTheme.surfaceDark,
                          onTap: () {
                            final added =
                                widget.controller.toggleRouletteItem(_media);
                            HapticFeedback.mediumImpact();
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(added
                                    ? 'Añadido a la ruleta'
                                    : 'Quitado de la ruleta'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppTheme.surfaceDark,
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.casino_rounded,
                                size: 18,
                                color: isRouletteSelected
                                    ? Colors.white
                                    : AppTheme.accentCoral,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRouletteSelected
                                    ? 'En la Ruleta'
                                    : 'Añadir a la ruleta',
                                style: TextStyle(
                                  color: isRouletteSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: AppTheme.textSecondary,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Portada + Título + Director + Géneros
                    _buildHeaderSection(),
                    const SizedBox(height: 20),

                    // Selector de Estado (4 vías)
                    _buildStatusSelector(userItem?.status),
                    const SizedBox(height: 16),

                    // Slider de Calificación (1.0 a 10.0 continuo)
                    LeisureRatingSlider(
                      initialRating: userItem?.rating,
                      onRatingChanged: _onRatingChanged,
                    ),
                    const SizedBox(height: 20),

                    // Sección de Disponibilidad en Streaming (Dónde Ver)
                    if (_media.mediaType == LeisureMediaType.movie ||
                        _media.mediaType == LeisureMediaType.tv) ...[
                      _buildStreamingProvidersSection(),
                      const SizedBox(height: 20),
                    ],

                    // Duración estimada y tiendas oficiales (Para Videojuegos)
                    if (_media.mediaType == LeisureMediaType.game) ...[
                      _buildGameDurationSection(),
                      _buildGameStoresSection(),
                      const SizedBox(height: 14),
                      _buildIgdbAttribution(),
                      const SizedBox(height: 20),
                    ],

                    // Sinopsis / Descripción
                    if (_media.overview != null && _media.overview!.isNotEmpty) ...[
                      Text(
                        'Sinopsis',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _media.overview!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Acordeón 1: Reparto (Para Películas y Series)
                    if (_media.mediaType != LeisureMediaType.game &&
                        _media.castOrPlatforms.isNotEmpty) ...[
                      LeisureAccordion(
                        icon: Icons.people_alt_rounded,
                        title: 'Reparto Principal',
                        badgeText: '${_media.castOrPlatforms.length}',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _media.castOrPlatforms.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppTheme.cardBorderColor),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Acordeón 2: Temporadas (Si es serie TV)
                    if (_media.mediaType == LeisureMediaType.tv) ...[
                      LeisureAccordion(
                        icon: Icons.video_library_rounded,
                        title: 'Temporadas y Episodios',
                        badgeText: _media.seasonsCount != null
                            ? '${_media.seasonsCount} temp.'
                            : null,
                        onExpansionChanged: () {
                          if (_seasonDetails == null) {
                            _loadSeasonDetails(1);
                          }
                        },
                        child: _buildTvSeasonsSection(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Acordeón 3: Ediciones (Si es Libro)
                    if (_media.mediaType == LeisureMediaType.book) ...[
                      LeisureAccordion(
                        icon: Icons.menu_book_rounded,
                        title: 'Ediciones Publicadas',
                        onExpansionChanged: _loadBookEditions,
                        child: _buildBookEditionsSection(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Botón para Añadir a Lista del Entorno (disponible en todos los entornos)
                    const SizedBox(height: 10),
                    AppButton(
                      text: 'Guardar en lista del entorno',
                      icon: Icons.bookmark_add_rounded,
                      onPressed: _showAddToListDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    final displayYear = _media.year != null
        ? (OpenLibraryService.extractYear(_media.year) ?? _media.year)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Póster
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 90,
            height: 130,
            color: AppTheme.surfaceDark,
            child: _media.posterUrl != null
                ? Image.network(_media.posterUrl!, fit: BoxFit.cover)
                : const Icon(Icons.movie_outlined, size: 36),
          ),
        ),
        const SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _media.title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (_media.creatorOrDirector != null)
                Text(
                  _media.creatorOrDirector!,
                  style: TextStyle(
                    color: AppTheme.primaryLiquid,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (displayYear != null) ...[
                    Text(
                      displayYear,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_media.rating != null && _media.rating! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            _media.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_media.mediaType == LeisureMediaType.game) ...[
                    if (_media.isF2p) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.accentEmerald.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.all_inclusive_rounded,
                                size: 12, color: AppTheme.accentEmerald),
                            const SizedBox(width: 3),
                            Text(
                              'Free to Play',
                              style: TextStyle(
                                color: AppTheme.accentEmerald,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_media.isFreeToPlay == false) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.cardBorderColor,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'De pago',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (_media.gameDuration?.mainStoryHours != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.primaryLiquid.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 12, color: AppTheme.primaryLiquid),
                            const SizedBox(width: 3),
                            Text(
                              '~${_media.gameDuration!.mainStoryHours}h',
                              style: TextStyle(
                                color: AppTheme.primaryLiquid,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Géneros
              if (_media.genres.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _media.genres.take(3).map((genre) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        genre,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameDurationSection() {
    final duration = _media.gameDuration;
    if (duration == null || !duration.hasAny) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 16, color: AppTheme.primaryLiquid),
            const SizedBox(width: 8),
            Text(
              'Duración estimada (Tiempo para pasárselo)',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (duration.mainStoryHours != null && duration.mainStoryHours! > 0)
              Expanded(
                child: _buildDurationCard(
                  label: 'Historia',
                  hours: duration.mainStoryHours!,
                  color: AppTheme.accentEmerald,
                  icon: Icons.flag_rounded,
                ),
              ),
            if (duration.mainExtraHours != null && duration.mainExtraHours! > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildDurationCard(
                  label: 'Historia + Extras',
                  hours: duration.mainExtraHours!,
                  color: AppTheme.primaryLiquid,
                  icon: Icons.explore_rounded,
                ),
              ),
            ],
            if (duration.completionistHours != null && duration.completionistHours! > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildDurationCard(
                  label: '100% Completista',
                  hours: duration.completionistHours!,
                  color: Colors.amber,
                  icon: Icons.emoji_events_rounded,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildDurationCard({
    required String label,
    required int hours,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            '$hours h',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStoresSection() {
    final stores = _media.gameStores;
    final isF2p = _media.isF2p;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isF2p ? Icons.all_inclusive_rounded : Icons.storefront_rounded,
              size: 16,
              color: isF2p ? AppTheme.accentEmerald : AppTheme.primaryLiquid,
            ),
            const SizedBox(width: 8),
            Text(
              isF2p
                  ? 'Consíguelo gratis en:'
                  : (stores.isNotEmpty ? 'Disponible en tiendas oficiales:' : 'Disponibilidad'),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (stores.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stores.map((store) {
              return InkWell(
                onTap: () async {
                  final uri = Uri.tryParse(store.url);
                  if (uri != null) {
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isF2p
                          ? AppTheme.accentEmerald.withValues(alpha: 0.3)
                          : AppTheme.cardBorderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStoreIcon(store.storeName),
                        size: 14,
                        color: _getStoreColor(store.storeName),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        store.storeName,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        if (stores.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(
                  isF2p ? Icons.all_inclusive_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: isF2p ? AppTheme.accentEmerald : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isF2p
                        ? 'Juego gratuito disponible en las plataformas y tiendas oficiales correspondientes.'
                        : 'Juego de pago disponible en las tiendas habituales de tus plataformas.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildIgdbAttribution() {
    return AppContainer(
      onTap: () async {
        HapticFeedback.lightImpact();
        final uri = Uri.parse('https://www.igdb.com');
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF9146FF),
                  Color(0xFF772CE8),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9146FF).withValues(alpha: 0.35),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_esports_rounded, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'IGDB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Powered by IGDB',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Datos de catálogo, carátulas y metadatos proporcionados por IGDB.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStoreIcon(String storeName) {
    final s = storeName.toLowerCase();
    if (s.contains('steam')) return Icons.sports_esports_rounded;
    if (s.contains('nintendo')) return Icons.videogame_asset_rounded;
    if (s.contains('playstation')) return Icons.gamepad_rounded;
    if (s.contains('xbox')) return Icons.gamepad_outlined;
    if (s.contains('epic')) return Icons.shopping_bag_outlined;
    if (s.contains('gog')) return Icons.album_rounded;
    if (s.contains('apple') || s.contains('app store')) return Icons.apple_rounded;
    if (s.contains('google') || s.contains('play')) return Icons.play_arrow_rounded;
    return Icons.storefront_rounded;
  }

  Color _getStoreColor(String storeName) {
    final s = storeName.toLowerCase();
    if (s.contains('steam')) return const Color(0xFF66C0F4);
    if (s.contains('nintendo')) return const Color(0xFFE60012);
    if (s.contains('playstation')) return const Color(0xFF0070D1);
    if (s.contains('xbox')) return const Color(0xFF107C10);
    if (s.contains('epic')) return Colors.white;
    if (s.contains('gog')) return const Color(0xFFC070F0);
    if (s.contains('apple')) return Colors.white;
    if (s.contains('google')) return const Color(0xFF00E676);
    return AppTheme.primaryLiquid;
  }

  Widget _buildStatusSelector(LeisureItemStatus? currentStatus) {
    return Row(
      children: LeisureItemStatus.values.map((status) {
        final isSelected = currentStatus == status;
        IconData icon;
        Color color;

        switch (status) {
          case LeisureItemStatus.toWatch:
            icon = Icons.bookmark_border_rounded;
            color = const Color(0xFF64B5F6);
            break;
          case LeisureItemStatus.watching:
            icon = Icons.play_arrow_rounded;
            color = const Color(0xFFFFB74D);
            break;
          case LeisureItemStatus.watched:
            icon = Icons.check_circle_outline_rounded;
            color = const Color(0xFF81C784);
            break;
          case LeisureItemStatus.favorite:
            icon = Icons.favorite_border_rounded;
            color = const Color(0xFFFF4081);
            break;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AppContainer(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(vertical: 8),
              baseColor: isSelected ? color : AppTheme.surfaceDark,
              onTap: () => _onStatusToggled(status),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStreamingProvidersSection() {
    final hasProviders = _media.watchProviders.isNotEmpty;
    final isLoading = _isLoadingDetails || _isLoadingProviders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.live_tv_rounded,
                    size: 18, color: AppTheme.primaryLiquid),
                const SizedBox(width: 8),
                Text(
                  'Dónde Ver',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Selector de Región (España, EE.UU., México, etc.)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRegionChip('ES', '🇪🇸 ES'),
                const SizedBox(width: 4),
                _buildRegionChip('US', '🇺🇸 US'),
                const SizedBox(width: 4),
                _buildRegionChip('MX', '🇲🇽 MX'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorderColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryLiquid,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Consultando plataformas de streaming...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else if (!hasProviders)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorderColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tv_off_rounded,
                  size: 20,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No disponible en suscripción en $_selectedRegion actualmente. Prueba seleccionando otra región arriba.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _media.watchProviders.map((provider) {
                final hasLink = provider.watchLink != null &&
                    provider.watchLink!.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: hasLink
                        ? () async {
                            HapticFeedback.lightImpact();
                            final uri = Uri.parse(provider.watchLink!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.cardBorderColor.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              color: Colors.black26,
                              child: provider.logoPath.isNotEmpty
                                  ? Image.network(
                                      provider.logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.play_circle_outline_rounded,
                                        size: 20,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: 20,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                provider.providerName,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                provider.typeLabel,
                                style: TextStyle(
                                  color: AppTheme.primaryLiquid,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (hasLink) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 13,
                              color: AppTheme.textSecondary.withValues(alpha: 0.8),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRegionChip(String code, String label) {
    final isSelected = _selectedRegion == code;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _changeRegion(code);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLiquid.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryLiquid
                : AppTheme.cardBorderColor.withValues(alpha: 0.5),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTvSeasonsSection() {
    final seasonsCount = _media.seasonsCount ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selector de número de temporada
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(seasonsCount, (index) {
              final seasonNum = index + 1;
              final isCurrent = seasonNum == _selectedSeason;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Temporada $seasonNum'),
                  selected: isCurrent,
                  selectedColor: AppTheme.primaryLiquid,
                  backgroundColor: AppTheme.surfaceDark,
                  labelStyle: TextStyle(
                    color: isCurrent ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) _loadSeasonDetails(seasonNum);
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // Lista de episodios
        if (_isLoadingSeason)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_seasonDetails == null || _seasonDetails!.episodes.isEmpty)
          Text(
            'No hay episodios registrados para esta temporada.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          )
        else
          ..._seasonDetails!.episodes.map((ep) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'E${ep.episodeNumber}',
                        style: TextStyle(
                          color: AppTheme.primaryLiquid,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ep.name,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ep.overview != null && ep.overview!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              ep.overview!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
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

  Widget _buildBookEditionsSection() {
    if (_isLoadingEditions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_bookEditions == null || _bookEditions!.isEmpty) {
      return Text(
        'No se encontraron ediciones adicionales para esta obra.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _bookEditions!.take(6).map((edition) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edition.title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    if (edition.publishers.isNotEmpty)
                      Text(
                        edition.publishers.first,
                        style: TextStyle(
                          color: AppTheme.primaryLiquid,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (edition.publishDate != null && edition.publishDate!.isNotEmpty) ...[
                      if (edition.publishers.isNotEmpty)
                        Text('•',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      Text(
                        edition.publishDate!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if ((edition.isbn13 != null && edition.isbn13!.isNotEmpty) ||
                    (edition.isbn10 != null && edition.isbn10!.isNotEmpty)) ...[
                  const SizedBox(height: 3),
                  Text(
                    'ISBN: ${edition.isbn13 ?? edition.isbn10}',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.85),
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                    softWrap: true,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
