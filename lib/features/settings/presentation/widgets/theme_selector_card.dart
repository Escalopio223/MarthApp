import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_config.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_card.dart';

/// Tarjeta interactiva de configuración visual para seleccionar entre los 6 temas
/// core de MarthApp (Oscuros, Claros y Monocromáticos de Alto Contraste).
class ThemeSelectorCard extends StatefulWidget {
  final ThemeController themeController;
  final bool initiallyExpanded;

  const ThemeSelectorCard({
    super.key,
    required this.themeController,
    this.initiallyExpanded = false,
  });

  @override
  State<ThemeSelectorCard> createState() => _ThemeSelectorCardState();
}

class _ThemeSelectorCardState extends State<ThemeSelectorCard> {
  late bool _isExpanded;
  // 0 = Temas Oscuros, 1 = Temas Claros
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    // Abrir la pestaña correspondiente al tema actual
    _selectedTab = widget.themeController.isDark ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = widget.themeController.currentTheme;
    final themesToShow =
        _selectedTab == 0 ? AppThemes.darkThemes : AppThemes.lightThemes;

    return AppCard(
      borderRadius: 20.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera interactiva del acordeón
          _buildHeader(activeTheme),

          // Contenido desplegable con animación suave
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                Divider(color: AppTheme.cardBorderColor, height: 1),
                const SizedBox(height: 14),

                Text(
                  'Elige la estética visual de MarthApp. Cada tema adapta dinámicamente las superficies de arcilla táctil, relieves 3D y gradientes con alto contraste WCAG AA.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de pestaña (Oscuros / Claros)
                _buildCategoryTabs(),
                const SizedBox(height: 16),

                // Lista interactiva de los temas de la categoría
                ...themesToShow
                    .map((theme) => _buildThemeOption(theme, activeTheme)),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeConfig activeTheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.palette_rounded,
                color: AppTheme.primaryAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apariencia y Temas',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        activeTheme.name,
                        style: TextStyle(
                          color: AppTheme.primaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' • ${activeTheme.isDark ? 'Oscuro' : 'Claro'}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textSecondary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.cardBorderColor,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              label: 'Oscuros (3)',
              icon: Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              index: 1,
              label: 'Claros (3)',
              icon: Icons.light_mode_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.surfaceDark
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? AppTheme.clayRaisedShadows()
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? AppTheme.primaryAccent
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    AppThemeConfig theme,
    AppThemeConfig activeTheme,
  ) {
    final isSelected = activeTheme.id == theme.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.themeController.setTheme(theme),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.bgSurface
                  : AppTheme.surfaceDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.accentPrimary
                    : AppTheme.cardBorderColor,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.accentPrimary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Muestra cromática visual (Canvas + Superficie + Gradiente)
                _buildPaletteCircle(theme),
                const SizedBox(width: 14),

                // Nombre y etiqueta descriptiva
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            theme.name,
                            style: TextStyle(
                              color: isSelected
                                  ? theme.textPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (theme.id == ThemeId.midnightSlate) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.accentPrimary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Base',
                                style: TextStyle(
                                  color: theme.accentPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        theme.tag,
                        style: TextStyle(
                          color: isSelected
                              ? theme.textSecondary
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicador de selección
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected ? theme.actionGradient : null,
                    color: isSelected ? null : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppTheme.textSecondary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: theme.ctaTextColor,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteCircle(AppThemeConfig theme) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.bgCanvas,
        border: Border.all(
          color: theme.shadowLight.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: theme.actionGradient,
          ),
        ),
      ),
    );
  }
}
