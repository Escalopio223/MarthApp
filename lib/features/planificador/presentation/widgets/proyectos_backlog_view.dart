import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/tarea_model.dart';
import '../controllers/planificador_controller.dart';

/// Vista de Proyectos y Backlog de Tareas sueltas con barras de progreso y checkboxes reactivos
class ProyectosBacklogView extends StatefulWidget {
  final PlanificadorController controller;
  final VoidCallback? onCrearProyecto;
  final VoidCallback? onCrearTarea;

  const ProyectosBacklogView({
    super.key,
    required this.controller,
    this.onCrearProyecto,
    this.onCrearTarea,
  });

  @override
  State<ProyectosBacklogView> createState() => _ProyectosBacklogViewState();
}

class _ProyectosBacklogViewState extends State<ProyectosBacklogView> {
  // 0 = Proyectos, 1 = Tareas sueltas
  int _selectedTab = 0;
  final Set<String> _expandedProjectIds = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSegmentedTabSelector(context),
        const SizedBox(height: 12),
        Expanded(
          child: _selectedTab == 0
              ? _buildProyectosList(context)
              : _buildTareasSueltasList(context),
        ),
      ],
    );
  }

  // ===========================================================================
  // Segmented Control Claymórfico: "Proyectos" vs "Tareas sueltas"
  // ===========================================================================

  Widget _buildSegmentedTabSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: AppContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(4),
              baseColor: AppTheme.surfaceDark,
              child: Row(
                children: [
                  _buildTabOption(
                    title: 'Proyectos (${widget.controller.proyectos.length})',
                    icon: Icons.folder_rounded,
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  _buildTabOption(
                    title: 'Tareas sueltas (${widget.controller.tareasSueltas.length})',
                    icon: Icons.checklist_rounded,
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(10),
            baseColor: AppTheme.surfaceDark,
            onTap: _selectedTab == 0
                ? widget.onCrearProyecto
                : widget.onCrearTarea,
            child: Icon(
              Icons.add_rounded,
              color: AppTheme.primaryLiquid,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.actionGradient : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppTheme.ctaTextColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
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

  // ===========================================================================
  // Lista de Proyectos con Barra de Progreso
  // ===========================================================================

  Widget _buildProyectosList(BuildContext context) {
    final proyectos = widget.controller.proyectos;

    if (proyectos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 52,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay proyectos creados aún',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.onCrearProyecto != null)
              ElevatedButton.icon(
                onPressed: widget.onCrearProyecto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLiquid,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Crear primer proyecto'),
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      itemCount: proyectos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final proyecto = proyectos[index];
        return _buildProyectoCard(context, proyecto);
      },
    );
  }

  Widget _buildProyectoCard(BuildContext context, ProyectoModel proyecto) {
    final tareasDelProyecto =
        widget.controller.getTareasPorProyecto(proyecto.id);
    final totalTareas = tareasDelProyecto.length;
    final completadas =
        tareasDelProyecto.where((t) => t.estaCompletada).length;
    final progreso = totalTareas > 0 ? completadas / totalTareas : 0.0;
    final isExpanded = _expandedProjectIds.contains(proyecto.id);

    final color = _parseColor(proyecto.colorHex);

    return AppContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      baseColor: AppTheme.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getIconData(proyecto.icono),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proyecto.nombre,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (proyecto.descripcion != null &&
                        proyecto.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        proyecto.descripcion!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Botón expandir/colapsar tareas
              IconButton(
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedProjectIds.remove(proyecto.id);
                    } else {
                      _expandedProjectIds.add(proyecto.id);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de progreso interactiva
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 8,
                    backgroundColor:
                        AppTheme.textSecondary.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progreso >= 1.0 ? AppTheme.accentEmerald : color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completadas/$totalTareas (${(progreso * 100).toInt()}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          // Tareas anidadas desplegables
          if (isExpanded) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (tareasDelProyecto.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Este proyecto no tiene tareas asociadas.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              ...tareasDelProyecto.map(
                (tarea) => _buildTareaItem(context, tarea),
              ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Lista de Tareas Sueltas (Backlog sin proyecto)
  // ===========================================================================

  Widget _buildTareasSueltasList(BuildContext context) {
    final tareas = widget.controller.tareasSueltas;

    if (tareas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 52,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay tareas sueltas pendientes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      itemCount: tareas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tarea = tareas[index];
        return AppContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
          baseColor: AppTheme.surfaceDark,
          child: _buildTareaItem(context, tarea),
        );
      },
    );
  }

  // ===========================================================================
  // Fila de Tarea Individual con Checkbox Reactivo y Checklist desplegable
  // ===========================================================================

  Widget _buildTareaItem(BuildContext context, TareaModel tarea) {
    final isDone = tarea.estaCompletada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox táctil 3D claymórfico
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.controller.toggleTarea(tarea.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDone
                      ? AppTheme.liquidEmeraldGradient
                      : AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
                  border: Border.all(
                    color: isDone
                        ? AppTheme.accentEmerald
                        : AppTheme.cardBorderColor.withValues(alpha: 0.9),
                    width: isDone ? 1.0 : 1.3,
                  ),
                  boxShadow: isDone
                      ? [
                          BoxShadow(
                            color: AppTheme.accentEmerald.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark, isPressed: false),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                      : Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.textSecondary.withValues(alpha: 0.25),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tarea.titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? AppTheme.textSecondary.withValues(alpha: 0.5)
                          : AppTheme.textPrimary,
                    ),
                  ),
                  if (tarea.descripcion != null &&
                      tarea.descripcion!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tarea.descripcion!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Clay pill de tiempo estimado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                gradient: AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.28),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '${tarea.tiempoEstimadoMinutos} min',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLiquid,
                ),
              ),
            ),
          ],
        ),
        // Checklist interactivo en bandeja hendida si la tarea contiene elementos
        if (tarea.checklist.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.isDark
                    ? Color.alphaBlend(Colors.black.withValues(alpha: 0.3), AppTheme.surfaceDark)
                    : Color.alphaBlend(AppTheme.shadowDark.withValues(alpha: 0.12), AppTheme.surfaceDark),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.clayInsetShadows(),
                border: Border.all(
                  color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Column(
                children: tarea.checklist.map((item) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.controller.toggleChecklistItem(tarea.id, item.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              gradient: item.completado
                                  ? AppTheme.liquidEmeraldGradient
                                  : AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
                              border: Border.all(
                                color: item.completado
                                    ? AppTheme.accentEmerald
                                    : AppTheme.cardBorderColor.withValues(alpha: 0.8),
                                width: 1.2,
                              ),
                              boxShadow: item.completado
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.accentEmerald.withValues(alpha: 0.35),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: item.completado
                                ? const Icon(Icons.check_rounded,
                                    size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.titulo,
                              style: TextStyle(
                                fontSize: 12,
                                decoration:
                                    item.completado ? TextDecoration.lineThrough : null,
                                color: item.completado
                                    ? AppTheme.textSecondary.withValues(alpha: 0.45)
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // Helpers de Iconos y Colores
  // ===========================================================================

  Color _parseColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppTheme.primaryLiquid;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}
