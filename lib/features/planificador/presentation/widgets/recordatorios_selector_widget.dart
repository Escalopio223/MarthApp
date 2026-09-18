import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/recordatorio_tarea_model.dart';

/// Widget con estética Claymórfica para configurar uno o múltiples recordatorios programados por tarea.
/// Soporta accesos rápidos ("El día antes", "3 días antes", "1 semana antes", "El mismo día", "Personalizado...")
/// y selector opcional de hora fija con `showTimePicker` (o repetición automática cada 8h si no hay hora).
class RecordatoriosSelectorWidget extends StatefulWidget {
  final List<RecordatorioTareaModel> recordatoriosIniciales;
  final DateTime? fechaLimite;
  final ValueChanged<List<RecordatorioTareaModel>> onChanged;

  const RecordatoriosSelectorWidget({
    super.key,
    this.recordatoriosIniciales = const [],
    this.fechaLimite,
    required this.onChanged,
  });

  @override
  State<RecordatoriosSelectorWidget> createState() =>
      _RecordatoriosSelectorWidgetState();
}

class _RecordatoriosSelectorWidgetState
    extends State<RecordatoriosSelectorWidget> {
  late List<RecordatorioTareaModel> _recordatorios;

  @override
  void initState() {
    super.initState();
    _recordatorios = List.from(widget.recordatoriosIniciales);
  }

  @override
  void didUpdateWidget(covariant RecordatoriosSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordatoriosIniciales != widget.recordatoriosIniciales) {
      _recordatorios = List.from(widget.recordatoriosIniciales);
    }
  }

  void _notificarCambio() {
    widget.onChanged(List.unmodifiable(_recordatorios));
  }

  DateTime _baseDate() {
    if (widget.fechaLimite != null) {
      return DateTime(
        widget.fechaLimite!.year,
        widget.fechaLimite!.month,
        widget.fechaLimite!.day,
      );
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _agregarRecordatorioRapido({
    required int diasAntes,
    required String label,
  }) async {
    HapticFeedback.lightImpact();
    final fechaBase = _baseDate();
    final fechaNotif = fechaBase.subtract(Duration(days: diasAntes));

    // Permitir configurar hora opcional o dejar ciclo 8h
    final hora = await _preguntarHoraOpcional();

    final nuevo = RecordatorioTareaModel(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}_$diasAntes',
      tareaId: '',
      fechaNotificacion: fechaNotif,
      horaNotificacion: hora,
    );

    // Evitar duplicados exactos (misma fecha y misma hora)
    final yaExiste = _recordatorios.any((r) =>
        r.fechaNotificacion.year == nuevo.fechaNotificacion.year &&
        r.fechaNotificacion.month == nuevo.fechaNotificacion.month &&
        r.fechaNotificacion.day == nuevo.fechaNotificacion.day &&
        r.horaNotificacion == nuevo.horaNotificacion);

    if (!yaExiste) {
      setState(() {
        _recordatorios.add(nuevo);
      });
      _notificarCambio();
    }
  }

  Future<void> _agregarRecordatorioPersonalizado() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _baseDate(),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryLiquid,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final hora = await _preguntarHoraOpcional();

    final nuevo = RecordatorioTareaModel(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      tareaId: '',
      fechaNotificacion: DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      ),
      horaNotificacion: hora,
    );

    setState(() {
      _recordatorios.add(nuevo);
    });
    _notificarCambio();
  }

  Future<String?> _preguntarHoraOpcional() async {
    // Diálogo rápido: ¿Deseas fijar una hora específica o recibir aviso todo el día (cada 8h)?
    final definirHora = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.alarm_rounded, color: AppTheme.primaryLiquid, size: 22),
            const SizedBox(width: 8),
            Text(
              'Hora del aviso',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Deseas fijar una hora exacta para este recordatorio o recibir avisos en ciclo de 8h (00:00, 08:00, 16:00)?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Ciclo 8h (Todo el día)',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLiquid,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elegir hora fija'),
          ),
        ],
      ),
    );

    if (definirHora != true || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryLiquid,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return null;
    return '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
  }

  void _eliminarRecordatorio(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _recordatorios.removeAt(index);
    });
    _notificarCambio();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  size: 15,
                  color: AppTheme.primaryLiquid,
                ),
                const SizedBox(width: 6),
                Text(
                  'RECORDATORIOS PROGRAMADOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (_recordatorios.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_recordatorios.length}',
                  style: TextStyle(
                    color: AppTheme.primaryLiquid,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Chips de accesos rápidos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildAccesoRapidoChip(
                label: 'El mismo día',
                diasAntes: 0,
                icon: Icons.today_rounded,
              ),
              const SizedBox(width: 6),
              _buildAccesoRapidoChip(
                label: 'El día antes',
                diasAntes: 1,
                icon: Icons.event_repeat_rounded,
              ),
              const SizedBox(width: 6),
              _buildAccesoRapidoChip(
                label: '3 días antes',
                diasAntes: 3,
                icon: Icons.date_range_rounded,
              ),
              const SizedBox(width: 6),
              _buildAccesoRapidoChip(
                label: '1 semana antes',
                diasAntes: 7,
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _agregarRecordatorioPersonalizado,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryLiquid.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 14,
                        color: AppTheme.primaryLiquid,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Personalizado...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryLiquid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de recordatorios configurados
        if (_recordatorios.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._recordatorios.asMap().entries.map((entry) {
            final idx = entry.key;
            final rec = entry.value;
            final texto = rec.calcularAntelacionTexto(widget.fechaLimite);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.cardBorderColor,
                  width: 0.8,
                ),
                boxShadow: AppTheme.clayRaisedShadows(
                  baseColor: AppTheme.darkBackground,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      rec.tieneHoraFija
                          ? Icons.alarm_on_rounded
                          : Icons.loop_rounded,
                      size: 15,
                      color: AppTheme.primaryLiquid,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          texto,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          rec.textoDescriptivo,
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 17),
                    color: AppTheme.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _eliminarRecordatorio(idx),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAccesoRapidoChip({
    required String label,
    required int diasAntes,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _agregarRecordatorioRapido(
        diasAntes: diasAntes,
        label: label,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.cardBorderColor,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
