import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_container.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../../../profile/presentation/widgets/user_avatar.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../domain/models/agenda_item_model.dart';
import '../controllers/planificador_controller.dart';
import 'editar_evento_dialog.dart';
import 'editar_tarea_dialog.dart';

/// Vista de Agenda y Calendario interactivo (mensual y semanal)
/// con diferenciación gráfica clara entre eventos, cumpleaños y tareas con vencimiento.
class AgendaCalendarView extends StatelessWidget {
  final PlanificadorController controller;
  final List<EnvironmentMemberModel> miembros;
  final String? usuarioActualId;
  final VoidCallback? onCrearEvento;
  final VoidCallback? onCrearTarea;

  const AgendaCalendarView({
    super.key,
    required this.controller,
    this.miembros = const [],
    this.usuarioActualId,
    this.onCrearEvento,
    this.onCrearTarea,
  });

  static const List<String> _diasSemana = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom'
  ];

  static const List<String> _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCalendarHeader(context),
        const SizedBox(height: 8),
        _buildCalendarGrid(context),
        const SizedBox(height: 16),
        _buildSelectedDayHeader(context),
        const SizedBox(height: 8),
        Expanded(
          child: _buildItemsList(context),
        ),
      ],
    );
  }

  // ===========================================================================
  // Cabecera del Calendario: Mes, Año y Selector de Vista (Mensual/Semanal)
  // ===========================================================================

  Widget _buildCalendarHeader(BuildContext context) {
    final focused = controller.focusedMonth;
    final mesNombre = _meses[focused.month - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '$mesNombre ${focused.year}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              AppContainer(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                baseColor: AppTheme.surfaceDark,
                onTap: controller.toggleCalendarView,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      controller.isWeeklyView
                          ? Icons.view_week_rounded
                          : Icons.calendar_view_month_rounded,
                      size: 14,
                      color: AppTheme.primaryLiquid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      controller.isWeeklyView ? 'Semana' : 'Mes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLiquid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: controller.previousMonth,
              ),
              const SizedBox(width: 6),
              _buildNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: controller.nextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppContainer(
      borderRadius: 12,
      padding: const EdgeInsets.all(6),
      baseColor: AppTheme.surfaceDark,
      onTap: onTap,
      child: Icon(
        icon,
        size: 20,
        color: AppTheme.textPrimary,
      ),
    );
  }

  // ===========================================================================
  // Cuadrícula Interactiva (Días de la semana + Celdas de días)
  // ===========================================================================

  Widget _buildCalendarGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: AppContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(12.0),
        baseColor: AppTheme.surfaceDark,
        child: Column(
          children: [
          // Nombres de los días de la semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _diasSemana.map((dia) {
              return SizedBox(
                width: 38,
                child: Center(
                  child: Text(
                    dia,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Días del calendario
          controller.isWeeklyView
              ? _buildWeekDays(context)
              : _buildMonthDays(context),
        ],
      ),
    ),
  );
}

  Widget _buildMonthDays(BuildContext context) {
    final focused = controller.focusedMonth;
    final firstDayOfMonth = DateTime(focused.year, focused.month, 1);
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;

    // Offset de lunes (1 = lunes, 7 = domingo)
    final startWeekday = firstDayOfMonth.weekday;
    final int emptySlots = startWeekday - 1;

    final List<Widget> dayWidgets = [];

    // Celdas vacías antes del día 1
    for (int i = 0; i < emptySlots; i++) {
      dayWidgets.add(const SizedBox(width: 38, height: 38));
    }

    // Días del mes
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(focused.year, focused.month, day);
      dayWidgets.add(_buildDayCell(context, date));
    }

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 6,
      runSpacing: 6,
      children: dayWidgets,
    );
  }

  Widget _buildWeekDays(BuildContext context) {
    final selected = controller.selectedDate;
    final startOfWeek =
        selected.subtract(Duration(days: selected.weekday - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final date = startOfWeek.add(Duration(days: index));
        return _buildDayCell(context, date);
      }),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date) {
    final isSelected = controller.selectedDate.year == date.year &&
        controller.selectedDate.month == date.month &&
        controller.selectedDate.day == date.day;

    final now = DateTime.now();
    final isToday = now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;

    final hasItems = controller.diaTieneItems(date);

    return InkWell(
      onTap: () => controller.selectDate(date),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected ? AppTheme.actionGradient : null,
          color: isSelected
              ? null
              : (isToday
                  ? AppTheme.primaryLiquid.withValues(alpha: 0.12)
                  : Colors.transparent),
          border: isToday && !isSelected
              ? Border.all(color: AppTheme.primaryLiquid.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.ctaTextColor
                    : (isToday
                        ? AppTheme.primaryLiquid
                        : AppTheme.textPrimary),
              ),
            ),
            if (hasItems && !isSelected)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Lista de Items del Día Seleccionado
  // ===========================================================================

  Widget _buildSelectedDayHeader(BuildContext context) {
    final sel = controller.selectedDate;
    final mes = _meses[sel.month - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${sel.day} de $mes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Row(
            children: [
              if (onCrearTarea != null)
                _buildActionChip(
                  label: '+ Tarea',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.primaryLiquid,
                  onTap: onCrearTarea!,
                ),
              const SizedBox(width: 8),
              if (onCrearEvento != null)
                _buildActionChip(
                  label: '+ Evento',
                  icon: Icons.event_rounded,
                  color: AppTheme.secondaryAccent,
                  onTap: onCrearEvento!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(BuildContext context) {
    final items = controller.agendaItemsForSelectedDate;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay eventos ni tareas para este día',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 100.0),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildAgendaItemCard(context, item);
      },
    );
  }

  Widget _buildAgendaItemCard(BuildContext context, AgendaItemModel item) {
    if (item.esCumpleanos) {
      return _buildCumpleanosCard(context, item);
    } else if (item.esTarea) {
      return _buildTareaAgendaCard(context, item);
    } else {
      return _buildEventoGeneralCard(context, item);
    }
  }

  // ===========================================================================
  // Tarjetas Diferenciadas: Cumpleaños, Tarea y Evento General
  // ===========================================================================

  Widget _buildCumpleanosCard(BuildContext context, AgendaItemModel item) {
    final evento = item.eventoOriginal;

    return AppContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      baseColor: AppTheme.surfaceDark,
      onTap: evento != null
          ? () {
              HapticFeedback.lightImpact();
              EditarEventoDialog.show(
                context,
                evento: evento,
                controller: controller,
              );
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7E95), Color(0xFFFF5E7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCoral.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Cumpleaños',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentCoral,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.personaCumpleanos ?? item.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (item.ideasRegalo != null &&
                        item.ideasRegalo!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.card_giftcard_rounded,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Ideas: ${item.ideasRegalo}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (evento != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
            ],
          ),
          if (evento != null && evento.checklist.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: evento.checklist.map((chk) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.toggleEventoChecklistItem(evento.id, chk.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: chk.completado
                                  ? AppTheme.accentCoral
                                  : Colors.transparent,
                              border: Border.all(
                                color: chk.completado
                                    ? AppTheme.accentCoral
                                    : AppTheme.textSecondary.withValues(alpha: 0.5),
                                width: 1.4,
                              ),
                            ),
                            child: chk.completado
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              chk.titulo,
                              style: TextStyle(
                                fontSize: 12,
                                color: chk.completado
                                    ? AppTheme.textSecondary.withValues(alpha: 0.5)
                                    : AppTheme.textPrimary,
                                decoration: chk.completado
                                    ? TextDecoration.lineThrough
                                    : null,
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
    );
  }

  Widget _buildTareaAgendaCard(BuildContext context, AgendaItemModel item) {
    final tarea = item.tareaOriginal;
    final isDone = item.estaCompletada;
    final responsable = tarea?.asignadoA != null
        ? miembros.firstWhere(
            (m) => m.userId == tarea!.asignadoA,
            orElse: () => EnvironmentMemberModel(
              environmentId: '',
              userId: tarea!.asignadoA!,
              role: 'member',
              joinedAt: DateTime.now(),
              username: 'Sin asignar',
              avatarData: const AvatarData.initials(),
            ),
          )
        : null;

    final cardRadius = BorderRadius.circular(20);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          onTap: tarea != null
              ? () {
                  HapticFeedback.lightImpact();
                  EditarTareaDialog.show(
                    context,
                    tarea: tarea,
                    controller: controller,
                    miembros: miembros,
                    usuarioActualId: usuarioActualId,
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Checkbox Clay + Título + Avatar Responsable
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox Claymórfico Táctil 3D
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: tarea != null
                            ? () {
                                if (!isDone) {
                                  HapticFeedback.mediumImpact();
                                } else {
                                  HapticFeedback.lightImpact();
                                }
                                controller.toggleTarea(tarea.id);
                              }
                            : null,
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
                      child: Text(
                        item.titulo,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Avatar del Responsable si existe
                    if (responsable != null) ...[
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
                    if (responsable != null)
                      _buildAgendaClayMetaPill(
                        customLeading: UserAvatar(
                          avatarData: responsable.avatarData,
                          username: responsable.username,
                          size: 13,
                        ),
                        label: responsable.userId == usuarioActualId ? 'Tú' : responsable.username,
                        accentColor: AppTheme.secondaryAccent,
                      ),

                    // Badge Tiempo Estimado
                    if ((item.tiempoEstimadoMinutos ?? 0) > 0)
                      _buildAgendaClayMetaPill(
                        icon: Icons.schedule_rounded,
                        label: '~${item.tiempoEstimadoMinutos} min',
                        accentColor: AppTheme.textSecondary,
                      ),

                    // Badge Subtareas counter
                    if (tarea != null && tarea.checklist.isNotEmpty)
                      _buildAgendaClayMetaPill(
                        icon: Icons.checklist_rounded,
                        label: '${tarea.checklistItemsCompletados}/${tarea.checklistItemsTotales} subtareas',
                        accentColor: tarea.checklistItemsCompletados == tarea.checklistItemsTotales && tarea.checklistItemsTotales > 0
                            ? AppTheme.accentEmerald
                            : AppTheme.secondaryAccent,
                      ),

                    // Badge Comentarios Counter
                    if (tarea != null && tarea.comentarios.isNotEmpty)
                      _buildAgendaClayMetaPill(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${tarea.comentarios.length}',
                        accentColor: AppTheme.primaryLiquid,
                      ),
                  ],
                ),

                // Caja Hendida / Recessed Tray de Subtareas
                if (tarea != null && tarea.checklist.isNotEmpty) ...[
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
                        ...tarea.checklist.map((chk) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.toggleChecklistItem(tarea.id, chk.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  // Mini Checkbox clay
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 19,
                                    height: 19,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: chk.completado
                                          ? AppTheme.liquidEmeraldGradient
                                          : AppTheme.claySurfaceGradient(baseColor: AppTheme.surfaceDark),
                                      border: Border.all(
                                        color: chk.completado
                                            ? AppTheme.accentEmerald
                                            : AppTheme.cardBorderColor.withValues(alpha: 0.9),
                                        width: 1.2,
                                      ),
                                      boxShadow: chk.completado
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.accentEmerald.withValues(alpha: 0.35),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: chk.completado
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
                                      chk.titulo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: chk.completado ? FontWeight.normal : FontWeight.w500,
                                        color: chk.completado
                                            ? AppTheme.textSecondary.withValues(alpha: 0.45)
                                            : AppTheme.textPrimary,
                                        decoration: chk.completado
                                            ? TextDecoration.lineThrough
                                            : null,
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

  Widget _buildAgendaClayMetaPill({
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

  Widget _buildEventoGeneralCard(BuildContext context, AgendaItemModel item) {
    final evento = item.eventoOriginal;

    return AppContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      baseColor: AppTheme.surfaceDark,
      onTap: evento != null
          ? () {
              HapticFeedback.lightImpact();
              EditarEventoDialog.show(
                context,
                evento: evento,
                controller: controller,
              );
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  color: AppTheme.secondaryAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (item.descripcion != null &&
                        item.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.descripcion!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (evento != null && evento.checklist.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
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
          ),
          if (evento != null && evento.checklist.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: evento.checklist.map((chk) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.toggleEventoChecklistItem(evento.id, chk.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: chk.completado
                                  ? AppTheme.accentEmerald
                                  : Colors.transparent,
                              border: Border.all(
                                color: chk.completado
                                    ? AppTheme.accentEmerald
                                    : AppTheme.secondaryAccent.withValues(alpha: 0.5),
                                width: 1.4,
                              ),
                            ),
                            child: chk.completado
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              chk.titulo,
                              style: TextStyle(
                                fontSize: 12,
                                color: chk.completado
                                    ? AppTheme.textSecondary.withValues(alpha: 0.5)
                                    : AppTheme.textPrimary,
                                decoration: chk.completado
                                    ? TextDecoration.lineThrough
                                    : null,
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
    );
  }
}
