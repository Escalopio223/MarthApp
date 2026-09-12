import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';
import '../../domain/models/leisure_media_type.dart';

/// Selector horizontal Claymórfico de tipo de medio (Películas, Series, Libros, Videojuegos)
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: LeisureMediaType.values.map((type) {
          final isSelected = type == selectedType;
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: _buildTypePill(context, type, isSelected),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypePill(
      BuildContext context, LeisureMediaType type, bool isSelected) {
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
      borderRadius: 16.0,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      baseColor: isSelected ? AppTheme.primaryLiquid : AppTheme.surfaceDark,
      onTap: () {
        if (!isSelected) {
          HapticFeedback.lightImpact();
          onTypeChanged(type);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            type.pluralLabel,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
