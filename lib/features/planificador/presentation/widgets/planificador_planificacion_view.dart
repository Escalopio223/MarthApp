import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../controllers/planificador_controller.dart';
import 'agenda_calendar_view.dart';
import 'proyectos_backlog_view.dart';

/// Vista de "Planificación": agrupa la visión global de la casa:
/// - Calendario interactivo (fechas clave, eventos y tareas programadas)
/// - Proyectos del hogar (reformas, compras, objetivos) con barras de progreso aisladas
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
  // 0 = Calendario, 1 = Proyectos
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
                miembros: widget.miembros,
                usuarioActualId: widget.usuarioActualId,
                onCrearProyecto: widget.onCrearProyecto,
                onCrearTarea: widget.onCrearTarea,
              ),
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
}
