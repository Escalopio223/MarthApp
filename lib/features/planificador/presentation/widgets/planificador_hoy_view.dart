import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../domain/models/etiqueta_tarea.dart';
import '../../domain/models/evento_model.dart';
import '../../domain/models/tarea_model.dart';
import '../controllers/planificador_controller.dart';
import 'crear_tarea_rapida_dialog.dart';
import 'editar_evento_dialog.dart';
import 'editar_tarea_dialog.dart';

/// Vista principal "Hoy" para el módulo Planificador:
/// - Feed vertical scrolleable enfocado en: "¿Qué hay que hacer hoy y quién lo hace?"
/// - Alertas críticas superiores: Cumpleaños próximos con ideas de regalo y eventos con hora fija
/// - Carrusel horizontal de plantillas habituales del hogar para añadir con 1 solo toque
/// - Filtros ágiles mediante chips: "Mis tareas" vs "Todas" y por etiquetas del hogar
/// - Agrupación visual por etiquetas para mantener todo ordenado
/// - Checkbox atómico de 1 toque con tachado optimista inmediato sin recarga de pantalla
/// - Botón flotante para creación rápida de tareas en < 5 segundos
class PlanificadorHoyView extends StatelessWidget {
  final PlanificadorController controller;
  final List<EnvironmentMemberModel> miembros;
  final String? usuarioActualId;
  final VoidCallback? onIrAPlanificacion;

  const PlanificadorHoyView({
    super.key,
    required this.controller,
    this.miembros = const [],
    this.usuarioActualId,
    this.onIrAPlanificacion,
  });

  @override
  Widget build(BuildContext context) {
    final alertas = controller.alertasCriticasHoy;
    final tareas = controller.tareasDeHoy;
    final filtroActivo = controller.filtroUsuarioId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          final envId = controller.entornoId;
          if (envId != null) {
            controller.setEntorno(envId);
          }
        },
        color: AppTheme.primaryLiquid,
        backgroundColor: AppTheme.surfaceDark,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // 1. Alertas Críticas Superiores (Cumpleaños y eventos fijados hoy)
            if (alertas.isNotEmpty) ...[
              _buildAlertasCriticasSection(context, alertas),
              const SizedBox(height: 16),
            ],

            // 2. Carrusel de Rutinas Habituales del Hogar (1 toque)
            _buildPlantillasHabitualesSection(context),
            const SizedBox(height: 16),

            // 3. Barra de Filtro Rápido (Mis tareas vs Todas y Etiquetas)
            _buildFiltrosChipsSection(context, filtroActivo),
            const SizedBox(height: 14),

