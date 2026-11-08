import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Cabecera de Calendario Dinámica con diseño Flat 2.0.
/// - Modo Semana por defecto: Fila horizontal compacta de 7 días (~65px).
/// - Modo Mes expandido: Cuadrícula mensual completa limpia y sin solapamientos.
/// - Al pulsar cualquier día en la cuadrícula mensual se colapsa automáticamente
///   a la fila semanal y actualiza la fecha seleccionada.
class FlatCalendarHeader extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime) hasItemsOnDate;
  final ValueChanged<DateTime>? onMonthChanged;

  const FlatCalendarHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.hasItemsOnDate,
    this.onMonthChanged,
  });

  @override
  State<FlatCalendarHeader> createState() => _FlatCalendarHeaderState();
}

class _FlatCalendarHeaderState extends State<FlatCalendarHeader> {
  bool _isMonthExpanded = false;
  late DateTime _referenceDate;

  static const List<String> _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _referenceDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(covariant FlatCalendarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _referenceDate = widget.selectedDate;
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMonthExpanded = !_isMonthExpanded;
    });
  }

  void _previousPeriod() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isMonthExpanded) {
        _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 1, 1);
        widget.onMonthChanged?.call(_referenceDate);
      } else {
        _referenceDate = _referenceDate.subtract(const Duration(days: 7));
      }
    });
  }

  void _nextPeriod() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isMonthExpanded) {
        _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 1, 1);
        widget.onMonthChanged?.call(_referenceDate);
      } else {
        _referenceDate = _referenceDate.add(const Duration(days: 7));
      }
    });
  }

  void _selectToday() {
    final today = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() {
      _referenceDate = today;
      _isMonthExpanded = false;
    });
    widget.onDateSelected(today);
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _monthNames[_referenceDate.month - 1];
    final year = _referenceDate.year;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 200 && !_isMonthExpanded) {
            _toggleExpanded();
          } else if (details.primaryVelocity! < -200 && _isMonthExpanded) {
            _toggleExpanded();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.cardBorderColor.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila superior: Mes, Año, Navegadores y Botón de Expansión
            _buildTopBar(monthName, year),
            const SizedBox(height: 8),

            // Contenido dinámico (Semana compacta vs Cuadrícula mensual)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _isMonthExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildWeekView(),
              secondChild: _buildMonthGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String monthName, int year) {
    final now = DateTime.now();
    final isCurrentPeriodToday = isSameDay(_referenceDate, now) ||
        (!_isMonthExpanded &&
            now.isAfter(_referenceDate.subtract(Duration(days: _referenceDate.weekday))) &&
            now.isBefore(_referenceDate.add(Duration(days: 8 - _referenceDate.weekday))));

    return Row(
      children: [
        // Mes y año
        InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$monthName $year',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isMonthExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),

        // Botón rápido "Hoy" si no estamos viendo hoy
        if (!isCurrentPeriodToday)
          TextButton(
            onPressed: _selectToday,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(40, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: AppTheme.primaryAccent.withOpacity(0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Hoy',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryAccent,
              ),
            ),
          ),
        const SizedBox(width: 4),

        // Navegación período anterior
        _buildNavIconButton(
          icon: Icons.chevron_left_rounded,
          onTap: _previousPeriod,
        ),

        // Navegación período siguiente
        _buildNavIconButton(
          icon: Icons.chevron_right_rounded,
          onTap: _nextPeriod,
        ),
      ],
    );
  }

  Widget _buildNavIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Icon(
            icon,
            size: 20,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Modo Semana (Fila horizontal de 7 días, ~65px)
  // ===========================================================================

  Widget _buildWeekView() {
    // Calcular Lunes de la semana que contiene a _referenceDate
    final monday = DateTime(
      _referenceDate.year,
      _referenceDate.month,
      _referenceDate.day,
    ).subtract(Duration(days: _referenceDate.weekday - 1));

    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    final now = DateTime.now();

    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekDays.map((day) {
          final isSelected = isSameDay(day, widget.selectedDate);
          final isToday = isSameDay(day, now);
          final hasItems = widget.hasItemsOnDate(day);
          final label = _weekdayLabels[day.weekday - 1];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: _buildDayCell(
                day: day,
                label: label,
                isSelected: isSelected,
                isToday: isToday,
                hasItems: hasItems,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _referenceDate = day);
                  widget.onDateSelected(day);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell({
    required DateTime day,
    required String label,
    required bool isSelected,
    required bool isToday,
    required bool hasItems,
    required VoidCallback onTap,
  }) {
    final borderColor = isSelected
        ? AppTheme.primaryAccent
        : (isToday
            ? AppTheme.primaryAccent.withOpacity(0.5)
            : AppTheme.cardBorderColor.withOpacity(0.12));

    final bgColor = isSelected
        ? AppTheme.primaryAccent
        : (isToday
            ? AppTheme.primaryAccent.withOpacity(0.08)
            : Colors.transparent);

    final textColor = isSelected
        ? Colors.white
        : (isToday ? AppTheme.primaryAccent : AppTheme.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white.withOpacity(0.85)
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 3),
            // Badge / Punto mínimo
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasItems
                    ? (isSelected ? Colors.white : AppTheme.primaryAccent)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Modo Mes Expandido (Cuadrícula mensual completa)
  // ===========================================================================

  Widget _buildMonthGrid() {
    final year = _referenceDate.year;
    final month = _referenceDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();

    // Desfase para que Lunes sea 0 y Domingo 6
    final leadingEmpty = firstDayOfMonth.weekday - 1;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabecera de días de la semana
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdayLabels.map((lbl) {
              return SizedBox(
                width: 32,
                child: Text(
                  lbl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),

        // Grid de celdas
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingEmpty + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final cellDate = DateTime(year, month, dayNumber);
            final isSelected = isSameDay(cellDate, widget.selectedDate);
            final isToday = isSameDay(cellDate, now);
            final hasItems = widget.hasItemsOnDate(cellDate);

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _referenceDate = cellDate;
                  _isMonthExpanded = false; // Auto-colapso al tocar cualquier día
                });
                widget.onDateSelected(cellDate);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryAccent
                      : (isToday
                          ? AppTheme.primaryAccent.withOpacity(0.08)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryAccent
                        : (isToday
                            ? AppTheme.primaryAccent.withOpacity(0.4)
                            : Colors.transparent),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isToday
                                ? AppTheme.primaryAccent
                                : AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasItems
                            ? (isSelected ? Colors.white : AppTheme.primaryAccent)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

