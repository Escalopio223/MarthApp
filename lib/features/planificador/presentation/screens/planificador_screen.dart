import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../environments/domain/models/environment_member_model.dart';
import '../../../environments/presentation/controllers/environment_controller.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/evento_model.dart';
import '../../domain/models/recordatorio_tarea_model.dart';
import '../../domain/models/tarea_model.dart';
import '../../domain/services/reparto_equitativo_service.dart';
import '../controllers/planificador_controller.dart';
import '../widgets/flat_calendar_header.dart';
import '../widgets/flat_create_item_sheet.dart';
import '../widgets/flat_event_card.dart';
import '../widgets/flat_reparto_preview_sheet.dart';
import '../widgets/flat_task_card.dart';

/// Pantalla Principal Unificada del Planificador (Flat Design 2.0):
/// - Cabecera de Calendario Dinámica (Semana ↔ Mes).
/// - Feed vertical continuo del día seleccionado:
///   1. Bloque Eventos / Citas destacadas (si existen).
///   2. Bloque Tareas Domésticas con checkbox rápido, chip de tiempo y avatar del responsable.
/// - Botón Flotante (+) con Modal Unificado de Creación.
class PlanificadorScreen extends StatefulWidget {
  final PlanificadorController? controller;
  final EnvironmentController? environmentController;
  final String? currentUserId;
  final bool asTab;

  const PlanificadorScreen({
    super.key,
    this.controller,
    this.environmentController,
    this.currentUserId,
    this.asTab = false,
  });

  @override
  State<PlanificadorScreen> createState() => _PlanificadorScreenState();
}

