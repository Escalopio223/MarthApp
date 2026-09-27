import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/services/reparto_equitativo_service.dart';
import '../controllers/planificador_controller.dart';

/// Diálogo modal de confirmación y previsualización del reparto automático equitativo.
/// Muestra un desglose visual claro de las tareas asignadas y los minutos estimados
/// por cada miembro antes de aplicar los cambios en la base de datos.
class RepartoPreviewDialog extends StatefulWidget {
  final ResultadoRepartoCalculado resultado;
  final PlanificadorController controller;

  const RepartoPreviewDialog({
    super.key,
    required this.resultado,
    required this.controller,
  });

  /// Método estático de conveniencia para mostrar el diálogo modal.
  static Future<bool?> show(
    BuildContext context, {
    required ResultadoRepartoCalculado resultado,
    required PlanificadorController controller,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RepartoPreviewDialog(
        resultado: resultado,
        controller: controller,
      ),
    );
  }

  @override
  State<RepartoPreviewDialog> createState() => _RepartoPreviewDialogState();
}

class _RepartoPreviewDialogState extends State<RepartoPreviewDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _confirmarYAplicar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    try {
      final usuariosParticipantes = widget.resultado.resumenMiembros
          .map((m) => m.userId)
          .toList();

      final exito = await widget.controller.aplicarRepartoLote(
        asignacionesFinales: widget.resultado.asignacionesFinales,
        usuariosParticipantes: usuariosParticipantes,
      );

      if (!mounted) return;

      if (exito) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = widget.controller.errorMessage ??
              'No se pudo completar el reparto de tareas.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error inesperado al aplicar reparto: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.resultado;
    final totalTareas = res.tareasTotales;
    final totalMinutos = res.minutosTotales;
    final resumenMiembros = res.resumenMiembros;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.liquidEmeraldGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentEmerald.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reparto automático',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalTareas ${totalTareas == 1 ? "tarea balanceada" : "tareas balanceadas"} (~$totalMinutos min)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCoral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentCoral.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.accentCoral,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.accentCoral,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                'Propuesta de asignación equilibrada:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Desglose por Miembro
              ...resumenMiembros.map((miembro) => _buildMiembroCard(miembro)),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmarYAplicar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLiquid,
            foregroundColor: Colors.white,
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Confirmar y aplicar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMiembroCard(MiembroRepartoResumen miembro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.7),
          width: 0.8,
        ),
        boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila del Miembro y totales
          Row(
            children: [
              UserAvatar(
                avatarData: miembro.avatarData,
                username: miembro.username,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  miembro.username,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryLiquid.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 11,
                      color: AppTheme.primaryLiquid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${miembro.totalTareas} ${miembro.totalTareas == 1 ? "tarea" : "tareas"} (~${miembro.minutosTotales} min)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLiquid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Lista de tareas asignadas al miembro
          if (miembro.tareas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: miembro.tareas.map((tarea) {
                  final duracion = tarea.tiempoEstimadoMinutos > 0
                      ? tarea.tiempoEstimadoMinutos
                      : RepartoEquitativoService.kTiempoEstimadoFallbackMinutos;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 12,
                          color: AppTheme.secondaryAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tarea.titulo,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textPrimary.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$duracion min',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Sin tareas asignadas en este balanceo',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
