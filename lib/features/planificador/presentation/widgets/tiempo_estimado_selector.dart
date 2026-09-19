import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

enum UnidadTiempo { minutos, horas }

/// Selector / Creador interactivo de tiempo estimado para tareas del Planificador.
/// Permite definir libremente la duración ingresando o seleccionando un número del 1 al 60
/// junto con la unidad de medida (Minutos u Horas), o marcar la tarea como "Sin tiempo".
class TiempoEstimadoSelector extends StatefulWidget {
  final int initialMinutes;
  final ValueChanged<int> onChanged;

  const TiempoEstimadoSelector({
    super.key,
    required this.initialMinutes,
    required this.onChanged,
  });

  @override
  State<TiempoEstimadoSelector> createState() => _TiempoEstimadoSelectorState();
}

class _TiempoEstimadoSelectorState extends State<TiempoEstimadoSelector> {
  late TextEditingController _numeroController;
  late UnidadTiempo _unidad;
  late bool _sinTiempo;
  late int _numero;

  @override
  void initState() {
    super.initState();
    _sinTiempo = widget.initialMinutes <= 0;
    if (_sinTiempo) {
      _numero = 15;
      _unidad = UnidadTiempo.minutos;
      _numeroController = TextEditingController(text: '15');
    } else {
      if (widget.initialMinutes % 60 == 0 &&
          (widget.initialMinutes ~/ 60) <= 60 &&
          widget.initialMinutes > 0) {
        _numero = widget.initialMinutes ~/ 60;
        _unidad = UnidadTiempo.horas;
      } else {
        _numero = widget.initialMinutes > 60
            ? widget.initialMinutes
            : widget.initialMinutes.clamp(1, 60);
        _unidad = UnidadTiempo.minutos;
      }
      _numeroController = TextEditingController(text: '$_numero');
    }
  }

