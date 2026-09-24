import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/agenda_item_model.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/comentario_tarea_model.dart';
import '../../domain/models/evento_model.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/recordatorio_tarea_model.dart';
import '../../domain/models/tarea_model.dart';
import '../../domain/repositories/i_planificador_repository.dart';
import '../../infrastructure/repositories/planificador_repository.dart';
import '../../../../core/services/local_notification_service.dart';

/// Plantilla predefinida para tareas habituales del hogar
class PlantillaTarea {
  final String id;
  final String titulo;
  final int tiempoMinutos;
  final IconData icono;
  final String categoria;

  const PlantillaTarea({
    required this.id,
    required this.titulo,
    this.tiempoMinutos = 15,
    required this.icono,
    required this.categoria,
  });
}

/// Controlador reactivo y gestor de estado para el módulo Planificador
class PlanificadorController extends ChangeNotifier {
  final IPlanificadorRepository _repository;

  String? _entornoId;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Plantillas de tareas habituales del hogar
  static const List<PlantillaTarea> plantillasHabituales = [
    PlantillaTarea(
      id: 'fregar_platos',
      titulo: 'Fregar platos',
      tiempoMinutos: 15,
      icono: Icons.soup_kitchen_rounded,
      categoria: 'Cocina',
    ),
    PlantillaTarea(
      id: 'poner_lavadora',
      titulo: 'Poner lavadora',
      tiempoMinutos: 15,
      icono: Icons.local_laundry_service_rounded,
      categoria: 'Limpieza',
    ),
    PlantillaTarea(
      id: 'bajar_basura',
      titulo: 'Bajar la basura',
      tiempoMinutos: 10,
      icono: Icons.delete_sweep_rounded,
      categoria: 'Limpieza',
    ),
    PlantillaTarea(
      id: 'barrer_suelo',
      titulo: 'Barrer el suelo',
      tiempoMinutos: 20,
      icono: Icons.cleaning_services_rounded,
      categoria: 'Limpieza',
    ),
    PlantillaTarea(
      id: 'hacer_compra',
      titulo: 'Hacer la compra',
      tiempoMinutos: 30,
      icono: Icons.shopping_cart_rounded,
      categoria: 'Compras',
    ),
    PlantillaTarea(
      id: 'pasear_mascota',
      titulo: 'Pasear a la mascota',
      tiempoMinutos: 20,
      icono: Icons.pets_rounded,
      categoria: 'Mascotas',
    ),
  ];

  // Colecciones de datos reactivas
  List<ProyectoModel> _proyectos = [];
  List<TareaModel> _tareas = [];
  List<EventoModel> _eventos = [];

  // Subscripciones a Streams
  StreamSubscription<List<ProyectoModel>>? _proyectosSub;
  StreamSubscription<List<TareaModel>>? _tareasSub;
  StreamSubscription<List<EventoModel>>? _eventosSub;
  bool _initialSyncDone = false;

  // Filtro de usuario en vista "Hoy" (null = todas, o userId)
  String? _filtroUsuarioId;

  // Filtro y ordenación por etiquetas en vista "Hoy"
  String? _filtroEtiqueta;
  bool _agruparPorEtiqueta = false;

  // Estado de la Agenda / Calendario
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  bool _isWeeklyView = false;

  // Estado del Tablero de Reparto (Drag & Drop)
  List<String> _participantesIds = [];
  bool _participantesPersonalizados = false;
  Set<String> _tareasSeleccionadasIds = {};
  final Map<String, String> _repartoAsignaciones = {}; // { tareaId: usuarioId }
  bool _isRepartoLoading = false;

  PlanificadorController({IPlanificadorRepository? repository})
      : _repository = repository ?? PlanificadorRepository();

  // ===========================================================================
  // Getters de Estado
  // ===========================================================================

  String? get entornoId => _entornoId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  List<ProyectoModel> get proyectos => List.unmodifiable(_proyectos);
  List<TareaModel> get tareas => List.unmodifiable(_tareas);
  List<EventoModel> get eventos => List.unmodifiable(_eventos);

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedMonth => _focusedMonth;
  bool get isWeeklyView => _isWeeklyView;

  List<String> get participantesIds => List.unmodifiable(_participantesIds);
  Set<String> get tareasSeleccionadasIds =>
      Set.unmodifiable(_tareasSeleccionadasIds);
  Map<String, String> get repartoAsignaciones =>
      Map.unmodifiable(_repartoAsignaciones);
  bool get isRepartoLoading => _isRepartoLoading;

  String? get filtroUsuarioId => _filtroUsuarioId;

  void setFiltroUsuario(String? userId) {
    if (_filtroUsuarioId == userId) return;
    _filtroUsuarioId = userId;
    notifyListeners();
  }

  String? get filtroEtiqueta => _filtroEtiqueta;
  bool get agruparPorEtiqueta => _agruparPorEtiqueta;