            // 4. Feed de Tareas de Hoy (Agrupadas o planas)
            if (tareas.isEmpty)
              _buildEmptyState(context)
            else if (controller.agruparPorEtiqueta)
              ..._buildTareasAgrupadas(context)
            else
              ...tareas.map((tarea) => _buildTareaHoyItem(context, tarea)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryLiquid,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Tarea rápida',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => CrearTareaRapidaDialog.show(
          context,
          controller: controller,
          miembros: miembros,
          usuarioActualId: usuarioActualId,
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Alertas Críticas Superiores
  // ===========================================================================

  Widget _buildAlertasCriticasSection(
    BuildContext context,
    List<EventoModel> alertas,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: alertas.map((evento) {
        if (evento.esCumpleanos) {
          final dias = evento.diasParaCumpleanos;
          final String subtitulo = dias == 0
              ? '¡HOY ES SU CUMPLEAÑOS! 🎂'
              : (dias == 1 ? '¡Mañana es su cumpleaños!' : 'En $dias días');

          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              EditarEventoDialog.show(
                context,
                evento: evento,
                controller: controller,
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentCoral,
                    AppTheme.accentCoral.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentCoral.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cake_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subtitulo.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              evento.personaCumpleanos ?? evento.titulo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (evento.ideasRegalo != null &&
                                evento.ideasRegalo!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.card_giftcard_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        evento.ideasRegalo!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  if (evento.checklist.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: evento.checklist.map((item) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.toggleEventoChecklistItem(evento.id, item.id);
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
                                      color: item.completado ? Colors.white : Colors.transparent,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: item.completado
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: AppTheme.accentCoral,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.titulo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: item.completado ? FontWeight.normal : FontWeight.w500,
                                        decoration: item.completado ? TextDecoration.lineThrough : null,
                                        decorationColor: Colors.white70,
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
                  ],
                ],
              ),
            ),
          );
        }

        // Evento general fijado para hoy (ej. "Ir al médico")
        final hora = evento.esTodoElDia
            ? 'Todo el día'
            : '${evento.fechaInicio.hour.toString().padLeft(2, '0')}:${evento.fechaInicio.minute.toString().padLeft(2, '0')}';

        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            EditarEventoDialog.show(
              context,
              evento: evento,
              controller: controller,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.secondaryAccent.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: AppTheme.secondaryAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evento.titulo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (evento.descripcion != null &&
                              evento.descripcion!.isNotEmpty)
                            Text(
                              evento.descripcion!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (evento.checklist.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${evento.checklistItemsCompletados}/${evento.checklistItemsTotales}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryAccent,
                          ),
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hora,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                // Checklist interactivo directamente en la tarjeta del evento
                if (evento.checklist.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.secondaryAccent.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUBTAREAS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppTheme.secondaryAccent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...evento.checklist.map((item) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.toggleEventoChecklistItem(evento.id, item.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 19,
                                    height: 19,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: item.completado
                                          ? AppTheme.accentEmerald
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: item.completado
                                            ? AppTheme.accentEmerald
                                            : AppTheme.secondaryAccent.withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: item.completado
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.titulo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: item.completado ? FontWeight.normal : FontWeight.w500,
                                        color: item.completado
                                            ? AppTheme.textSecondary.withValues(alpha: 0.5)
                                            : AppTheme.textPrimary,
                                        decoration: item.completado
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        decorationColor: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // 2. Carrusel de Rutinas Habituales del Hogar (1 toque)
  // ===========================================================================

  Widget _buildPlantillasHabitualesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RUTINAS HABITUALES (1 TOQUE)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppTheme.textSecondary,
              ),
            ),
            if (onIrAPlanificacion != null)
              GestureDetector(
                onTap: onIrAPlanificacion,
                child: Text(
                  'Ver planificación →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryLiquid,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PlanificadorController.plantillasHabituales.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final plantilla =
                  PlanificadorController.plantillasHabituales[index];
              return _buildPlantillaChip(context, plantilla);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlantillaChip(BuildContext context, PlantillaTarea plantilla) {
    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        await controller.crearTareaDesdePlantilla(
          plantilla,
          asignadoA: usuarioActualId,
          fechaLimite: DateTime.now(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Añadida: ${plantilla.titulo} para hoy'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.surfaceDark,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
          boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              plantilla.icono,
              size: 15,
              color: AppTheme.primaryLiquid,
            ),
            const SizedBox(width: 6),
            Text(
              plantilla.titulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.add_rounded,
              size: 14,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. Barra de Filtro Rápido
  // ===========================================================================

  Widget _buildFiltrosChipsSection(
    BuildContext context,
    String? filtroActivo,
  ) {
    final misTareasCount = controller.tareasPendientesHoyCount;
    final esMisTareas =
        filtroActivo != null && filtroActivo == usuarioActualId;
    final esTodas = filtroActivo == null;
    final etiquetaActiva = controller.filtroEtiqueta;
    final estaAgrupado = controller.agruparPorEtiqueta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Filtro por Responsable / Mis tareas + Botón toggle para ordenar/agrupar por etiquetas
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Chip "Mis tareas"
                    _buildFilterChip(
                      label: 'Mis tareas',
                      count: esMisTareas ? misTareasCount : null,
                      isSelected: esMisTareas,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (esMisTareas) {
                          controller.setFiltroUsuario(null);
                        } else {
                          controller.setFiltroUsuario(usuarioActualId);
                        }
                      },
                    ),
                    const SizedBox(width: 8),

                    // Chip "Todas"
                    _buildFilterChip(
                      label: 'Todas',
                      isSelected: esTodas,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.setFiltroUsuario(null);
                      },
                    ),

                    // Chips individuales de convivientes (si hay más miembros)
                    if (miembros.length > 1) ...[
                      const SizedBox(width: 8),
                      ...miembros.map((m) {
                        if (m.userId == usuarioActualId) return const SizedBox.shrink();
                        final isSelected = filtroActivo == m.userId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildFilterChip(
                            label: m.username,
                            isSelected: isSelected,
                            avatarData: m.avatarData,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (isSelected) {
                                controller.setFiltroUsuario(null);
                              } else {
                                controller.setFiltroUsuario(m.userId);
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botón Agrupar / Ordenar por etiquetas
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.toggleAgruparPorEtiqueta();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: estaAgrupado
                      ? AppTheme.primaryLiquid.withValues(alpha: 0.18)
                      : AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: estaAgrupado
                        ? AppTheme.primaryLiquid
                        : AppTheme.cardBorderColor,
                    width: estaAgrupado ? 1.4 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      estaAgrupado
                          ? Icons.view_agenda_rounded
                          : Icons.grid_view_rounded,
                      size: 14,
                      color: estaAgrupado
                          ? AppTheme.primaryLiquid
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Agrupar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: estaAgrupado ? FontWeight.bold : FontWeight.w500,
                        color: estaAgrupado
                            ? AppTheme.primaryLiquid
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Fila 2: Filtro rápido por Etiquetas
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTagFilterChip(
                label: 'Todas las etiquetas',
                icono: Icons.label_outline_rounded,
                color: AppTheme.primaryLiquid,
                isSelected: etiquetaActiva == null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.setFiltroEtiqueta(null);
                },
              ),
              const SizedBox(width: 8),
              ...EtiquetaTarea.etiquetasPredeterminadas.map((e) {
                final isSelected =
                    etiquetaActiva?.toLowerCase() == e.nombre.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildTagFilterChip(
                    label: e.nombre,
                    icono: e.icono,
                    color: e.color,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (isSelected) {
                        controller.setFiltroEtiqueta(null);
                      } else {
                        controller.setFiltroEtiqueta(e.nombre);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    int? count,
    required bool isSelected,
    AvatarData? avatarData,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLiquid.withValues(alpha: 0.16)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLiquid : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarData != null) ...[
              UserAvatar(
                avatarData: avatarData,
                username: label,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryLiquid : AppTheme.textSecondary,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLiquid,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilterChip({
    required String label,
    required IconData icono,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorderColor,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 13,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTareasAgrupadas(BuildContext context) {
    final agrupadas = controller.tareasDeHoyAgrupadasPorEtiqueta;
    final List<Widget> items = [];

    for (final entry in agrupadas.entries) {
      final tagNombre = entry.key;
      final listaTareas = entry.value;
      final etiqueta =
          EtiquetaTarea.buscar(tagNombre == 'Sin etiqueta' ? null : tagNombre);
      final color = etiqueta?.color ?? AppTheme.textSecondary;
      final icono = etiqueta?.icono ?? Icons.label_off_outlined;

      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                tagNombre.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${listaTareas.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      );

      for (final tarea in listaTareas) {
        items.add(_buildTareaHoyItem(context, tarea));
      }
    }

    return items;
  }

  // ===========================================================================
  // 4. Ítem de Tarea de Hoy con Checkbox Atómico
  // ===========================================================================

  Widget _buildTareaHoyItem(BuildContext context, TareaModel tarea) {
    final isDone = tarea.estado == 'completada';
    final etiqueta = EtiquetaTarea.buscar(tarea.etiqueta);
    final responsable = miembros.firstWhere(
      (m) => m.userId == tarea.asignadoA,
      orElse: () => EnvironmentMemberModel(
        environmentId: '',
        userId: tarea.asignadoA ?? '',
        role: 'member',
        joinedAt: DateTime.now(),
        username: 'Sin asignar',
        avatarData: const AvatarData.initials(),
      ),
    );

    final cardRadius = BorderRadius.circular(20);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        gradient: isDone
            ? null
            : AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
        borderRadius: cardRadius,
        border: Border.all(
          color: isDone
              ? AppTheme.accentEmerald.withValues(alpha: 0.25)
              : AppTheme.cardBorderColor.withValues(alpha: 0.85),
          width: 1.0,
        ),
        boxShadow: isDone
            ? AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark, isPressed: true)
            : AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        child: InkWell(
          borderRadius: cardRadius,
          onTap: () {
            HapticFeedback.lightImpact();
            EditarTareaDialog.show(
              context,
              tarea: tarea,
              controller: controller,
              miembros: miembros,
              usuarioActualId: usuarioActualId,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Checkbox Clay + Título + Avatar Responsable + Menú
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox Claymórfico Táctil 3D
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.toggleTarea(tarea.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isDone
                                ? AppTheme.liquidEmeraldGradient
                                : AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
                            border: Border.all(
                              color: isDone
                                  ? AppTheme.accentEmerald
                                  : AppTheme.cardBorderColor.withValues(alpha: 0.9),
                              width: isDone ? 1.0 : 1.4,
                            ),
                            boxShadow: isDone
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentEmerald.withValues(alpha: 0.45),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                    ...AppTheme.clayRaisedShadows(baseColor: AppTheme.accentEmerald, isPressed: true),
                                  ]
                                : AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark, isPressed: false),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  )
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.textSecondary.withValues(alpha: 0.22),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Título de la tarea
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                              color: isDone
                                  ? AppTheme.textSecondary.withValues(alpha: 0.45)
                                  : AppTheme.textPrimary,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppTheme.textSecondary,
                              height: 1.25,
                            ),
                            child: Text(
                              tarea.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tarea.descripcion != null &&
                              tarea.descripcion!.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              tarea.descripcion!.trim(),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Avatar del Responsable (con aro y relieve clay)
                    if (tarea.asignadoA != null) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Responsable: ${responsable.username}',
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
                            border: Border.all(
                              color: AppTheme.primaryLiquid.withValues(alpha: 0.5),
                              width: 1.4,
                            ),
                            boxShadow: AppTheme.clayRaisedShadows(baseColor: AppTheme.surfaceDark),
                          ),
                          child: UserAvatar(
                            avatarData: responsable.avatarData,
                            username: responsable.username,
                            size: 26,
                          ),
                        ),
                      ),
                    ],

                    // Menú de opciones (tres puntos)
                    _buildTareaOptionsMenu(context, tarea),
                  ],
                ),

                // Fila de Pastillas / Badges de Metadata en Wrap adaptable
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Badge Responsable
                    _buildClayMetaPill(
                      icon: tarea.asignadoA != null ? null : Icons.person_outline_rounded,
                      customLeading: tarea.asignadoA != null
                          ? UserAvatar(
                              avatarData: responsable.avatarData,
                              username: responsable.username,
                              size: 13,
                            )
                          : null,
                      label: tarea.asignadoA == null
                          ? 'Sin asignar'
                          : (tarea.asignadoA == usuarioActualId ? 'Tú' : responsable.username),
                      accentColor: tarea.asignadoA != null
                          ? AppTheme.secondaryAccent
                          : AppTheme.textSecondary,
                    ),

                    // Badge Tiempo Estimado
                    if (tarea.tiempoEstimadoMinutos > 0)
                      _buildClayMetaPill(
                        icon: Icons.schedule_rounded,
                        label: '${tarea.tiempoEstimadoMinutos} min',
                        accentColor: AppTheme.textSecondary,
                      ),

                    // Badge Categoría / Etiqueta
                    if (etiqueta != null)
                      _buildClayMetaPill(
                        icon: etiqueta.icono,
                        label: etiqueta.nombre,
                        accentColor: etiqueta.color,
                      ),

                    // Badge Proyecto
                    if (tarea.proyectoId != null)
                      _buildClayMetaPill(
                        icon: Icons.folder_outlined,
                        label: 'Proyecto',
                        accentColor: AppTheme.primaryLiquid,
                      ),

                    // Badge Checklist Counter
                    if (tarea.checklist.isNotEmpty)
                      _buildClayMetaPill(
                        icon: Icons.checklist_rounded,
                        label: '${tarea.checklistItemsCompletados}/${tarea.checklistItemsTotales}',
                        accentColor: tarea.checklistItemsCompletados == tarea.checklistItemsTotales && tarea.checklistItemsTotales > 0
                            ? AppTheme.accentEmerald
                            : AppTheme.primaryLiquid,
                      ),

                    // Badge Comentarios Counter
                    if (tarea.comentarios.isNotEmpty)
                      _buildClayMetaPill(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${tarea.comentarios.length}',
                        accentColor: AppTheme.secondaryAccent,
                      ),
                  ],
                ),

                // Caja Hendida / Recessed Tray de Subtareas (Ancho completo del card)
                if (tarea.checklist.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.isDark
                          ? Color.alphaBlend(Colors.black.withValues(alpha: 0.35), AppTheme.surfaceDark)
                          : Color.alphaBlend(AppTheme.shadowDark.withValues(alpha: 0.12), AppTheme.surfaceDark),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.clayInsetShadows(),
                      border: Border.all(
                        color: AppTheme.cardBorderColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado de la bandeja de subtareas con micro barra de progreso
                        Row(
                          children: [
                            Icon(
                              Icons.checklist_rounded,
                              size: 13,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'SUBTAREAS (${tarea.checklistItemsCompletados}/${tarea.checklistItemsTotales})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            // Micro barra de progreso claymórfica
                            Container(
                              width: 54,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: AppTheme.cardBorderColor.withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: tarea.porcentajeProgreso.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.liquidEmeraldGradient,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(tarea.porcentajeProgreso * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tarea.porcentajeProgreso == 1.0
                                    ? AppTheme.accentEmerald
                                    : AppTheme.primaryLiquid,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Lista de subtareas interactivas
                        ...tarea.checklist.map((item) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.toggleChecklistItem(tarea.id, item.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  // Checkbox clay para subtarea
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 19,
                                    height: 19,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: item.completado
                                          ? AppTheme.liquidEmeraldGradient
                                          : AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
                                      border: Border.all(
                                        color: item.completado
                                            ? AppTheme.accentEmerald
                                            : AppTheme.cardBorderColor.withValues(alpha: 0.9),
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
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      item.titulo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: item.completado ? FontWeight.normal : FontWeight.w500,
                                        color: item.completado
                                            ? AppTheme.textSecondary.withValues(alpha: 0.45)
                                            : AppTheme.textPrimary,
                                        decoration: item.completado
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        decorationColor: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClayMetaPill({
    IconData? icon,
    Widget? customLeading,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        gradient: AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customLeading != null) ...[
            customLeading,
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: accentColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accentColor == AppTheme.textSecondary
                  ? AppTheme.textSecondary.withValues(alpha: 0.9)
                  : accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTareaOptionsMenu(BuildContext context, TareaModel tarea) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: AppTheme.textSecondary.withValues(alpha: 0.6),
      ),
      padding: EdgeInsets.zero,
      color: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorderColor),
      ),
      onSelected: (value) async {
        HapticFeedback.lightImpact();
        if (value == 'editar') {
          EditarTareaDialog.show(
            context,
            tarea: tarea,
            controller: controller,
            miembros: miembros,
            usuarioActualId: usuarioActualId,
          );
        } else if (value == 'eliminar') {
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(
                '¿Eliminar tarea?',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              content: Text(
                '¿Deseas eliminar "${tarea.titulo}"?',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCoral,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );

          if (confirmar == true) {
            await controller.eliminarTarea(tarea.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tarea eliminada'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'editar',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryLiquid),
              const SizedBox(width: 8),
              Text('Editar detalles', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'eliminar',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.accentCoral),
              const SizedBox(width: 8),
              Text('Eliminar tarea', style: TextStyle(color: AppTheme.accentCoral, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. Estado Vacío Cálido
  // ===========================================================================

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentEmerald.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: AppTheme.accentEmerald,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Todo listo por hoy en casa! 🎉',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay tareas pendientes en este filtro. Tómate un descanso o añade una tarea rápida con el botón flotante.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
