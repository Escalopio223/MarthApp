import '../models/agenda_item_model.dart';
import '../models/checklist_item_model.dart';
import '../models/comentario_tarea_model.dart';
import '../models/evento_model.dart';
import '../models/proyecto_model.dart';
import '../models/recordatorio_tarea_model.dart';
import '../models/sesion_reparto_model.dart';
import '../models/tarea_model.dart';

/// Contrato abstracto del repositorio para el módulo Planificador de MarthApp.
abstract class IPlanificadorRepository {
  // ===========================================================================
  // 1. Streams reactivos filtrados por entorno
  // ===========================================================================

  /// Emite la lista actualizada de proyectos del entorno activo
  Stream<List<ProyectoModel>> streamProyectos(String entornoId);

  /// Emite la lista actualizada de tareas del entorno activo
  Stream<List<TareaModel>> streamTareas(String entornoId);

  /// Emite la lista actualizada de eventos del entorno activo
  Stream<List<EventoModel>> streamEventos(String entornoId);

  // ===========================================================================
  // 2. Consulta combinada para la Agenda/Calendario
  // ===========================================================================

  /// Retorna la combinación de eventos y tareas con fecha_limite != null,
  /// ordenados cronológicamente.
  Future<List<AgendaItemModel>> getAgendaItems(
    String entornoId, {
    DateTime? desde,
    DateTime? hasta,
  });

  // ===========================================================================
  // 3. Operaciones CRUD de Proyectos
  // ===========================================================================

  Future<ProyectoModel> crearProyecto({
    required String entornoId,
    required String nombre,
    String? descripcion,
    String icono = 'folder',
    String colorHex = '#6366F1',
  });

  Future<void> actualizarProyecto(ProyectoModel proyecto);

  Future<void> eliminarProyecto(String proyectoId);

  // ===========================================================================
  // 4. Operaciones CRUD de Tareas y Checklist
  // ===========================================================================

  Future<TareaModel> crearTarea({
    required String entornoId,
    String? proyectoId,
    required String titulo,
    String? descripcion,
    DateTime? fechaLimite,
    String? asignadoA,
    int tiempoEstimadoMinutos = 15,
    List<ChecklistItemModel> checklist = const [],
    List<RecordatorioTareaModel> recordatorios = const [],
  });

  Future<void> actualizarTarea(TareaModel tarea);

  Future<void> cambiarEstadoTarea(String tareaId, String nuevoEstado);

  Future<void> toggleChecklistItem(String tareaId, String itemId);

  Future<void> agregarComentarioTarea({
    required String tareaId,
    required ComentarioTareaModel comentario,
  });

  Future<List<RecordatorioTareaModel>> obtenerRecordatoriosTarea(String tareaId);

  Future<void> guardarRecordatoriosTarea(
    String tareaId,
    List<RecordatorioTareaModel> recordatorios,
  );

  Future<void> eliminarTarea(String tareaId);

  // ===========================================================================
  // 5. Operaciones CRUD de Eventos y Cumpleaños
  // ===========================================================================

  Future<EventoModel> crearEvento({
    required String entornoId,
    required String titulo,
    String? descripcion,
    required String tipo, // 'cumpleanos' | 'evento_general'
    required DateTime fechaInicio,
    DateTime? fechaFin,
    bool esTodoElDia = false,
    String? personaCumpleanos,
    String? ideasRegalo,
    List<ChecklistItemModel> checklist = const [],
    List<RecordatorioTareaModel> recordatorios = const [],
  });

  Future<void> actualizarEvento(EventoModel evento);

  Future<void> toggleEventoChecklistItem(String eventoId, String itemId);

  Future<void> eliminarEvento(String eventoId);

  // ===========================================================================
  // 6. Algoritmo y Persistencia de Reparto de Tareas
  // ===========================================================================

  /// Invoca la función determinista en PostgreSQL para ejecutar el reparto Greedy
  Future<SesionRepartoModel> ejecutarRepartoAutomatico({
    required String entornoId,
    required List<String> usuariosParticipantes,
    List<String>? tareaIds,
  });

  /// Persiste una sesión manual de reparto resultante de reorganizaciones por Drag & Drop
  Future<SesionRepartoModel> guardarSesionRepartoManual({
    required String entornoId,
    required List<String> usuariosParticipantes,
    required Map<String, String> asignacionesFinales, // { tareaId: usuarioId }
    required List<TareaModel> todasLasTareas,
  });

  // ===========================================================================
  // 7. Registro y Actualización de Tokens FCM
  // ===========================================================================

  /// Registra o actualiza el token FCM del dispositivo para el entorno activo
  Future<void> registrarActualizarFcmToken({
    required String entornoId,
    required String fcmToken,
    String? dispositivoInfo,
  });
}
