import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';
import '../../domain/models/leisure_media_type.dart';

/// Selector Claymórfico de tipo de medio (Películas, Series, Libros, Videojuegos)
/// Completamente anclado al ancho de pantalla (sin scroll horizontal) con escala adaptativa.
class LeisureMediaTypeSelector extends StatelessWidget {
  final LeisureMediaType selectedType;
  final ValueChanged<LeisureMediaType> onTypeChanged;

  const LeisureMediaTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = LeisureMediaType.values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          for (int i = 0; i < types.length; i++) ...[
            if (i > 0) const SizedBox(width: 6.0),
            Expanded(
              child: _buildTypeSegment(context, types[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSegment(BuildContext context, LeisureMediaType type) {
    final isSelected = type == selectedType;

    IconData icon;
    switch (type) {
      case LeisureMediaType.movie:
        icon = Icons.movie_filter_rounded;
        break;
      case LeisureMediaType.tv:
        icon = Icons.tv_rounded;
        break;
      case LeisureMediaType.book:
        icon = Icons.auto_stories_rounded;
        break;
      case LeisureMediaType.game:
        icon = Icons.sports_esports_rounded;
        break;
    }

    return AppContainer(
      borderRadius: 14.0,
      padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 4.0),
      baseColor: isSelected ? AppTheme.primaryLiquid : AppTheme.surfaceDark,
      onTap: () {
        if (!isSelected) {
          HapticFeedback.lightImpact();
          onTypeChanged(type);
        }
      },
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                type.pluralLabel,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
