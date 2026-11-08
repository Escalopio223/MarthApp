import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/services/reparto_equitativo_service.dart';

/// Modal BottomSheet con estética Flat Design 2.0 para previsualizar y confirmar
/// el balanceo / reparto automático de tareas del día entre los miembros del hogar.
class FlatRepartoPreviewSheet extends StatefulWidget {
  final ResultadoRepartoCalculado resultado;
  final Future<void> Function() onConfirm;

  const FlatRepartoPreviewSheet({
    super.key,
    required this.resultado,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required ResultadoRepartoCalculado resultado,
    required Future<void> Function() onConfirm,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlatRepartoPreviewSheet(
        resultado: resultado,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<FlatRepartoPreviewSheet> createState() => _FlatRepartoPreviewSheetState();
}

class _FlatRepartoPreviewSheetState extends State<FlatRepartoPreviewSheet> {
  bool _isApplying = false;
  String? _errorMessage;

  Future<void> _handleApply() async {
    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApplying = false;
          _errorMessage = 'Error al aplicar reparto: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final resumenMiembros = widget.resultado.resumenMiembros;
    final totalTareasRepartidas = widget.resultado.tareasNuevamenteRepartidas;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: AppTheme.cardBorderColor.withOpacity(0.18),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera del modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.balance_rounded,
                      size: 20,
                      color: AppTheme.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balanceo de Tareas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalTareasRepartidas tarea${totalTareasRepartidas == 1 ? '' : 's'} no asignada${totalTareasRepartidas == 1 ? '' : 's'} a repartir',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.cardBorderColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${widget.resultado.minutosTotales}m total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Explicación informativa rápida
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.cardBorderColor.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se reparten las tareas no asignadas buscando la menor diferencia de minutos acumulados entre convivientes.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lista de miembros con la propuesta de tiempo
              Text(
                'Reparto propuesto por miembro',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              ...resumenMiembros.map((m) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.cardBorderColor.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          UserAvatar(
                            avatarData: m.avatarData,
                            username: m.username,
                            size: 26,
                            showBorder: false,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.username,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${m.totalTareas} tarea${m.totalTareas == 1 ? '' : 's'} (${m.nuevasTareasAsignadas} nueva${m.nuevasTareasAsignadas == 1 ? '' : 's'})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${m.minutosTotales} min',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (m.tareas.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: m.tareas.map((t) {
                            final duracion = t.tiempoEstimadoMinutos > 0
                                ? '${t.tiempoEstimadoMinutos}m'
                                : '15m*';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.cardBorderColor.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${t.titulo} ($duracion)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textPrimary.withOpacity(0.9),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],

              const SizedBox(height: 18),

              // Botones de acción: Aplicar cambios y Cancelar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isApplying ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(
                          color: AppTheme.cardBorderColor.withOpacity(0.25),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isApplying ? null : _handleApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: _isApplying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Aplicar cambios',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

