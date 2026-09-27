import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/recurrence_rule.dart';

/// Subformulario interactivo de configuración de reglas de recurrencia.
/// Permite configurar frecuencia (Diaria, Semanal, Mensual, Personalizada),
/// selección de días (L, M, X, J, V, S, D) y condiciones de término.
class RecurringRuleFormWidget extends StatelessWidget {
  final RecurrenceRule rule;
  final ValueChanged<RecurrenceRule> onChanged;

  const RecurringRuleFormWidget({
    super.key,
    required this.rule,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryLiquid.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector de Frecuencia
          _buildFrecuenciaSection(),
          const SizedBox(height: 14),

          // 2. Selector de Días de la semana (si aplica)
          if (_muestraSelectorDias) ...[
            _buildDiasSemanaSection(),
            const SizedBox(height: 14),
          ],

          // 3. Intervalo Personalizado (si frecuencia es custom)
          if (rule.frequency == RecurrenceFrequency.custom) ...[
            _buildCustomIntervalSection(context),
            const SizedBox(height: 14),
          ],

          // 4. Opciones de Término / Finalización
          _buildTerminoSection(context),
          const SizedBox(height: 12),

          // 5. Resumen en lenguaje natural
          _buildResumenBadge(),
        ],
      ),
    );
  }

  bool get _muestraSelectorDias =>
      rule.frequency == RecurrenceFrequency.weekly ||
      (rule.frequency == RecurrenceFrequency.custom &&
          rule.customUnit == CustomIntervalUnit.weeks);

  Widget _buildFrecuenciaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frecuencia',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: RecurrenceFrequency.values.map((freq) {
            final isSelected = rule.frequency == freq;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    List<int> defaultDays = rule.daysOfWeek;
                    if (freq == RecurrenceFrequency.weekly && defaultDays.isEmpty) {
                      defaultDays = [DateTime.now().weekday];
                    }
                    onChanged(rule.copyWith(
                      frequency: freq,
                      daysOfWeek: defaultDays,
                    ));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryLiquid.withValues(alpha: 0.18)
                          : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryLiquid
                            : AppTheme.cardBorderColor,
                        width: isSelected ? 1.4 : 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        freq.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryLiquid
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDiasSemanaSection() {
    const dias = [
      {'num': 1, 'label': 'L'},
      {'num': 2, 'label': 'M'},
      {'num': 3, 'label': 'X'},
      {'num': 4, 'label': 'J'},
      {'num': 5, 'label': 'V'},
      {'num': 6, 'label': 'S'},
      {'num': 7, 'label': 'D'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repetir los días',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dias.map((dia) {
            final dayNum = dia['num'] as int;
            final isSelected = rule.daysOfWeek.contains(dayNum);

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                final currentDays = List<int>.from(rule.daysOfWeek);
                if (isSelected) {
                  // No permitir dejar la lista completamente vacía
                  if (currentDays.length > 1) {
                    currentDays.remove(dayNum);
                  }
                } else {
                  currentDays.add(dayNum);
                  currentDays.sort();
                }
                onChanged(rule.copyWith(daysOfWeek: currentDays));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppTheme.primaryLiquid
                      : AppTheme.surfaceDark,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryLiquid
                        : AppTheme.cardBorderColor,
                    width: isSelected ? 1.4 : 0.8,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    dia['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomIntervalSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intervalo personalizado',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Cada',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),

            // Stepper de intervalo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.cardBorderColor,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    color: AppTheme.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: rule.interval > 1
                        ? () {
                            HapticFeedback.selectionClick();
                            onChanged(rule.copyWith(interval: rule.interval - 1));
                          }
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '${rule.interval}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    color: AppTheme.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onChanged(rule.copyWith(interval: rule.interval + 1));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Selector de unidad (Días / Semanas / Meses)
            Expanded(
              child: Row(
                children: CustomIntervalUnit.values.map((unit) {
                  final isSelected = rule.customUnit == unit;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(rule.copyWith(customUnit: unit));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.secondaryLilac.withValues(alpha: 0.18)
                                : AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.secondaryLilac
                                  : AppTheme.cardBorderColor,
                              width: isSelected ? 1.2 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              unit.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.secondaryLilac
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTerminoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condición de término',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: RecurrenceEndType.values.map((endType) {
            final isSelected = rule.endType == endType;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(rule.copyWith(
                      endType: endType,
                      endDate: endType == RecurrenceEndType.untilDate
                          ? (rule.endDate ??
                              DateTime.now().add(const Duration(days: 30)))
                          : null,
                      maxOccurrences: endType == RecurrenceEndType.afterOccurrences
                          ? (rule.maxOccurrences ?? 10)
                          : null,
                    ));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.secondaryAccent.withValues(alpha: 0.16)
                          : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.secondaryAccent
                            : AppTheme.cardBorderColor,
                        width: isSelected ? 1.4 : 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        endType.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.secondaryAccent
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Detalle adicional según condición de término
        if (rule.endType == RecurrenceEndType.untilDate) ...[
          const SizedBox(height: 10),
          _buildEndDateSelector(context),
        ] else if (rule.endType == RecurrenceEndType.afterOccurrences) ...[
          const SizedBox(height: 10),
          _buildMaxOccurrencesSelector(),
        ],
      ],
    );
  }

  Widget _buildEndDateSelector(BuildContext context) {
    final now = DateTime.now();
    final fecha = rule.endDate ?? now.add(const Duration(days: 30));

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final picked = await showDatePicker(
          context: context,
          initialDate: fecha,
          firstDate: now,
          lastDate: DateTime(now.year + 5, 12, 31),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: AppTheme.secondaryAccent,
                  surface: AppTheme.surfaceDark,
                  onSurface: AppTheme.textPrimary,
                ),
                dialogTheme: DialogThemeData(
                  backgroundColor: AppTheme.surfaceDark,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );

        if (picked != null) {
          onChanged(rule.copyWith(
            endDate: DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.secondaryAccent.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 16,
              color: AppTheme.secondaryAccent,
            ),
            const SizedBox(width: 8),
            Text(
              'Finalizar el: ${fecha.day}/${fecha.month}/${fecha.year}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaxOccurrencesSelector() {
    final count = rule.maxOccurrences ?? 10;

    return Row(
      children: [
        Text(
          'Repetir exactamente:',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.cardBorderColor,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 16),
                color: AppTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: count > 1
                    ? () {
                        HapticFeedback.selectionClick();
                        onChanged(rule.copyWith(maxOccurrences: count - 1));
                      }
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 16),
                color: AppTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onChanged(rule.copyWith(maxOccurrences: count + 1));
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'veces',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResumenBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: AppTheme.primaryLiquid,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Regla: ${rule.toHumanReadable()}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
