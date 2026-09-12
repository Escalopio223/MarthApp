import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';

/// Selector táctil Claymórfico de calificación personal continua:
/// - Rango estricto de 1.0 a 10.0 con divisiones exactas de 0.1
/// - Micro-vibración háptica (`HapticFeedback.selectionClick()`) por cada salto
/// - Badge numérico dinámico con gradiente de color según puntaje
/// - Opción para remover la calificación (valor `null`)
class LeisureRatingSlider extends StatefulWidget {
  final double? initialRating;
  final ValueChanged<double?> onRatingChanged;
  final bool readOnly;

  const LeisureRatingSlider({
    super.key,
    this.initialRating,
    required this.onRatingChanged,
    this.readOnly = false,
  });

  @override
  State<LeisureRatingSlider> createState() => _LeisureRatingSliderState();
}

class _LeisureRatingSliderState extends State<LeisureRatingSlider> {
  double? _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating != null
        ? _clampRating(widget.initialRating!)
        : null;
  }

  @override
  void didUpdateWidget(covariant LeisureRatingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      _rating = widget.initialRating != null
          ? _clampRating(widget.initialRating!)
          : null;
    }
  }

  double _clampRating(double val) {
    final clamped = val.clamp(1.0, 10.0);
    return double.parse(clamped.toStringAsFixed(1));
  }

  void _onSliderChanged(double value) {
    if (widget.readOnly) return;
    final rounded = double.parse(value.toStringAsFixed(1));
    if (_rating != rounded) {
      // Micro-vibración física por cada tick de 0.1
      HapticFeedback.selectionClick();
      setState(() {
        _rating = rounded;
      });
      widget.onRatingChanged(rounded);
    }
  }

  void _clearRating() {
    if (widget.readOnly || _rating == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _rating = null;
    });
    widget.onRatingChanged(null);
  }

  Color _getScoreColor(double score) {
    if (score < 5.0) return const Color(0xFFFF5252);
    if (score < 7.0) return const Color(0xFFFFB74D);
    if (score < 8.5) return const Color(0xFF64B5F6);
    return const Color(0xFF00E676);
  }

  @override
  Widget build(BuildContext context) {
    final currentScore = _rating;
    final scoreColor = currentScore != null
        ? _getScoreColor(currentScore)
        : AppTheme.textSecondary;

    return AppContainer(
      borderRadius: 18.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      baseColor: AppTheme.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila de encabezado: Título + Badge numérico + Botón Limpiar
          Row(
            children: [
              Icon(
                Icons.star_rate_rounded,
                size: 20,
                color: currentScore != null ? scoreColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tu Puntuación',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Badge de puntaje
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: currentScore != null
                      ? scoreColor.withValues(alpha: 0.18)
                      : AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentScore != null
                        ? scoreColor.withValues(alpha: 0.5)
                        : AppTheme.cardBorderColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  currentScore != null
                      ? '${currentScore.toStringAsFixed(1)} / 10'
                      : 'Sin calificar',
                  style: TextStyle(
                    color: currentScore != null
                        ? scoreColor
                        : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (currentScore != null && !widget.readOnly) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Borrar nota',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: _clearRating,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Slider continuo con 90 pasos (1.0 a 10.0 en 0.1)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6.0,
              activeTrackColor: scoreColor,
              inactiveTrackColor: AppTheme.textSecondary.withValues(alpha: 0.2),
              thumbColor: scoreColor,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10.0,
                pressedElevation: 6.0,
              ),
              overlayColor: scoreColor.withValues(alpha: 0.2),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
            ),
            child: Slider(
              value: currentScore ?? 5.0,
              min: 1.0,
              max: 10.0,
              divisions: 90,
              onChanged: widget.readOnly ? null : _onSliderChanged,
            ),
          ),
        ],
      ),
    );
  }
}
