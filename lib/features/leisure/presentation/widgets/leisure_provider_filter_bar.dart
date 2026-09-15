import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/streaming_provider_dto.dart';

/// Barra de filtros horizontales para plataformas de streaming (VOD):
/// Permite alternar entre "Todas", Netflix, Disney+, Prime Video, Max, Hulu, etc.
class LeisureProviderFilterBar extends StatelessWidget {
  final int? selectedProviderId;
  final ValueChanged<int?> onProviderSelected;

  const LeisureProviderFilterBar({
    super.key,
    required this.selectedProviderId,
    required this.onProviderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final providers = StreamingProviderDto.popularProviders;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: providers.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAllSelected = selectedProviderId == null;
            return _buildChip(
              context: context,
              label: 'Todas',
              isSelected: isAllSelected,
              icon: Icons.auto_awesome_rounded,
              onTap: () => onProviderSelected(null),
            );
          }

          final provider = providers[index - 1];
          final isSelected = selectedProviderId == provider.providerId;

          return _buildChip(
            context: context,
            label: provider.providerName,
            isSelected: isSelected,
            logoUrl: provider.logoUrl,
            onTap: () => onProviderSelected(
              isSelected ? null : provider.providerId,
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    IconData? icon,
    String? logoUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLiquid.withValues(alpha: 0.22)
              : AppTheme.surfaceDark.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryLiquid
                : AppTheme.cardBorderColor.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
            ] else if (logoUrl != null && logoUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  logoUrl,
                  width: 16,
                  height: 16,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.play_circle_outline_rounded,
                    size: 14,
                    color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