  void setFiltroEtiqueta(String? etiqueta) {
    if (_filtroEtiqueta == etiqueta) return;
    _filtroEtiqueta = etiqueta;
    notifyListeners();
  }

  void toggleAgruparPorEtiqueta() {
    _agruparPorEtiqueta = !_agruparPorEtiqueta;
    notifyListeners();
  }

  // ===========================================================================
  // Getters Específicos para la Vista "Hoy"
  // ===========================================================================

  /// Alertas críticas para el día actual: cumpleaños de hoy o en ≤3 días, y eventos fijados hoy
  List<EventoModel> get alertasCriticasHoy {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<EventoModel> alertas = [];
    for (final ev in _eventos) {
      if (ev.esCumpleanos) {
        final dias = ev.diasParaCumpleanos;
        if (dias != null && dias <= 3) {
          alertas.add(ev);
        }
      } else {
        final evDay = DateTime(
          ev.fechaInicio.year,
          ev.fechaInicio.month,
          ev.fechaInicio.day,
        );
        if (evDay.isAtSameMomentAs(today)) {
          alertas.add(ev);
        }
      }
    }
    return alertas;
  }

  /// Tareas de hoy (vencen hoy, atrasadas pendientes, o completadas hoy), aplicando el filtro de usuario
  List<TareaModel> get tareasDeHoy {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final candidatas = _tareas.where((t) {
      // 1. Tarea completada hoy
      if (t.completadaAt != null) {
        final compDate = DateTime(
          t.completadaAt!.year,
          t.completadaAt!.month,
          t.completadaAt!.day,
        );
        if (compDate.isAtSameMomentAs(today)) return true;
      }

      // 2. Tarea con fecha límite para hoy o atrasada pendiente
      if (t.fechaLimite != null) {
        final limite = DateTime(
          t.fechaLimite!.year,
          t.fechaLimite!.month,
          t.fechaLimite!.day,
        );
        if (limite.isAtSameMomentAs(today)) return true;
        if (limite.isBefore(today) && t.estado != 'completada') return true;
      }

      // 3. Tarea sin fecha creada hoy
      if (t.fechaLimite == null) {
        final created = DateTime(
          t.createdAt.year,
          t.createdAt.month,
          t.createdAt.day,
        );
        if (created.isAtSameMomentAs(today) && t.estado != 'completada') {
          return true;
        }
      }

      return false;
    }).toList();

    var filtradas = candidatas;

    // Aplicar filtro de usuario si está activo
    if (_filtroUsuarioId != null) {
      filtradas = filtradas.where((t) => t.asignadoA == _filtroUsuarioId).toList();
    }

    // Aplicar filtro de etiqueta si está activo
    if (_filtroEtiqueta != null) {
      filtradas = filtradas
          .where((t) =>
              t.etiqueta?.toLowerCase() == _filtroEtiqueta!.toLowerCase())
          .toList();
    }

    return filtradas;
  }

  /// Tareas de hoy organizadas por etiqueta (para ordenación/agrupación visual)
  Map<String, List<TareaModel>> get tareasDeHoyAgrupadasPorEtiqueta {
    final Map<String, List<TareaModel>> agrupadas = {};
    for (final t in tareasDeHoy) {
      final tag = t.etiqueta ?? 'Sin etiqueta';
      agrupadas.putIfAbsent(tag, () => []).add(t);
    }
    return agrupadas;
  }

