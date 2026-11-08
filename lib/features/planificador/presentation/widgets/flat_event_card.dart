import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/evento_model.dart';

/// Tarjeta plana compacta para eventos y citas del día (Flat Design 2.0).
/// Presenta fondo pastel sutil (10-15% opacidad), borde de 1px y tipografía nítida.
class FlatEventCard extends StatelessWidget {
  final EventoModel evento;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const FlatEventCard({
    super.key,
    required this.evento,
    this.onTap,
    this.onDelete,
  });

  String _formatTime() {
    if (evento.esTodoElDia || evento.esCumpleanos) {
      return evento.esCumpleanos ? 'Cumpleaños' : 'Todo el día';
    }
    final hora = evento.fechaInicio.hour.toString().padLeft(2, '0');
    final min = evento.fechaInicio.minute.toString().padLeft(2, '0');
    if (evento.fechaFin != null) {
      final finH = evento.fechaFin!.hour.toString().padLeft(2, '0');
      final finM = evento.fechaFin!.minute.toString().padLeft(2, '0');
      return '$hora:$min - $finH:$finM';
    }
    return '$hora:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isBirthday = evento.esCumpleanos;
    final accentColor = isBirthday ? AppTheme.accentCoral : AppTheme.primaryAccent;
    final timeStr = _formatTime();

    final subtitle = isBirthday
        ? (evento.ideasRegalo != null && evento.ideasRegalo!.isNotEmpty
            ? 'Regalo: ${evento.ideasRegalo}'
            : (evento.personaCumpleanos != null ? 'Cumpleañero: ${evento.personaCumpleanos}' : null))
        : (evento.descripcion != null && evento.descripcion!.trim().isNotEmpty
            ? evento.descripcion!.trim()
            : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
            child: Row(
              children: [
                // Icono temático con pastilla suave
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isBirthday ? Icons.cake_rounded : Icons.event_note_rounded,
                    size: 20,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),

                // Contenido textual
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                          if (isBirthday) ...[
                            const SizedBox(width: 6),
                            Text(
                              '🎂',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        evento.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Botón de opciones o eliminación si se proporciona
                if (onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.textSecondary.withOpacity(0.6),
                    ),
                    splashRadius: 18,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onDelete!();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