class _PlanificadorScreenState extends State<PlanificadorScreen> {
  late final PlanificadorController _controller;
  EnvironmentController? _environmentController;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];
  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  String? get _currentUserId {
    if (widget.currentUserId != null) return widget.currentUserId;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PlanificadorController();
    _controller.addListener(_onControllerChanged);

    _environmentController = widget.environmentController;
    _environmentController?.addListener(_onEnvironmentChanged);

    // Sincronizar entorno inicial
    final activeEnv = _environmentController?.activeEnvironment;
    if (activeEnv != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.setEntorno(activeEnv.id);
        _registrarTokenFcmSiExiste(activeEnv.id);
      });
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: AppTheme.accentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _controller.clearMessages();
    } else if (_controller.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.successMessage!),
          backgroundColor: AppTheme.accentEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _controller.clearMessages();
    }

    setState(() {});
  }

  void _onEnvironmentChanged() {
    final activeEnv = _environmentController?.activeEnvironment;
    if (activeEnv != null) {
      _controller.setEntorno(activeEnv.id);
      _registrarTokenFcmSiExiste(activeEnv.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _registrarTokenFcmSiExiste(String entornoId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _controller.registrarFcmToken(
          token,
          infoDispositivo: 'Flutter App',
        );
      }
    } catch (_) {
      // Ignorar silenciosamente si FCM no está disponible
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.removeListener(_onControllerChanged);
    _environmentController?.removeListener(_onEnvironmentChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  EnvironmentMemberModel? _findMember(String? userId) {
    if (userId == null) return null;
    final members = _environmentController?.activeMembers ?? const [];
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  String _formatHeaderDate(DateTime d) {
    final now = DateTime.now();
    final diaNombre = _diasSemana[d.weekday - 1];
    final mesNombre = _meses[d.month - 1];

    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hoy ($diaNombre, ${d.day} de $mesNombre)';
    }

    final tomorrow = now.add(const Duration(days: 1));
    if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
      return 'Mañana ($diaNombre, ${d.day} de $mesNombre)';
    }

    return '$diaNombre, ${d.day} de $mesNombre';
  }

  void _abrirModalCreacion(BuildContext context) {
    final members = _environmentController?.activeMembers ?? const [];

    FlatCreateItemSheet.show(
      context,
      defaultDate: _controller.selectedDate,
      miembros: members,
      currentUserId: _currentUserId,
      proyectos: _controller.proyectos,
      onCreateTask: ({
        required String titulo,
        DateTime? fechaLimite,
        String? asignadoA,
        int tiempoEstimadoMinutos = 15,
        String? proyectoId,
        String? descripcion,
        List<ChecklistItemModel> checklist = const [],
        List<RecordatorioTareaModel> recordatorios = const [],
      }) async {
        await _controller.crearTarea(
          titulo: titulo,
          fechaLimite: fechaLimite,
          asignadoA: asignadoA,
          tiempoEstimadoMinutos: tiempoEstimadoMinutos,
          proyectoId: proyectoId,
          descripcion: descripcion,
          checklist: checklist,
          recordatorios: recordatorios,
        );
      },
      onCreateEvent: ({
        required String titulo,
        required DateTime fechaInicio,
        DateTime? fechaFin,
        bool esTodoElDia = false,
        String tipo = 'evento_general',
        String? personaCumpleanos,
        String? ideasRegalo,
        List<ChecklistItemModel> checklist = const [],
        List<RecordatorioTareaModel> recordatorios = const [],
      }) async {
        await _controller.crearEvento(
          titulo: titulo,
          fechaInicio: fechaInicio,
          fechaFin: fechaFin,
          esTodoElDia: esTodoElDia,
          tipo: tipo,
          personaCumpleanos: personaCumpleanos,
          ideasRegalo: ideasRegalo,
          checklist: checklist,
          recordatorios: recordatorios,
        );
      },
    );
  }

  void _abrirModalEdicionTarea(TareaModel tarea) {
    final members = _environmentController?.activeMembers ?? const [];

    FlatCreateItemSheet.show(
      context,
      defaultDate: tarea.fechaLimite ?? _controller.selectedDate,
      miembros: members,
      currentUserId: _currentUserId,
      proyectos: _controller.proyectos,
      tareaToEdit: tarea,
      onDeleteTask: () async {
        await _controller.eliminarTarea(tarea.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tarea "${tarea.titulo}" eliminada'),
              backgroundColor: AppTheme.surfaceDark,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onCreateTask: ({
        required String titulo,
        DateTime? fechaLimite,
        String? asignadoA,
        int tiempoEstimadoMinutos = 15,
        String? proyectoId,
        String? descripcion,
        List<ChecklistItemModel> checklist = const [],
        List<RecordatorioTareaModel> recordatorios = const [],
      }) async {
        final tareaActualizada = tarea.copyWith(
          titulo: titulo,
          fechaLimite: fechaLimite,
          clearFechaLimite: fechaLimite == null,
          asignadoA: asignadoA,
          clearAsignadoA: asignadoA == null,
          tiempoEstimadoMinutos: tiempoEstimadoMinutos,
          proyectoId: proyectoId,
          clearProyectoId: proyectoId == null,
          descripcion: descripcion,
          clearDescripcion: descripcion == null,
          checklist: checklist,
          recordatorios: recordatorios,
          updatedAt: DateTime.now(),
        );
        await _controller.actualizarTarea(tareaActualizada);
      },
      onCreateEvent: ({
        required String titulo,
        required DateTime fechaInicio,
        DateTime? fechaFin,
        bool esTodoElDia = false,
        String tipo = 'evento_general',
        String? personaCumpleanos,
        String? ideasRegalo,
        List<ChecklistItemModel> checklist = const [],
        List<RecordatorioTareaModel> recordatorios = const [],
      }) async {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _controller.selectedDate;
    final isSearching = _searchQuery.trim().isNotEmpty;
    final queryLower = _searchQuery.trim().toLowerCase();

    // Filtrado de eventos y tareas si hay búsqueda activa o vista normal por día
    final eventosFiltrados = isSearching
        ? _controller.eventos.where((e) {
            final titulo = e.titulo.toLowerCase();
            final desc = (e.descripcion ?? '').toLowerCase();
            final persona = (e.personaCumpleanos ?? '').toLowerCase();
            return titulo.contains(queryLower) ||
                desc.contains(queryLower) ||
                persona.contains(queryLower);
          }).toList()
        : _controller.eventosForSelectedDate;

    final tareasFiltradas = isSearching
        ? _controller.tareas.where((t) {
            final titulo = t.titulo.toLowerCase();
            final desc = (t.descripcion ?? '').toLowerCase();
            return titulo.contains(queryLower) || desc.contains(queryLower);
          }).toList()
        : _controller.tareasForSelectedDate;

    final content = Column(
      children: [
        // 1. Cabecera de Calendario Dinámica (Semana ↔ Mes)
        FlatCalendarHeader(
          selectedDate: selectedDate,
          onDateSelected: (newDate) {
            _controller.selectDate(newDate);
          },
          hasItemsOnDate: (d) => _controller.diaTieneItems(d),
          onMonthChanged: (m) => _controller.setFocusedMonth(m),
        ),

        // 2. Buscador de tareas y eventos (Flat 2.0 justo debajo del calendario)
        _buildSearchBar(),

        // 3. Feed del Día Seleccionado o Resultados de Búsqueda
        Expanded(
          child: _controller.isLoading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : RefreshIndicator(
                  onRefresh: () => _controller.recargar(),
                  color: AppTheme.primaryAccent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
                    children: [
                      if (isSearching)
                        _buildSearchResultsHeader(
                          eventosCount: eventosFiltrados.length,
                          tareasCount: tareasFiltradas.length,
                        )
                      else ...[
                        // Subcabecera de fecha actual del feed
                        _buildFeedDateHeader(selectedDate),
                        const SizedBox(height: 12),
                      ],

                      // Bloque A: Eventos / Citas (Solo si existen)
                      if (eventosFiltrados.isNotEmpty) ...[
                        _buildSectionTitle(
                          title: isSearching ? 'Eventos encontrados' : 'Eventos y Citas',
                          count: eventosFiltrados.length,
                          icon: Icons.event_note_rounded,
                        ),
                        const SizedBox(height: 8),
                        ...eventosFiltrados.map(
                          (ev) => FlatEventCard(
                            evento: ev,
                            onDelete: () => _confirmarEliminarEvento(ev),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Bloque B: Tareas Domésticas
                      _buildSectionTitle(
                        title: isSearching ? 'Tareas encontradas' : 'Tareas del Día',
                        count: tareasFiltradas.length,
                        icon: Icons.checklist_rounded,
                        trailing: !isSearching && tareasFiltradas.isNotEmpty
                            ? InkWell(
                                onTap: () => _iniciarRepartoAutomatico(tareasFiltradas),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.primaryAccent.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_fix_high_rounded,
                                        size: 13,
                                        color: AppTheme.primaryAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Autoasignar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),

                      if (tareasFiltradas.isEmpty && eventosFiltrados.isEmpty)
                        isSearching
                            ? _buildSearchEmptyState()
                            : _buildEmptyState()
                      else if (tareasFiltradas.isEmpty)
                        _buildSinTareasState()
                      else
                        ...tareasFiltradas.map((t) {
                          final asignado = _findMember(t.asignadoA);
                          return FlatTaskCard(
                            tarea: t,
                            asignado: asignado,
                            onToggle: () => _controller.toggleTarea(t.id),
                            onTap: () => _abrirModalEdicionTarea(t),
                            onDelete: () => _controller.eliminarTarea(t.id),
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ],
    );

    final fab = FloatingActionButton(
      onPressed: () => _abrirModalCreacion(context),
      backgroundColor: AppTheme.primaryAccent,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(
        Icons.add_rounded,
        size: 28,
        color: Colors.white,
      ),
    );

    if (widget.asTab) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: content,
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Planificador',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: AppBackground(
        safeAreaTop: false,
        safeAreaBottom: false,
        child: content,
      ),
      floatingActionButton: fab,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppTheme.primaryAccent.withOpacity(0.5)
              : AppTheme.cardBorderColor.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar tareas, eventos, notas...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.5),
            fontSize: 12.5,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: _searchQuery.isNotEmpty
                ? AppTheme.primaryAccent
                : AppTheme.textSecondary.withOpacity(0.6),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: AppTheme.textSecondary,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );
  }

  Widget _buildSearchResultsHeader({
    required int eventosCount,
    required int tareasCount,
  }) {
    final total = eventosCount + tareasCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Resultados para "$_searchQuery"',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$total resultado${total == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cardBorderColor.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin resultados',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No se encontraron tareas ni eventos que coincidan con "$_searchQuery".',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.clear_rounded, size: 16),
            label: const Text('Limpiar búsqueda'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }

  void _iniciarRepartoAutomatico(List<TareaModel> tareasDelDia) {
    final members = _environmentController?.activeMembers ?? const [];
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay miembros en el espacio actual para balancear tareas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final tareasNoAsignadas = tareasDelDia.where((t) => t.asignadoA == null).toList();
    if (tareasNoAsignadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas las tareas de este día ya tienen un miembro asignado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Calcular la distribución propuesta usando el servicio de dominio (LPT Greedy)
    final resultado = RepartoEquitativoService.calcularRepartoEquitativo(
      tareas: tareasDelDia,
      miembros: members,
      balancearSoloNoAsignadas: true,
    );

    if (resultado.asignacionesFinales.isEmpty) return;

    FlatRepartoPreviewSheet.show(
      context,
      resultado: resultado,
      onConfirm: () async {
        final exito = await _controller.aplicarRepartoLote(
          asignacionesFinales: resultado.asignacionesFinales,
          usuariosParticipantes: members.map((m) => m.userId).toList(),
        );

        if (exito && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡${resultado.tareasNuevamenteRepartidas} tareas autoasignadas exitosamente!',
              ),
              backgroundColor: AppTheme.accentEmerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _buildFeedDateHeader(DateTime date) {
    return Row(
      children: [
        Text(
          _formatHeaderDate(date),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (_controller.tareasPendientesHoyCount > 0 &&
            PlanificadorController.isSameDay(date, DateTime.now()))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_controller.tareasPendientesHoyCount} pendientes',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required int count,
    required IconData icon,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.cardBorderColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.cardBorderColor.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.spa_rounded,
            size: 40,
            color: AppTheme.primaryAccent.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Día despejado',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay tareas ni eventos programados para esta fecha.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _abrirModalCreacion(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Añadir Tarea o Evento'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryAccent,
              side: BorderSide(color: AppTheme.primaryAccent.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinTareasState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Text(
        'Sin tareas pendientes para hoy',
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary.withOpacity(0.7),
        ),
      ),
    );
  }

  void _confirmarEliminarEvento(EventoModel evento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar Evento',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Text(
          '¿Deseas eliminar "${evento.titulo}"?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.eliminarEvento(evento.id);
            },
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.accentCoral),
            ),
          ),
        ],
      ),
    );
  }
}
