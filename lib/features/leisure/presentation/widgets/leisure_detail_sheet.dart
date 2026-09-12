import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_container.dart';
import '../../domain/models/book_edition_dto.dart';
import '../../domain/models/leisure_item_status.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';
import '../../domain/models/tv_season_details_dto.dart';
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

  @override
  void initState() {
    super.initState();
    _media = widget.initialMedia;
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
          _media = detailed;
        });
      }
    } catch (_) {}
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
              Text(
                'Guardar en lista del entorno',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (sharedLists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No hay listas en este entorno aún.',
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
    final isPersonal = widget.controller.isPersonalEnvironment;

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

                    // Fila de Proveedores de Streaming en España
                    if (_media.watchProviders.isNotEmpty) ...[
                      _buildStreamingProviders(),
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

                    // Acordeón 1: Reparto y Créditos
                    if (_media.castOrPlatforms.isNotEmpty) ...[
                      LeisureAccordion(
                        icon: Icons.people_alt_rounded,
                        title: _media.mediaType == LeisureMediaType.game
                            ? 'Plataformas y Compañías'
                            : 'Reparto Principal',
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

                    // Botón para Añadir a Lista Compartida del Entorno
                    const SizedBox(height: 10),
                    if (!isPersonal)
                      AppButton(
                        text: 'Guardar en lista del entorno',
                        icon: Icons.bookmark_add_rounded,
                        onPressed: _showAddToListDialog,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Para listas colaborativas, activa un entorno compartido en la cabecera.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                  if (_media.year != null) ...[
                    Text(
                      _media.year!,
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

  Widget _buildStreamingProviders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.live_tv_rounded,
                size: 18, color: AppTheme.primaryLiquid),
            const SizedBox(width: 6),
            Text(
              'Disponible en España (Suscripción)',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _media.watchProviders.map((provider) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: AppTheme.surfaceDark,
                        child: provider.logoPath.isNotEmpty
                            ? Image.network(
                                provider.logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    const Icon(Icons.play_circle_outline_rounded),
                              )
                            : const Icon(Icons.play_circle_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.providerName,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (edition.publishers.isNotEmpty)
                      Text(
                        edition.publishers.first,
                        style: TextStyle(
                          color: AppTheme.primaryLiquid,
                          fontSize: 11,
                        ),
                      ),
                    if (edition.publishDate != null) ...[
                      const SizedBox(width: 6),
                      Text('•',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(width: 6),
                      Text(
                        edition.publishDate!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (edition.isbn13 != null && edition.isbn13!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('•',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(width: 6),
                      Text(
                        'ISBN: ${edition.isbn13}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