  @override
  void didUpdateWidget(covariant TiempoEstimadoSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMinutes != widget.initialMinutes) {
      final nuevoSinTiempo = widget.initialMinutes <= 0;
      if (nuevoSinTiempo != _sinTiempo ||
          _calcularMinutos() != widget.initialMinutes) {
        _sinTiempo = nuevoSinTiempo;
        if (!_sinTiempo) {
          if (widget.initialMinutes % 60 == 0 &&
              (widget.initialMinutes ~/ 60) <= 60 &&
              widget.initialMinutes > 0) {
            _numero = widget.initialMinutes ~/ 60;
            _unidad = UnidadTiempo.horas;
          } else {
            _numero = widget.initialMinutes > 60
                ? widget.initialMinutes
                : widget.initialMinutes.clamp(1, 60);
            _unidad = UnidadTiempo.minutos;
          }
          _numeroController.text = '$_numero';
        }
      }
    }
  }

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  int _calcularMinutos() {
    if (_sinTiempo) return 0;
    final multiplicador = _unidad == UnidadTiempo.horas ? 60 : 1;
    return (_numero.clamp(1, 999)) * multiplicador;
  }

  void _notificarCambio() {
    final mins = _calcularMinutos();
    widget.onChanged(mins);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila superior: Título y Chip de alternancia rápida "Sin tiempo"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tiempo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppTheme.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _sinTiempo = !_sinTiempo;
                });
                if (_sinTiempo) {
                  widget.onChanged(0);
                } else {
                  _notificarCambio();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _sinTiempo
                      ? AppTheme.accentEmerald.withValues(alpha: 0.16)
                      : AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _sinTiempo
                        ? AppTheme.accentEmerald
                        : AppTheme.cardBorderColor,
                    width: _sinTiempo ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sinTiempo
                          ? Icons.check_circle_rounded
                          : Icons.timer_off_outlined,
                      size: 13,
                      color: _sinTiempo
                          ? AppTheme.accentEmerald
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sin tiempo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            _sinTiempo ? FontWeight.bold : FontWeight.w500,
                        color: _sinTiempo
                            ? AppTheme.accentEmerald
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fila de controles: Input con opciones de 1 a 60 + Selector de unidad (Minutos u Horas)
        Row(
          children: [
            // Campo de número (1 al 60) con entrada directa por teclado y menú desplegable
            Expanded(
              flex: 5,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !_sinTiempo
                        ? AppTheme.primaryLiquid.withValues(alpha: 0.6)
                        : AppTheme.cardBorderColor,
                    width: !_sinTiempo ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.pin_outlined,
                      size: 16,
                      color: !_sinTiempo
                          ? AppTheme.primaryLiquid
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _numeroController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '1 - 60',
                          hintStyle: TextStyle(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val.trim());
                          if (parsed != null && parsed > 0) {
                            final clamped = parsed > 60 ? 60 : parsed;
                            if (clamped != parsed) {
                              _numeroController.text = '$clamped';
                              _numeroController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: _numeroController.text.length),
                              );
                            }
                            setState(() {
                              _numero = clamped;
                              _sinTiempo = false;
                            });
                            _notificarCambio();
                          } else if (val.isEmpty || parsed == 0) {
                            setState(() {
                              _sinTiempo = true;
                            });
                            widget.onChanged(0);
                          }
                        },
                      ),
                    ),
                    // Botón desplegable con opciones del 1 al 60
                    Theme(
                      data: Theme.of(context).copyWith(
                        cardColor: AppTheme.surfaceDark,
                      ),
                      child: PopupMenuButton<int>(
                        tooltip: 'Seleccionar número (1 al 60)',
                        icon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppTheme.textSecondary,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        color: AppTheme.surfaceDark,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: AppTheme.cardBorderColor,
                            width: 0.8,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          maxHeight: 280,
                          minWidth: 90,
                        ),
                        onSelected: (int num) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _numero = num;
                            _numeroController.text = '$num';
                            _sinTiempo = false;
                          });
                          _notificarCambio();
                        },
                        itemBuilder: (context) {
                          return List.generate(60, (index) {
                            final num = index + 1;
                            final isSelected = !_sinTiempo && _numero == num;
                            return PopupMenuItem<int>(
                              value: num,
                              height: 38,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryLiquid
                                          .withValues(alpha: 0.18)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$num',
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.primaryLiquid
                                            : AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: AppTheme.primaryLiquid,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Selector desplegable de Unidad (Minutos u Horas)
            Expanded(
              flex: 5,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !_sinTiempo
                        ? AppTheme.primaryLiquid.withValues(alpha: 0.6)
                        : AppTheme.cardBorderColor,
                    width: !_sinTiempo ? 1.2 : 0.8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UnidadTiempo>(
                    value: _unidad,
                    dropdownColor: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppTheme.textSecondary,
                      size: 24,
                    ),
                    isExpanded: true,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (UnidadTiempo? nuevaUnidad) {
                      if (nuevaUnidad != null) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _unidad = nuevaUnidad;
                          _sinTiempo = false;
                        });
                        _notificarCambio();
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: UnidadTiempo.minutos,
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color:
                                  !_sinTiempo && _unidad == UnidadTiempo.minutos
                                      ? AppTheme.primaryLiquid
                                      : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Minutos'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: UnidadTiempo.horas,
                        child: Row(
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              size: 16,
                              color: !_sinTiempo &&
                                      _unidad == UnidadTiempo.horas
                                  ? AppTheme.secondaryAccent
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Text('Horas'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Resumen en tiempo real del tiempo estimado
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Icon(
                _sinTiempo ? Icons.timer_off_outlined : Icons.schedule_rounded,
                size: 13,
                color:
                    _sinTiempo ? AppTheme.textSecondary : AppTheme.primaryLiquid,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _sinTiempo
                      ? 'Tarea sin estimación de duración'
                      : _unidad == UnidadTiempo.horas
                          ? 'Duración estimada: $_numero ${_numero == 1 ? 'hora' : 'horas'} (${_numero * 60} min)'
                          : 'Duración estimada: $_numero min',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        _sinTiempo ? FontWeight.normal : FontWeight.w600,
                    color: _sinTiempo
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
