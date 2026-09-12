import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';

/// Acordeón táctil Claymórfico colapsable de alto rendimiento:
/// - Animación fluida de apertura/cierre sin saltos
/// - Cabecera ergonómica con icono temático, título y badge informativo
/// - Haptic feedback al desplegar/colapsar
class LeisureAccordion extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? badgeText;
  final Widget child;
  final bool initiallyExpanded;
  final VoidCallback? onExpansionChanged;

  const LeisureAccordion({
    super.key,
    required this.icon,
    required this.title,
    this.badgeText,
    required this.child,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  @override
  State<LeisureAccordion> createState() => _LeisureAccordionState();
}

class _LeisureAccordionState extends State<LeisureAccordion> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      borderRadius: 16.0,
      padding: EdgeInsets.zero,
      baseColor: AppTheme.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera táctil
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16.0),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: AppTheme.primaryLiquid,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.badgeText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        widget.badgeText!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cuerpo colapsable animado
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    color: AppTheme.cardBorderColor,
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  widget.child,
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}
