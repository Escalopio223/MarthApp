import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/leisure_media_details.dart';
import '../controllers/leisure_controller.dart';
import 'leisure_detail_sheet.dart';

/// Diálogo modal con diseño Claymórfico que revela el título ganador elegido por el dado.
class LeisureDiceWinnerDialog extends StatelessWidget {
  final LeisureMediaDetails winner;
  final LeisureController controller;

  const LeisureDiceWinnerDialog({
    super.key,
    required this.winner,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required LeisureMediaDetails winner,
    required LeisureController controller,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LeisureDiceWinnerDialog(
        winner: winner,
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: AppCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera con animación de dado y celebración
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCoral.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.casino_rounded,
                    color: AppTheme.accentCoral,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡El dado ha elegido!',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ganador seleccionado al azar',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Tarjeta del Ítem Ganador
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accentCoral.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carátula / Póster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 80,
                      height: 116,
                      child: winner.posterUrl != null
                          ? Image.network(
                              winner.posterUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildFallbackPoster(),
                            )
                          : _buildFallbackPoster(),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Información del Ítem
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Etiqueta de Tipo de Medio
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLiquid.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            winner.mediaType.label.toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.primaryLiquid,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Título
                        Text(
                          winner.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // Año y Puntuación
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (winner.year != null && winner.year!.isNotEmpty) ...[
                              Text(
                                winner.year!,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (winner.rating != null && winner.rating! > 0) ...[
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                winner.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Sinopsis resumida
                        if (winner.overview != null &&
                            winner.overview!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            winner.overview!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Notificación de Limpieza Automática
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: AppTheme.accentEmerald,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Selección del dado limpiada automáticamente',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Acciones: Ver detalles y Cerrar
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    text: 'Ver ficha',
                    icon: Icons.open_in_new_rounded,
                    onPressed: () {
                      Navigator.pop(context); // Cierra diálogo
                      LeisureDetailSheet.show(
                        context,
                        media: winner,
                        controller: controller,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      color: AppTheme.surfaceDark,
      child: Center(
        child: Icon(
          Icons.movie_rounded,
          color: AppTheme.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}
