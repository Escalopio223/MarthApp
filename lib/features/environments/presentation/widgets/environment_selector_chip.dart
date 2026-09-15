import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../friends/presentation/controllers/friends_controller.dart';
import '../controllers/environment_controller.dart';
import 'environment_picker_sheet.dart';

/// Chip selector interactivo para la TopBar / AppBar
/// Permite conmutar fluidamente entre entornos y el modo global "Todos"
class EnvironmentSelectorChip extends StatelessWidget {
  final EnvironmentController environmentController;
  final FriendsController? friendsController;
  final VoidCallback? onEnvironmentChanged;

  const EnvironmentSelectorChip({
    super.key,
    required this.environmentController,
    this.friendsController,
    this.onEnvironmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: environmentController,
      builder: (context, _) {
        final isAll = environmentController.isAllSelected;
        final active = environmentController.activeEnvironment;

        final displayName = isAll ? 'Todos' : (active?.name ?? 'Mi espacio');

        final iconData = isAll
            ? Icons.dashboard_customize_rounded
            : (active?.iconData ?? Icons.person_pin_rounded);

        final themeColor = isAll
            ? AppTheme.secondaryLilac
            : (active?.colorValue ?? AppTheme.primaryCyan);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showEnvironmentPickerSheet(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, size: 16, color: themeColor),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEnvironmentPickerSheet(BuildContext context) {
    EnvironmentPickerSheet.show(
      context,
      controller: environmentController,
      friendsController: friendsController,
      onSelected: () {
        Navigator.pop(context);
        onEnvironmentChanged?.call();
      },
    );
  }
}
