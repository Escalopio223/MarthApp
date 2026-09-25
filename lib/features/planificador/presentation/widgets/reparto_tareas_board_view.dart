import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/tarea_model.dart';
import '../controllers/planificador_controller.dart';

/// Tablero interactivo de reparto equitativo de tareas con Drag & Drop entre miembros del entorno.
class RepartoTareasBoardView extends StatefulWidget {
  final PlanificadorController controller;
  final List<EnvironmentMemberModel> miembros;

  const RepartoTareasBoardView({
    super.key,
    required this.controller,
    this.miembros = const [],
  });

  @override
  State<RepartoTareasBoardView> createState() => _RepartoTareasBoardViewState();
}

class _RepartoTareasBoardViewState extends State<RepartoTareasBoardView> {
  bool _mostrarSelectorTareas = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _sincronizarParticipantes();
  }

  @override
  void didUpdateWidget(covariant RepartoTareasBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    _sincronizarParticipantes();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _sincronizarParticipantes() {
    if (widget.miembros.isNotEmpty) {
      widget.controller.sincronizarParticipantes(
        widget.miembros.map((m) => m.userId).toList(),
      );
      widget.controller.inicializarTareasRepartoSiVacio();
    }
  }

  EnvironmentMemberModel? _getMiembro(String userId) {
    try {
      return widget.miembros.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final participantes = controller.participantesIds;

    return Column(
      children: [
        _buildActionHeader(context),
        if (widget.miembros.isNotEmpty) _buildParticipantesSelectorBar(context),
        if (_mostrarSelectorTareas) _buildTareasSelectorPanel(context),
        const SizedBox(height: 8),
        Expanded(
          child: participantes.isEmpty
              ? _buildSinParticipantes(context)
              : _buildBoardColumns(context),
        ),
        _buildBottomConfirmationBar(context),
      ],
    );
  }

  // ===========================================================================
  // Barra de Selección de Participantes del Reparto
  // ===========================================================================

  Widget _buildParticipantesSelectorBar(BuildContext context) {
    final controller = widget.controller;
    final participantes = controller.participantesIds;
    final todosSeleccionados =
        participantes.length == widget.miembros.length && widget.miembros.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PARTICIPANTES EN EL REPARTO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${participantes.length}/${widget.miembros.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryLiquid,
                  ),
                ),
              ),
              const Spacer(),
              // Botón rápido para alternar Todos / Ninguno
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (todosSeleccionados) {
                    controller.deseleccionarTodosLosParticipantes();
                  } else {
                    controller.seleccionarTodosLosParticipantes(
                      widget.miembros.map((m) => m.userId).toList(),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Text(
                    todosSeleccionados ? 'Deseleccionar todos' : 'Seleccionar todos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLiquid,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.miembros.map((miembro) {
                final isParticipando = participantes.contains(miembro.userId);
                final minutos =
                    controller.getMinutosUsuarioEnReparto(miembro.userId);

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: isParticipando
                        ? 'Pulsar para deseleccionar a ${miembro.username}'
                        : 'Pulsar para incluir a ${miembro.username}',
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.toggleParticipante(miembro.userId);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isParticipando ? 1.0 : 0.6,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isParticipando
                                ? AppTheme.primaryLiquid.withValues(alpha: 0.16)
                                : AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isParticipando
                                  ? AppTheme.primaryLiquid
                                  : AppTheme.cardBorderColor.withValues(alpha: 0.5),
                              width: isParticipando ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isParticipando
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color: isParticipando
                                    ? AppTheme.primaryLiquid
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              UserAvatar(
                                avatarData: miembro.avatarData,
                                username: miembro.username,
                                size: 22,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                miembro.username,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isParticipando
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isParticipando
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              if (isParticipando) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.actionGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${minutos}m',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
    );
  }

  // ===========================================================================
  // Barra Superior: Botón de Reparto Automático y Toggle de Selección de Tareas
  // ===========================================================================

  Widget _buildActionHeader(BuildContext context) {
    final controller = widget.controller;
    final pendientes = controller.tareasPendientes;
    final seleccionadas = controller.tareasSeleccionadasIds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          // Botón principal de Reparto Greedy Automático
          Expanded(
            child: InkWell(
              onTap: controller.isRepartoLoading
                  ? null
                  : () => controller.ejecutarRepartoAutomatico(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.actionGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.clayRaisedShadows(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (controller.isRepartoLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      controller.isRepartoLoading
                          ? 'Calculando...'
                          : 'Reparto automático balanceado',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón toggle para desplegar selección de tareas
          AppContainer(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            baseColor: AppTheme.surfaceDark,
            onTap: () {
              setState(() {
                _mostrarSelectorTareas = !_mostrarSelectorTareas;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: seleccionadas.isNotEmpty
                      ? AppTheme.primaryLiquid
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  seleccionadas.isEmpty
                      ? '${pendientes.length}'
                      : '${seleccionadas.length}/${pendientes.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: seleccionadas.isNotEmpty
                        ? AppTheme.primaryLiquid
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Panel Plegable para Filtrar qué Tareas Participan en el Reparto
  // ===========================================================================

  Widget _buildTareasSelectorPanel(BuildContext context) {
    final pendientes = widget.controller.tareasPendientes;
    final seleccionadas = widget.controller.tareasSeleccionadasIds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: AppContainer(
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        baseColor: AppTheme.surfaceDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seleccionar tareas a repartir:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed:
                    widget.controller.seleccionarTodasLasTareasReparto,
                child: Text(
                  seleccionadas.length == pendientes.length
                      ? 'Deseleccionar todas'
                      : 'Todas (${pendientes.length})',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryLiquid,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pendientes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tarea = pendientes[index];
                final isSelected = seleccionadas.contains(tarea.id);

                return InkWell(
                  onTap: () => widget.controller
                      .toggleTareaSeleccionadaReparto(tarea.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? AppTheme.primaryLiquid.withValues(alpha: 0.15)
                          : AppTheme.textSecondary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryLiquid
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tarea.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${tarea.tiempoEstimadoMinutos} min',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryLiquid,
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 16,
                              color: isSelected
                                  ? AppTheme.primaryLiquid
                                  : AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  // ===========================================================================
  // Columnas Kanban con DragTarget y Draggables
  // ===========================================================================

  Widget _buildBoardColumns(BuildContext context) {
    final controller = widget.controller;
    final participantes = controller.participantesIds;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 85.0),
      itemCount: participantes.length,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final userId = participantes[index];
        final miembro = _getMiembro(userId);
        final minutosTotales =
            controller.getMinutosUsuarioEnReparto(userId);
        final tareasUsuario =
            controller.getTareasDeUsuarioEnReparto(userId);

        return _buildUserColumn(
          context: context,
          userId: userId,
          miembro: miembro,
          minutosTotales: minutosTotales,
          tareas: tareasUsuario,
        );
      },
    );
  }

  Widget _buildUserColumn({
    required BuildContext context,
    required String userId,
    required EnvironmentMemberModel? miembro,
    required int minutosTotales,
    required List<TareaModel> tareas,
  }) {
    final nombre = miembro?.username ?? 'Usuario ${userId.substring(0, 4)}';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.clayRaisedShadows(),
        border: Border.all(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Cabecera de la columna con nombre, avatar y contador dinámico
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                if (miembro != null)
                  UserAvatar(
                    avatarData: miembro.avatarData,
                    username: miembro.username,
                    size: 34,
                  )
                else
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.primaryLiquid.withValues(alpha: 0.2),
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLiquid,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${tareas.length} ${tareas.length == 1 ? 'tarea' : 'tareas'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contador dinámico en tiempo real
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppTheme.actionGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$minutosTotales min',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Área DragTarget interactiva para soltar tareas
          Expanded(
            child: DragTarget<TareaModel>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) {
                widget.controller
                    .moverTareaEnReparto(details.data.id, userId);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isHovering
                        ? AppTheme.primaryLiquid.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isHovering
                        ? Border.all(color: AppTheme.primaryLiquid, width: 2)
                        : null,
                  ),
                  child: tareas.isEmpty
                      ? Center(
                          child: Text(
                            isHovering ? '¡Suelta aquí!' : 'Sin tareas asignadas\nArrastra aquí',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isHovering
                                  ? AppTheme.primaryLiquid
                                  : AppTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(6.0),
                          itemCount: tareas.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tarea = tareas[index];
                            return _buildDraggableTareaCard(context, tarea);
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tarjeta Draggable de Tarea
  // ===========================================================================

  Widget _buildDraggableTareaCard(BuildContext context, TareaModel tarea) {
    final controller = widget.controller;
    final currentAsignado =
        controller.repartoAsignaciones[tarea.id] ?? tarea.asignadoA;
    final otrosParticipantes = controller.participantesIds
        .where((uid) => uid != currentAsignado)
        .toList();

    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        gradient: AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cardBorderColor.withValues(alpha: 0.85),
          width: 1.0,
        ),
        boxShadow: AppTheme.clayRaisedShadows(),
      ),
      child: Row(
        children: [
          Icon(
            Icons.drag_indicator_rounded,
            size: 18,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tarea.titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Clay pill para minutos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              gradient: AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryLiquid.withValues(alpha: 0.3),
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
              '${tarea.tiempoEstimadoMinutos}m',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryLiquid,
              ),
            ),
          ),
          if (otrosParticipantes.isNotEmpty) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              tooltip: 'Reasignar a...',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxWidth: 200),
              color: AppTheme.surfaceDark,
              onSelected: (nuevoUsuarioId) {
                HapticFeedback.selectionClick();
                controller.moverTareaEnReparto(tarea.id, nuevoUsuarioId);
              },
              itemBuilder: (context) {
                return otrosParticipantes.map((uid) {
                  final m = _getMiembro(uid);
                  final name = m?.username ??
                      'Usuario ${uid.length >= 4 ? uid.substring(0, 4) : uid}';
                  return PopupMenuItem<String>(
                    value: uid,
                    height: 40,
                    child: Row(
                      children: [
                        if (m != null)
                          UserAvatar(
                            avatarData: m.avatarData,
                            username: m.username,
                            size: 20,
                          )
                        else
                          const Icon(Icons.person, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          ],
        ],
      ),
    );

    return LongPressDraggable<TareaModel>(
      data: tarea,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 240,
          child: Opacity(
            opacity: 0.9,
            child: cardContent,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: cardContent,
      ),
      child: cardContent,
    );
  }

  // ===========================================================================
  // Barra Inferior de Confirmación y Persistencia
  // ===========================================================================

  Widget _buildBottomConfirmationBar(BuildContext context) {
    final controller = widget.controller;
    final totalAsignadas = controller.repartoAsignaciones.length;

    if (totalAsignadas == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(
            color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reparto listo para aplicar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$totalAsignadas tareas distribuidas',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: controller.isRepartoLoading
                ? null
                : () => controller.confirmarRepartoFinal(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text(
              'Guardar y Aplicar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinParticipantes(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 52,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No hay miembros participantes seleccionados',
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
}
