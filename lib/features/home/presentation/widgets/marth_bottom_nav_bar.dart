import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Barra de navegacion inferior Claymorfica para MarthApp:
/// - 2 pestanas esenciales: Entornos y Ocio
/// - 100% libre de Glassmorfismo y BackdropFilter para garantizar 60 FPS solidos
/// - Badges interactivos para invitaciones pendientes y feedback haptico
class MarthBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final int pendingInvitesCount;

  const MarthBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.pendingInvitesCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final effectiveBaseColor = AppTheme.surfaceDark;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPadding > 0 ? bottomPadding + 4 : 12),
      decoration: BoxDecoration(
        color: effectiveBaseColor,
        gradient: AppTheme.claySurfaceGradient(baseColor: effectiveBaseColor),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: effectiveBaseColor),
        border: Border(
          top: BorderSide(
            color: AppTheme.cardBorderColor,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pestana 0: Entornos
          _buildNavItem(
            index: 0,
            icon: Icons.workspaces_outlined,
            activeIcon: Icons.workspaces_rounded,
            label: 'Entornos',
            badgeCount: pendingInvitesCount,
            onTap: () {
              HapticFeedback.selectionClick();
              onTabSelected(0);
            },
          ),
          const SizedBox(width: 16),
          // Pestana 1: Ocio & Cultura
          _buildNavItem(
            index: 1,
            icon: Icons.local_activity_outlined,
            activeIcon: Icons.local_activity_rounded,
            label: 'Ocio',
            badgeCount: 0,
            onTap: () {
              HapticFeedback.selectionClick();
              onTabSelected(1);
            },
          ),
          const SizedBox(width: 12),
          // Pestana 2: Planificador
          _buildNavItem(
            index: 2,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month_rounded,
            label: 'Planificador',
            badgeCount: 0,
            onTap: () {
              HapticFeedback.selectionClick();
              onTabSelected(2);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryLiquid.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.35),
                    width: 0.8,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.12 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      size: 24,
                      color: isSelected
                          ? AppTheme.primaryLiquid
                          : AppTheme.textSecondary,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCoral,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentCoral.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryLiquid
                      : AppTheme.textSecondary,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
