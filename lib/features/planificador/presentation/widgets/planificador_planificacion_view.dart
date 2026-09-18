import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../controllers/planificador_controller.dart';
import 'agenda_calendar_view.dart';
import 'proyectos_backlog_view.dart';
import 'reparto_tareas_board_view.dart';

/// Vista de "Planificación": agrupa la visión global de la casa:
/// - Calendario interactivo (fechas clave, eventos y tareas programadas)
/// - Proyectos del hogar (reformas, compras, objetivos) con barras de progreso aisladas
/// - Reparto equitativo con botón directo de "Reparto Rápido" y tablero Drag & Drop
class PlanificadorPlanificacionView extends StatefulWidget {
  final PlanificadorController controller;
  final List<EnvironmentMemberModel> miembros;
  final String? usuarioActualId;
  final VoidCallback? onCrearTarea;
  final VoidCallback? onCrearEvento;
  final VoidCallback? onCrearProyecto;

  const PlanificadorPlanificacionView({
    super.key,
    required this.controller,
    this.miembros = const [],
    this.usuarioActualId,
    this.onCrearTarea,
    this.onCrearEvento,
    this.onCrearProyecto,
  });

  @override
  State<PlanificadorPlanificacionView> createState() =>
      _PlanificadorPlanificacionViewState();
}

class _PlanificadorPlanificacionViewState
    extends State<PlanificadorPlanificacionView> {
  // 0 = Calendario, 1 = Proyectos, 2 = Reparto
  int _currentSubTab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selector de sub-sección minimalista
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: AppContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(3),
            baseColor: AppTheme.surfaceDark,
            child: Row(
              children: [
                _buildSubTabButton(
                  title: 'Calendario',
                  icon: Icons.calendar_month_rounded,
                  index: 0,
                ),
                _buildSubTabButton(
                  title: 'Proyectos',
                  icon: Icons.folder_special_rounded,
                  index: 1,
                ),
                _buildSubTabButton(
                  title: 'Reparto',
                  icon: Icons.balance_rounded,
                  index: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Contenido de la sub-pestaña seleccionada
        Expanded(
          child: IndexedStack(
            index: _currentSubTab,
            children: [
              // 0: Calendario y Agenda
              AgendaCalendarView(
                controller: widget.controller,
                miembros: widget.miembros,
                usuarioActualId: widget.usuarioActualId,
                onCrearTarea: widget.onCrearTarea,
                onCrearEvento: widget.onCrearEvento,
              ),

              // 1: Proyectos del hogar (sin ruido del día a día)
              ProyectosBacklogView(
                controller: widget.controller,
                onCrearProyecto: widget.onCrearProyecto,
                onCrearTarea: widget.onCrearTarea,
              ),

              // 2: Tablero de Reparto con acción rápida
              _buildRepartoConAccionRapida(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _currentSubTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentSubTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.actionGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color:
                    isSelected ? AppTheme.ctaTextColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color:
                      isSelected ? AppTheme.ctaTextColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepartoConAccionRapida(BuildContext context) {
    final miembrosIds = widget.miembros.map((m) => m.userId).toList();
    final pendientes = widget.controller.tareasPendientes;

    return Column(
      children: [
        // Barra superior con botón de Reparto Rápido en 1 toque
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REPARTO DE TAREAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pendientes.length} tareas pendientes en el hogar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await widget.controller.ejecutarRepartoRapidoSemanal(
                    miembrosIds,
                  );
                },
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Reparto Rápido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLiquid,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tablero Kanban Drag & Drop existente
        Expanded(
          child: RepartoTareasBoardView(
            controller: widget.controller,
            miembros: widget.miembros,
          ),
        ),
      ],
    );
  }
}
