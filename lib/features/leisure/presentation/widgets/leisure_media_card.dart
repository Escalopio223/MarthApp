import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/leisure_item_status.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_user_item_model.dart';

/// Tarjeta táctil Claymórfica para títulos multimedia:
/// - Imagen de portada con degradado inferior
/// - Insignia de rating y tipo
/// - Chip reactivo con el estado personal del usuario
/// - Botón táctil secundario para añadir/quitar de la Ruleta
class LeisureMediaCard extends StatelessWidget {
  final LeisureMediaDetails media;
  final LeisureUserItemModel? userItem;
  final bool isRouletteSelected;
  final VoidCallback onTap;
  final VoidCallback onRouletteToggle;

  const LeisureMediaCard({
    super.key,
    required this.media,
    this.userItem,
    required this.isRouletteSelected,
    required this.onTap,
    required this.onRouletteToggle,
  });

  Color _getStatusColor(LeisureItemStatus status) {
    switch (status) {
      case LeisureItemStatus.toWatch:
        return const Color(0xFF64B5F6); // Azul claro
      case LeisureItemStatus.watching:
        return const Color(0xFFFFB74D); // Naranja
      case LeisureItemStatus.watched:
        return const Color(0xFF81C784); // Verde
      case LeisureItemStatus.favorite:
        return const Color(0xFFFF4081); // Rosa intenso
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = userItem?.status;
    final rating = userItem?.rating ?? media.rating;

    return AppCard(
      borderRadius: 18.0,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sección Superior: Póster con overlay y badges
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Portada
                if (media.posterUrl != null)
                  Image.network(
                    media.posterUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPosterPlaceholder(),
                  )
                else
                  _buildPosterPlaceholder(),

                // Degradado cenital e inferior
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // Rating Badge (Top Left)
                if (rating != null && rating > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Botón Secundario de Ruleta (Top Right)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onRouletteToggle();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isRouletteSelected
                              ? AppTheme.accentCoral
                              : Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isRouletteSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: isRouletteSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.accentCoral
                                        .withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.casino_rounded,
                          size: 16,
                          color: isRouletteSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),

                // Estado personal del usuario (Bottom Left)
                if (status != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.label,
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
          ),

          // Sección Inferior: Información y Título
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (media.year != null)
                      Text(
                        media.year!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    if (media.creatorOrDirector != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '•',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          media.creatorOrDirector!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    IconData fallbackIcon;
    switch (media.mediaType.toValue()) {
      case 'movie':
        fallbackIcon = Icons.movie_outlined;
        break;
      case 'tv':
        fallbackIcon = Icons.tv_outlined;
        break;
      case 'book':
        fallbackIcon = Icons.auto_stories_outlined;
        break;
      case 'game':
        fallbackIcon = Icons.sports_esports_outlined;
        break;
      default:
        fallbackIcon = Icons.local_activity_outlined;
    }

    return Container(
      color: AppTheme.surfaceDark,
      child: Center(
        child: Icon(
          fallbackIcon,
          size: 40,
          color: AppTheme.textSecondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