  /// Conjunto de etiquetas actualmente presentes en las tareas del entorno
  List<String> get etiquetasDisponibles {
    final Set<String> tags = {};
    for (final t in _tareas) {
      final tag = t.etiqueta;
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag);
      }
    }
    return tags.toList()..sort();
  }

  /// Contador de tareas pendientes de hoy para el usuario filtrado o global
  int get tareasPendientesHoyCount =>
      tareasDeHoy.where((t) => t.estado != 'completada').length;

  // ===========================================================================
  // Getters Derivados y Filtros
  // ===========================================================================

  /// Tareas que no pertenecen a ningún proyecto (Backlog / Tareas Sueltas)
  List<TareaModel> get tareasSueltas =>
      _tareas.where((t) => t.proyectoId == null || t.proyectoId!.isEmpty).toList();

  /// Tareas pendientes para el reparto o asignación
  List<TareaModel> get tareasPendientes =>
      _tareas.where((t) => t.estado == 'pendiente').toList();

  /// Tareas asociadas a un proyecto específico
  List<TareaModel> getTareasPorProyecto(String proyectoId) =>
      _tareas.where((t) => t.proyectoId == proyectoId).toList();

  /// Items combinados para la fecha seleccionada en el calendario
  List<AgendaItemModel> get agendaItemsForSelectedDate {
    final List<AgendaItemModel> items = [];
    final selDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    for (final ev in _eventos) {
      final evLocal = ev.fechaInicio.toLocal();
      if (ev.esCumpleanos) {
        // Los cumpleaños coinciden por día y mes
        if (evLocal.month == selDay.month &&
            evLocal.day == selDay.day) {
          items.add(AgendaItemModel.fromEvento(ev));
        }
      } else {
        final evDay = DateTime(
            evLocal.year, evLocal.month, evLocal.day);
        if (evDay.isAtSameMomentAs(selDay)) {
          items.add(AgendaItemModel.fromEvento(ev));
        }
      }
    }

    for (final t in _tareas) {
      if (t.fechaLimite != null) {
        final tLocal = t.fechaLimite!.toLocal();
        final tDay = DateTime(
            tLocal.year, tLocal.month, tLocal.day);
        if (tDay.isAtSameMomentAs(selDay)) {
          items.add(AgendaItemModel.fromTarea(t));
        }
      }
    }

    items.sort();
    return items;
  }

  /// Verifica si un día dado tiene eventos o tareas asociadas (para pintar badges/puntos)
  bool diaTieneItems(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);

    final tieneEvento = _eventos.any((ev) {
      final evLocal = ev.fechaInicio.toLocal();
      if (ev.esCumpleanos) {
        return evLocal.month == d.month && evLocal.day == d.day;
      }
      final evD = DateTime(
          evLocal.year, evLocal.month, evLocal.day);
      return evD.isAtSameMomentAs(d);
    });

    if (tieneEvento) return true;

    return _tareas.any((t) {
      if (t.fechaLimite == null) return false;
      final tLocal = t.fechaLimite!.toLocal();
      final tD = DateTime(
          tLocal.year, tLocal.month, tLocal.day);
      return tD.isAtSameMomentAs(d);
    });
  }

  // ===========================================================================
  // Inicialización y Sincronización
  // ===========================================================================

  void setEntorno(String? newEntornoId) {
    if (newEntornoId == null || newEntornoId == _entornoId) return;
    _entornoId = newEntornoId;
    _errorMessage = null;
    _initialSyncDone = false;
    _participantesPersonalizados = false;
    _participantesIds = [];
    _tareasSeleccionadasIds.clear();
    _repartoAsignaciones.clear();
    _cancelSubscriptions();
    _subscribeToStreams(newEntornoId);
  }

  /// Fuerza la reconexión y recarga reactiva de los streams del entorno actual.
  Future<void> recargar() async {
    final id = _entornoId;
    if (id == null) return;
    _cancelSubscriptions();
    _subscribeToStreams(id);
  }

  void _cancelSubscriptions() {
    _proyectosSub?.cancel();
    _tareasSub?.cancel();
    _eventosSub?.cancel();
    _proyectosSub = null;
    _tareasSub = null;
    _eventosSub = null;
  }

  void _subscribeToStreams(String entornoId) {
    _isLoading = true;
    notifyListeners();

    try {
      _proyectosSub = _repository.streamProyectos(entornoId).listen(
        (proyectos) {
          _proyectos = proyectos;
          _isLoading = false;
          notifyListeners();
        },
        onError: (err) {
          debugPrint('[Planificador] Error en streamProyectos ($entornoId): $err');
          _isLoading = false;
          notifyListeners();
        },
      );

      _tareasSub = _repository.streamTareas(entornoId).listen(
        (tareas) {
          final prevTareasMap = {for (final t in _tareas) t.id: t};
          _tareas = tareas;
          _actualizarRepartoAlCambiarTareas();
          _isLoading = false;
          notifyListeners();

          if (_initialSyncDone) {
            _reaccionarRemotamenteATareas(prevTareasMap, tareas);
          } else {
            _checkInitialNotificationSync();
          }
        },
        onError: (err) {
          debugPrint('[Planificador] Error en streamTareas ($entornoId): $err');
          _isLoading = false;
          notifyListeners();
        },
      );

      _eventosSub = _repository.streamEventos(entornoId).listen(
        (eventos) {
          final prevEventosMap = {for (final e in _eventos) e.id: e};
          _eventos = eventos;
          _isLoading = false;
          notifyListeners();

          if (_initialSyncDone) {
            _reaccionarRemotamenteAEventos(prevEventosMap, eventos);
          } else {
            _checkInitialNotificationSync();
          }
        },
        onError: (err) {
          debugPrint('[Planificador] Error en streamEventos ($entornoId): $err');
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[Planificador] Error al iniciar suscripciones ($entornoId): $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // Control de Agenda y Calendario
  // ===========================================================================

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setFocusedMonth(DateTime month) {
    _focusedMonth = month;
    notifyListeners();
  }

  void toggleCalendarView() {
    _isWeeklyView = !_isWeeklyView;
    notifyListeners();
  }

  void previousMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    notifyListeners();
  }

  // ===========================================================================
  // Acciones de Tareas y Proyectos
  // ===========================================================================

  Future<void> toggleTarea(String tareaId) async {
    final tarea = _tareas.firstWhere((t) => t.id == tareaId);
    final nuevoEstado =
        tarea.estado == 'completada' ? 'pendiente' : 'completada';

    // Feedback háptico atómico: impacto medio al completar, ligero al desmarcar
    if (nuevoEstado == 'completada') {
      HapticFeedback.mediumImpact();
      unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeTarea(tareaId));
    } else {
      HapticFeedback.lightImpact();
      _reprogramarRecordatoriosDeTareaLocal(tarea.copyWith(estado: nuevoEstado));
    }

    // Optimistic UI update
    final index = _tareas.indexWhere((t) => t.id == tareaId);
    if (index != -1) {
      _tareas[index] = tarea.copyWith(estado: nuevoEstado);
      notifyListeners();
    }

    try {
      await _repository.cambiarEstadoTarea(tareaId, nuevoEstado);
    } catch (e) {
      _errorMessage = 'Error al actualizar tarea: $e';
      notifyListeners();
    }
  }

  Future<void> toggleChecklistItem(String tareaId, String itemId) async {
    HapticFeedback.lightImpact();
    // Optimistic UI update local inmediato
    final index = _tareas.indexWhere((t) => t.id == tareaId);
    if (index != -1) {
      final tarea = _tareas[index];
      final updatedChecklist = tarea.checklist.map((item) {
        if (item.id == itemId) {
          return item.copyWith(completado: !item.completado);
        }
        return item;
      }).toList();
      _tareas[index] = tarea.copyWith(checklist: updatedChecklist);
      notifyListeners();
    }

    try {
      await _repository.toggleChecklistItem(tareaId, itemId);
    } catch (e) {
      _errorMessage = 'Error al actualizar checklist: $e';
      notifyListeners();
    }
  }

  Future<ComentarioTareaModel?> agregarComentario({
    required String tareaId,
    required String texto,
    required String autorId,
    required String autorNombre,
  }) async {
    final cleanTexto = texto.trim();
    if (cleanTexto.isEmpty) return null;

    final comentario = ComentarioTareaModel(
      id: 'com_${DateTime.now().millisecondsSinceEpoch}',
      autorId: autorId,
      autorNombre: autorNombre,
      texto: cleanTexto,
      createdAt: DateTime.now(),
    );

    // Actualización optimista local inmediata
    final index = _tareas.indexWhere((t) => t.id == tareaId);
    final previousTarea = index != -1 ? _tareas[index] : null;
    if (index != -1) {
      final tarea = _tareas[index];
      _tareas[index] = tarea.copyWith(
        comentarios: [...tarea.comentarios, comentario],
      );
      notifyListeners();
    }

    try {
      await _repository.agregarComentarioTarea(
        tareaId: tareaId,
        comentario: comentario,
      );
      return comentario;
    } catch (e) {
      if (index != -1 && previousTarea != null) {
        _tareas[index] = previousTarea;
        notifyListeners();
      }
      _errorMessage = 'Error al agregar comentario: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleEventoChecklistItem(String eventoId, String itemId) async {
    HapticFeedback.lightImpact();
    // Optimistic UI update local inmediato
    final index = _eventos.indexWhere((e) => e.id == eventoId);
    if (index != -1) {
      final evento = _eventos[index];
      final updatedChecklist = evento.checklist.map((item) {
        if (item.id == itemId) {
          return item.copyWith(completado: !item.completado);
        }
        return item;
      }).toList();
      _eventos[index] = evento.copyWith(checklist: updatedChecklist);
      notifyListeners();
    }

    try {
      await _repository.toggleEventoChecklistItem(eventoId, itemId);
    } catch (e) {
      _errorMessage = 'Error al actualizar checklist de evento: $e';
      notifyListeners();
    }
  }

  Future<void> crearProyecto({
    required String nombre,
    String? descripcion,
    String icono = 'folder',
    String colorHex = '#6366F1',
  }) async {
    final envId = _entornoId;
    if (envId == null) return;
    try {
      final nuevoProyecto = await _repository.crearProyecto(
        entornoId: envId,
        nombre: nombre,
        descripcion: descripcion,
        icono: icono,
        colorHex: colorHex,
      );

      final exists = _proyectos.any((p) => p.id == nuevoProyecto.id);
      if (!exists) {
        _proyectos = [..._proyectos, nuevoProyecto];
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al crear proyecto: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> actualizarProyecto(ProyectoModel proyecto) async {
    final index = _proyectos.indexWhere((p) => p.id == proyecto.id);
    if (index != -1) {
      _proyectos[index] = proyecto;
      notifyListeners();
    }
    try {
      await _repository.actualizarProyecto(proyecto);
    } catch (e) {
      _errorMessage = 'Error al actualizar proyecto: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> eliminarProyecto(String proyectoId) async {
    _proyectos.removeWhere((p) => p.id == proyectoId);
    // Para las tareas asignadas a este proyecto, desasociarlas localmente
    _tareas = _tareas.map((t) {
      if (t.proyectoId == proyectoId) {
        return t.copyWith(clearProyectoId: true);
      }
      return t;
    }).toList();
    notifyListeners();

    try {
      await _repository.eliminarProyecto(proyectoId);
    } catch (e) {
      _errorMessage = 'Error al eliminar proyecto: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> crearTarea({
    String? proyectoId,
    required String titulo,
    String? descripcion,
    DateTime? fechaLimite,
    String? asignadoA,
    int tiempoEstimadoMinutos = 0,
    List<ChecklistItemModel> checklist = const [],
    List<RecordatorioTareaModel> recordatorios = const [],
  }) async {
    final envId = _entornoId;
    if (envId == null) {
      throw Exception('No hay ningún entorno activo seleccionado en el Planificador.');
    }
    try {
      final nuevaTarea = await _repository.crearTarea(
        entornoId: envId,
        proyectoId: proyectoId,
        titulo: titulo,
        descripcion: descripcion,
        fechaLimite: fechaLimite,
        asignadoA: asignadoA,
        tiempoEstimadoMinutos: tiempoEstimadoMinutos,
        checklist: checklist,
        recordatorios: recordatorios,
      );

      final exists = _tareas.any((t) => t.id == nuevaTarea.id);
      if (!exists) {
        _tareas = [nuevaTarea, ..._tareas];
        _actualizarRepartoAlCambiarTareas();
        _reprogramarRecordatoriosDeTareaLocal(nuevaTarea);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al crear tarea: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<List<RecordatorioTareaModel>> obtenerRecordatoriosTarea(String tareaId) {
    return _repository.obtenerRecordatoriosTarea(tareaId);
  }

  /// Crea una tarea instantáneamente a partir de una plantilla habitual (1 toque)
  Future<void> crearTareaDesdePlantilla(
    PlantillaTarea plantilla, {
    String? asignadoA,
    DateTime? fechaLimite,
  }) async {
    await crearTarea(
      titulo: plantilla.titulo,
      descripcion: plantilla.categoria,
      tiempoEstimadoMinutos: plantilla.tiempoMinutos,
      asignadoA: asignadoA,
      fechaLimite: fechaLimite ?? DateTime.now(),
    );
  }

  Future<void> actualizarTarea(TareaModel tarea) async {
    final index = _tareas.indexWhere((t) => t.id == tarea.id);
    final previousTarea = index != -1 ? _tareas[index] : null;

    if (index != -1) {
      _tareas[index] = tarea;
      notifyListeners();
    }

    _reprogramarRecordatoriosDeTareaLocal(tarea);

    try {
      await _repository.actualizarTarea(tarea);
    } catch (e) {
      if (index != -1 && previousTarea != null) {
        _tareas[index] = previousTarea;
        _reprogramarRecordatoriosDeTareaLocal(previousTarea);
        notifyListeners();
      }
      _errorMessage = 'Error al actualizar tarea: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> eliminarTarea(String tareaId) async {
    final index = _tareas.indexWhere((t) => t.id == tareaId);
    final previousTarea = index != -1 ? _tareas[index] : null;

    if (index != -1) {
      _tareas.removeAt(index);
      _actualizarRepartoAlCambiarTareas();
      notifyListeners();
    }

    unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeTarea(tareaId));

    try {
      await _repository.eliminarTarea(tareaId);
    } catch (e) {
      if (index != -1 && previousTarea != null) {
        _tareas.insert(index, previousTarea);
        _actualizarRepartoAlCambiarTareas();
        _reprogramarRecordatoriosDeTareaLocal(previousTarea);
        notifyListeners();
      }
      _errorMessage = 'Error al eliminar tarea: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> crearEvento({
    required String titulo,
    String? descripcion,
    required String tipo,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    bool esTodoElDia = false,
    String? personaCumpleanos,
    String? ideasRegalo,
    List<ChecklistItemModel> checklist = const [],
    List<RecordatorioTareaModel> recordatorios = const [],
  }) async {
    final envId = _entornoId;
    if (envId == null) return;
    try {
      final nuevoEvento = await _repository.crearEvento(
        entornoId: envId,
        titulo: titulo,
        descripcion: descripcion,
        tipo: tipo,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        esTodoElDia: esTodoElDia,
        personaCumpleanos: personaCumpleanos,
        ideasRegalo: ideasRegalo,
        checklist: checklist,
        recordatorios: recordatorios,
      );

      final exists = _eventos.any((e) => e.id == nuevoEvento.id);
      if (!exists) {
        _eventos = [..._eventos, nuevoEvento];
        _reprogramarRecordatoriosDeEventoLocal(nuevoEvento);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al crear evento: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> actualizarEvento(EventoModel evento) async {
    final index = _eventos.indexWhere((e) => e.id == evento.id);
    final previousEvento = index != -1 ? _eventos[index] : null;

    if (index != -1) {
      _eventos[index] = evento;
      notifyListeners();
    }

    _reprogramarRecordatoriosDeEventoLocal(evento);

    try {
      await _repository.actualizarEvento(evento);
    } catch (e) {
      if (index != -1 && previousEvento != null) {
        _eventos[index] = previousEvento;
        _reprogramarRecordatoriosDeEventoLocal(previousEvento);
        notifyListeners();
      }
      _errorMessage = 'Error al actualizar evento: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> eliminarEvento(String eventoId) async {
    final index = _eventos.indexWhere((e) => e.id == eventoId);
    final previousEvento = index != -1 ? _eventos[index] : null;

    if (index != -1) {
      _eventos.removeAt(index);
      notifyListeners();
    }

    unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeEvento(eventoId));

    try {
      await _repository.eliminarEvento(eventoId);
    } catch (e) {
      if (index != -1 && previousEvento != null) {
        _eventos.insert(index, previousEvento);
        _reprogramarRecordatoriosDeEventoLocal(previousEvento);
        notifyListeners();
      }
      _errorMessage = 'Error al eliminar evento: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ===========================================================================
  // Lógica del Tablero de Reparto (Drag & Drop)
  // ===========================================================================

  void setParticipantes(List<String> userIds) {
    _participantesIds = userIds;
    notifyListeners();
  }

  /// Sincroniza la lista de participantes con los miembros del entorno activo.
  /// Si la lista está vacía o contiene IDs inválidos de otro entorno, se actualiza automáticamente.
  /// Respeta las selecciones y deselecciones manuales del usuario.
  void sincronizarParticipantes(List<String> miembrosIds) {
    if (miembrosIds.isEmpty) return;

    final setMiembros = miembrosIds.toSet();
    final tieneInvalidos =
        _participantesIds.any((id) => !setMiembros.contains(id));

    if (tieneInvalidos) {
      _participantesIds.removeWhere((id) => !setMiembros.contains(id));
      if (_participantesIds.isEmpty) {
        _participantesIds = List.from(miembrosIds);
      }
      notifyListeners();
      return;
    }

    if (!_participantesPersonalizados) {
      if (_participantesIds.isEmpty ||
          _participantesIds.length != miembrosIds.length) {
        _participantesIds = List.from(miembrosIds);
        notifyListeners();
      }
    }
  }

  /// Alterna la selección/deselección de un miembro para el reparto de tareas.
  void toggleParticipante(String userId) {
    _participantesPersonalizados = true;
    if (_participantesIds.contains(userId)) {
      _participantesIds.remove(userId);
      // Reasignar tareas que estaban asignadas a este usuario al primer participante restante si hay alguno
      if (_participantesIds.isNotEmpty) {
        final nuevoResponsable = _participantesIds.first;
        for (final tareaId in _repartoAsignaciones.keys.toList()) {
          if (_repartoAsignaciones[tareaId] == userId) {
            _repartoAsignaciones[tareaId] = nuevoResponsable;
          }
        }
      }
    } else {
      _participantesIds.add(userId);
    }
    notifyListeners();
  }

  /// Selecciona todos los miembros para participar en el reparto
  void seleccionarTodosLosParticipantes(List<String> miembrosIds) {
    _participantesPersonalizados = true;
    _participantesIds = List.from(miembrosIds);
    notifyListeners();
  }

  /// Deselecciona todos los miembros para el reparto
  void deseleccionarTodosLosParticipantes() {
    _participantesPersonalizados = true;
    _participantesIds.clear();
    notifyListeners();
  }

  /// Inicializa automáticamente las tareas pendientes en el tablero de reparto si aún no hay ninguna seleccionada
  void inicializarTareasRepartoSiVacio() {
    final pendientes = tareasPendientes;
    if (_repartoAsignaciones.isEmpty &&
        _tareasSeleccionadasIds.isEmpty &&
        pendientes.isNotEmpty &&
        _participantesIds.isNotEmpty) {
      _tareasSeleccionadasIds = pendientes.map((t) => t.id).toSet();
      for (final t in pendientes) {
        if (t.asignadoA != null && _participantesIds.contains(t.asignadoA)) {
          _repartoAsignaciones[t.id] = t.asignadoA!;
        } else {
          _repartoAsignaciones[t.id] = _participantesIds.first;
        }
      }
      notifyListeners();
    }
  }

  void toggleTareaSeleccionadaReparto(String tareaId) {
    if (_tareasSeleccionadasIds.contains(tareaId)) {
      _tareasSeleccionadasIds.remove(tareaId);
      _repartoAsignaciones.remove(tareaId);
    } else {
      _tareasSeleccionadasIds.add(tareaId);
      // Asignar por defecto al primer participante si hay alguno
      if (_participantesIds.isNotEmpty) {
        final t = _tareas.firstWhere((item) => item.id == tareaId);
        _repartoAsignaciones[tareaId] =
            t.asignadoA ?? _participantesIds.first;
      }
    }
    notifyListeners();
  }

  void seleccionarTodasLasTareasReparto() {
    final pendientes = tareasPendientes;
    if (_tareasSeleccionadasIds.length == pendientes.length) {
      _tareasSeleccionadasIds.clear();
      _repartoAsignaciones.clear();
    } else {
      _tareasSeleccionadasIds = pendientes.map((t) => t.id).toSet();
      if (_participantesIds.isNotEmpty) {
        for (final t in pendientes) {
          _repartoAsignaciones[t.id] =
              t.asignadoA ?? _participantesIds.first;
        }
      }
    }
    notifyListeners();
  }

  /// Mueve una tarea a una nueva columna de usuario (Drag & Drop)
  void moverTareaEnReparto(String tareaId, String nuevoUsuarioId) {
    if (!_participantesIds.contains(nuevoUsuarioId)) return;
    _repartoAsignaciones[tareaId] = nuevoUsuarioId;
    notifyListeners();
  }

  /// Calcula dinámicamente los minutos totales acumulados por un usuario en el reparto
  int getMinutosUsuarioEnReparto(String usuarioId) {
    int total = 0;
    for (final entry in _repartoAsignaciones.entries) {
      if (entry.value == usuarioId) {
        final tarea = _tareas.firstWhere(
          (t) => t.id == entry.key,
          orElse: () => TareaModel(
            id: '',
            entornoId: '',
            titulo: '',
            tiempoEstimadoMinutos: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        total += tarea.tiempoEstimadoMinutos;
      }
    }
    return total;
  }

  /// Retorna la lista de tareas actualmente asignadas a un usuario en el tablero
  List<TareaModel> getTareasDeUsuarioEnReparto(String usuarioId) {
    return _tareas.where((t) {
      return _tareasSeleccionadasIds.contains(t.id) &&
          _repartoAsignaciones[t.id] == usuarioId;
    }).toList();
  }

  /// Ejecuta el algoritmo Greedy en Supabase o localmente
  Future<void> ejecutarRepartoAutomatico() async {
    final envId = _entornoId;
    if (envId == null || _participantesIds.isEmpty) return;

    final tareasARepartir = _tareasSeleccionadasIds.isNotEmpty
        ? _tareasSeleccionadasIds.toList()
        : tareasPendientes.map((t) => t.id).toList();

    if (tareasARepartir.isEmpty) {
      _errorMessage = 'No hay tareas seleccionadas para repartir';
      notifyListeners();
      return;
    }

    _isRepartoLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sesion = await _repository.ejecutarRepartoAutomatico(
        entornoId: envId,
        usuariosParticipantes: _participantesIds,
        tareaIds: tareasARepartir,
      );

      // Cargar asignaciones en el tablero para visualización / ajuste manual
      _tareasSeleccionadasIds = tareasARepartir.toSet();
      _repartoAsignaciones.clear();

      for (final item in sesion.items) {
        _repartoAsignaciones[item.tareaId] = item.usuarioAsignadoFinal;
      }

      _successMessage = 'Reparto balanceado calculado con éxito';
    } catch (e) {
      _errorMessage = 'Error en reparto: $e';
    } finally {
      _isRepartoLoading = false;
      notifyListeners();
    }
  }

  /// Confirma y persiste las asignaciones finales tras posibles ajustes manuales por Drag & Drop
  Future<void> confirmarRepartoFinal() async {
    final envId = _entornoId;
    if (envId == null ||
        _participantesIds.isEmpty ||
        _repartoAsignaciones.isEmpty) {
      return;
    }

    _isRepartoLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.guardarSesionRepartoManual(
        entornoId: envId,
        usuariosParticipantes: _participantesIds,
        asignacionesFinales: _repartoAsignaciones,
        todasLasTareas: _tareas,
      );

      // Actualizar inmediatamente las tareas locales en memoria
      _tareas = _tareas.map((t) {
        if (_repartoAsignaciones.containsKey(t.id)) {
          return t.copyWith(asignadoA: _repartoAsignaciones[t.id]);
        }
        return t;
      }).toList();

      _successMessage = 'Asignaciones guardadas y aplicadas a las tareas';
    } catch (e) {
      _errorMessage = 'Error al guardar reparto: $e';
    } finally {
      _isRepartoLoading = false;
      notifyListeners();
    }
  }

  /// Reparto Rápido sin fricción: asigna de forma automática y equitativa las tareas
  /// pendientes entre los miembros activos del hogar y aplica los cambios directamente.
  Future<void> ejecutarRepartoRapidoSemanal(List<String> miembrosIds) async {
    if (miembrosIds.isEmpty) return;
    setParticipantes(miembrosIds);

    final pendientes = tareasPendientes.map((t) => t.id).toList();
    if (pendientes.isEmpty) {
      _errorMessage = 'No hay tareas pendientes para repartir en este momento';
      notifyListeners();
      return;
    }

    _tareasSeleccionadasIds = pendientes.toSet();
    await ejecutarRepartoAutomatico();
    if (_repartoAsignaciones.isNotEmpty) {
      await confirmarRepartoFinal();
    }
  }

  void _actualizarRepartoAlCambiarTareas() {
    // Si alguna tarea fue eliminada, quitarla del mapa de reparto
    final currentIds = _tareas.map((t) => t.id).toSet();
    _tareasSeleccionadasIds.removeWhere((id) => !currentIds.contains(id));
    _repartoAsignaciones.removeWhere((id, _) => !currentIds.contains(id));
  }

  // ===========================================================================
  // Token FCM
  // ===========================================================================

  Future<void> registrarFcmToken(String token, {String? infoDispositivo}) async {
    final envId = _entornoId;
    if (envId == null) return;
    await _repository.registrarActualizarFcmToken(
      entornoId: envId,
      fcmToken: token,
      dispositivoInfo: infoDispositivo,
    );
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    LocalNotificationService.instance.cancelDebounceTimer();
    super.dispose();
  }

  // ===========================================================================
  // Métodos Auxiliares para Notificaciones Locales Quirúrgicas
  // ===========================================================================

  void _checkInitialNotificationSync() {
    if (_initialSyncDone || _entornoId == null) return;
    if (_tareas.isNotEmpty || _eventos.isNotEmpty) {
      _initialSyncDone = true;
      unawaited(LocalNotificationService.instance.sincronizarRecordatoriosLocalmente(
        tareas: _tareas,
        eventos: _eventos,
        currentUserId: _filtroUsuarioId,
      ));
    }
  }

  void _reaccionarRemotamenteATareas(
    Map<String, TareaModel> prevMap,
    List<TareaModel> newTareas,
  ) {
    final newMap = {for (final t in newTareas) t.id: t};

    // 1. Tareas eliminadas remotamente
    for (final prevEntry in prevMap.entries) {
      if (!newMap.containsKey(prevEntry.key)) {
        unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeTarea(prevEntry.key));
      }
    }

    // 2. Tareas modificadas o completadas remotamente
    for (final newTarea in newTareas) {
      final prevTarea = prevMap[newTarea.id];
      if (prevTarea == null) continue;

      if (newTarea.estaCompletada && !prevTarea.estaCompletada) {
        unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeTarea(newTarea.id));
      } else if (!newTarea.estaCompletada && prevTarea.estaCompletada) {
        _reprogramarRecordatoriosDeTareaLocal(newTarea);
      } else if (newTarea.recordatorios != prevTarea.recordatorios ||
          newTarea.fechaLimite != prevTarea.fechaLimite) {
        _reprogramarRecordatoriosDeTareaLocal(newTarea);
      }
    }
  }

  void _reaccionarRemotamenteAEventos(
    Map<String, EventoModel> prevMap,
    List<EventoModel> newEventos,
  ) {
    final newMap = {for (final e in newEventos) e.id: e};

    // 1. Eventos eliminados remotamente
    for (final prevEntry in prevMap.entries) {
      if (!newMap.containsKey(prevEntry.key)) {
        unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeEvento(prevEntry.key));
      }
    }

    // 2. Eventos modificados remotamente
    for (final newEv in newEventos) {
      final prevEv = prevMap[newEv.id];
      if (prevEv == null) continue;

      if (newEv.recordatorios != prevEv.recordatorios ||
          newEv.fechaInicio != prevEv.fechaInicio) {
        _reprogramarRecordatoriosDeEventoLocal(newEv);
      }
    }
  }

  void _reprogramarRecordatoriosDeTareaLocal(TareaModel tarea) {
    unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeTarea(tarea.id));
    if (tarea.estaCompletada) return;

    final bool mePertenece = tarea.asignadoA == null ||
        tarea.asignadoA!.isEmpty ||
        tarea.asignadoA == _filtroUsuarioId;

    if (mePertenece && tarea.recordatorios.isNotEmpty) {
      for (final rec in tarea.recordatorios) {
        unawaited(LocalNotificationService.instance.programarRecordatorioTarea(
          tareaId: tarea.id,
          tituloTarea: tarea.titulo,
          recordatorio: rec,
        ));
      }
    }
  }

  void _reprogramarRecordatoriosDeEventoLocal(EventoModel evento) {
    unawaited(LocalNotificationService.instance.cancelarRecordatoriosDeEvento(evento.id));
    if (evento.recordatorios.isNotEmpty) {
      for (final rec in evento.recordatorios) {
        unawaited(LocalNotificationService.instance.programarRecordatorioEvento(
          eventoId: evento.id,
          tituloEvento: evento.titulo,
          recordatorio: rec,
        ));
      }
    }
  }
}
