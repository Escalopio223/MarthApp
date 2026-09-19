import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/agenda_item_model.dart';
import '../../domain/models/checklist_item_model.dart';
import '../../domain/models/comentario_tarea_model.dart';
import '../../domain/models/evento_model.dart';
import '../../domain/models/item_reparto_model.dart';
import '../../domain/models/proyecto_model.dart';
import '../../domain/models/recordatorio_tarea_model.dart';
import '../../domain/models/sesion_reparto_model.dart';
import '../../domain/models/tarea_model.dart';
import '../../domain/repositories/i_planificador_repository.dart';

/// Implementación del repositorio Planificador conectada a Supabase
class PlanificadorRepository implements IPlanificadorRepository {
  final SupabaseClient? _supabase;

  PlanificadorRepository({SupabaseClient? client})
      : _supabase = client ?? _safeGetClient();

  static SupabaseClient? _safeGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _client {
    final client = _supabase;
    if (client == null) {
      throw StateError('SupabaseClient no está disponible (no inicializado)');
    }
    return client;
  }

  String? get _currentUserId => _client.auth.currentUser?.id;

  // ===========================================================================
  // 1. Streams reactivos filtrados por entorno_id
  // ===========================================================================

  @override
  Stream<List<ProyectoModel>> streamProyectos(String entornoId) {
    if (_supabase == null) return const Stream.empty();
    return _client
        .from('planificador_proyectos')
        .stream(primaryKey: ['id'])
        .eq('entorno_id', entornoId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .map((e) => ProyectoModel.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  @override
  Stream<List<TareaModel>> streamTareas(String entornoId) {
    if (_supabase == null) return const Stream.empty();
    return _client
        .from('planificador_tareas')
        .stream(primaryKey: ['id'])
        .eq('entorno_id', entornoId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((e) => TareaModel.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  @override
  Stream<List<EventoModel>> streamEventos(String entornoId) {
    if (_supabase == null) return const Stream.empty();
    return _client
        .from('planificador_eventos')
        .stream(primaryKey: ['id'])
        .eq('entorno_id', entornoId)
        .order('fecha_inicio', ascending: true)
        .map((rows) => rows
            .map((e) => EventoModel.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  // ===========================================================================
  // 2. Consulta combinada para Agenda / Calendario
  // ===========================================================================

  @override
  Future<List<AgendaItemModel>> getAgendaItems(
    String entornoId, {
    DateTime? desde,
    DateTime? hasta,
  }) async {
    if (_supabase == null) return [];
    try {
      // 1. Consultar eventos del entorno
      var eventosQuery = _client
          .from('planificador_eventos')
          .select()
          .eq('entorno_id', entornoId);

      if (desde != null) {
        eventosQuery =
            eventosQuery.gte('fecha_inicio', desde.toIso8601String());
      }
      if (hasta != null) {
        eventosQuery =
            eventosQuery.lte('fecha_inicio', hasta.toIso8601String());
      }

      // 2. Consultar tareas con fecha_limite asignada
      var tareasQuery = _client
          .from('planificador_tareas')
          .select()
          .eq('entorno_id', entornoId)
          .not('fecha_limite', 'is', null);

      if (desde != null) {
        tareasQuery =
            tareasQuery.gte('fecha_limite', desde.toIso8601String());
      }
      if (hasta != null) {
        tareasQuery =
            tareasQuery.lte('fecha_limite', hasta.toIso8601String());
      }

      final results = await Future.wait([eventosQuery, tareasQuery]);

      final List<dynamic> eventosData = results[0] as List<dynamic>? ?? [];
      final List<dynamic> tareasData = results[1] as List<dynamic>? ?? [];

      final List<AgendaItemModel> items = [];

      for (final json in eventosData) {
        try {
          final evento =
              EventoModel.fromJson(Map<String, dynamic>.from(json as Map));
          items.add(AgendaItemModel.fromEvento(evento));
        } catch (e) {
          debugPrint('Error parseando evento para agenda: $e');
        }
      }

      for (final json in tareasData) {
        try {
          final tarea =
              TareaModel.fromJson(Map<String, dynamic>.from(json as Map));
          items.add(AgendaItemModel.fromTarea(tarea));
        } catch (e) {
          debugPrint('Error parseando tarea para agenda: $e');
        }
      }

      // Ordenar cronológicamente
      items.sort();
      return items;
    } catch (e) {
      debugPrint('Error en getAgendaItems: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // 3. CRUD Proyectos
  // ===========================================================================

  @override
  Future<ProyectoModel> crearProyecto({
    required String entornoId,
    required String nombre,
    String? descripcion,
    String icono = 'folder',
    String colorHex = '#6366F1',
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw StateError('Usuario no autenticado');

    final res = await _client
        .from('planificador_proyectos')
        .insert({
          'entorno_id': entornoId,
          'nombre': nombre,
          'descripcion': ?descripcion,
          'icono': icono,
          'color_hex': colorHex,
          'created_by': userId,
        })
        .select()
        .single();

    return ProyectoModel.fromJson(Map<String, dynamic>.from(res));
  }

  @override
  Future<void> actualizarProyecto(ProyectoModel proyecto) async {
    await _client.from('planificador_proyectos').update({
      'nombre': proyecto.nombre,
      'descripcion': proyecto.descripcion,
      'icono': proyecto.icono,
      'color_hex': proyecto.colorHex,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', proyecto.id);
  }

  @override
  Future<void> eliminarProyecto(String proyectoId) async {
    await _client
        .from('planificador_proyectos')
        .delete()
        .eq('id', proyectoId);
  }

  // ===========================================================================
  // 4. CRUD Tareas y Checklist
  // ===========================================================================

  @override
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
  }) async {
    final res = await _client
        .from('planificador_tareas')
        .insert({
          'entorno_id': entornoId,
          'proyecto_id': ?proyectoId,
          'titulo': titulo,
          'descripcion': ?descripcion,
          'fecha_limite': ?fechaLimite?.toUtc().toIso8601String(),
          'asignado_a': ?asignadoA,
          'tiempo_estimado_minutos': tiempoEstimadoMinutos,
          'estado': 'pendiente',
          'checklist': checklist.map((e) => e.toJson()).toList(),
        })
        .select()
        .single();

    final tareaCreada = TareaModel.fromJson(Map<String, dynamic>.from(res));

    if (recordatorios.isNotEmpty) {
      final payload = recordatorios.map((r) {
        return {
          'tarea_id': tareaCreada.id,
          'fecha_notificacion':
              '${r.fechaNotificacion.year}-${r.fechaNotificacion.month.toString().padLeft(2, '0')}-${r.fechaNotificacion.day.toString().padLeft(2, '0')}',
          'hora_notificacion': r.horaNotificacion,
          'enviado': r.enviado,
        };
      }).toList();

      try {
        await _client.from('planificador_tarea_recordatorios').insert(payload);
      } catch (e) {
        debugPrint('Error al insertar recordatorios de tarea: $e');
      }

      return tareaCreada.copyWith(
        recordatorios: recordatorios
            .map((r) => r.copyWith(tareaId: tareaCreada.id))
            .toList(),
      );
    }

    return tareaCreada;
  }

  @override
  Future<void> actualizarTarea(TareaModel tarea) async {
    await _client.from('planificador_tareas').update({
      'proyecto_id': tarea.proyectoId,
      'titulo': tarea.titulo,
      'descripcion': tarea.descripcion,
      'fecha_limite': tarea.fechaLimite?.toUtc().toIso8601String(),
      'asignado_a': tarea.asignadoA,
      'tiempo_estimado_minutos': tarea.tiempoEstimadoMinutos,
      'estado': tarea.estado,
      'checklist': tarea.checklist.map((e) => e.toJson()).toList(),
      'comentarios': tarea.comentarios.map((e) => e.toJson()).toList(),
      'completada_por': tarea.completadaPor,
      'completada_at': tarea.completadaAt?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', tarea.id);

    // Sincronizar recordatorios de la tarea
    await guardarRecordatoriosTarea(tarea.id, tarea.recordatorios);
  }

  @override
  Future<List<RecordatorioTareaModel>> obtenerRecordatoriosTarea(
      String tareaId) async {
    try {
      final rows = await _client
          .from('planificador_tarea_recordatorios')
          .select()
          .eq('tarea_id', tareaId)
          .order('fecha_notificacion', ascending: true);

      return (rows as List)
          .whereType<Map>()
          .map((r) =>
              RecordatorioTareaModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener recordatorios de tarea $tareaId: $e');
      return const [];
    }
  }

  @override
  Future<void> guardarRecordatoriosTarea(
    String tareaId,
    List<RecordatorioTareaModel> recordatorios,
  ) async {
    try {
      // 1. Eliminar recordatorios previos de la tarea
      await _client
          .from('planificador_tarea_recordatorios')
          .delete()
          .eq('tarea_id', tareaId);

      // 2. Insertar nuevos recordatorios si la lista no está vacía
      if (recordatorios.isNotEmpty) {
        final payload = recordatorios.map((r) {
          return {
            'tarea_id': tareaId,
            'fecha_notificacion':
                '${r.fechaNotificacion.year}-${r.fechaNotificacion.month.toString().padLeft(2, '0')}-${r.fechaNotificacion.day.toString().padLeft(2, '0')}',
            'hora_notificacion': r.horaNotificacion,
            'enviado': r.enviado,
          };
        }).toList();

        await _client
            .from('planificador_tarea_recordatorios')
            .insert(payload);
      }
    } catch (e) {
      debugPrint('Error al guardar recordatorios de tarea $tareaId: $e');
    }
  }

  @override
  Future<void> cambiarEstadoTarea(String tareaId, String nuevoEstado) async {
    final userId = _currentUserId;
    final isDone = nuevoEstado == 'completada';

    await _client.from('planificador_tareas').update({
      'estado': nuevoEstado,
      'completada_por': isDone ? userId : null,
      'completada_at': isDone ? DateTime.now().toIso8601String() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', tareaId);
  }

  @override
  Future<void> toggleChecklistItem(String tareaId, String itemId) async {
    // 1. Obtener la tarea actual
    final row = await _client
        .from('planificador_tareas')
        .select('checklist, estado')
        .eq('id', tareaId)
        .single();

    final currentTask = TareaModel.fromJson(Map<String, dynamic>.from(row));
    final updatedChecklist = currentTask.checklist.map((item) {
      if (item.id == itemId) {
        return item.copyWith(completado: !item.completado);
      }
      return item;
    }).toList();

    // Actualizar estado si todos los items fueron completados
    final todosCompletos = updatedChecklist.isNotEmpty &&
        updatedChecklist.every((item) => item.completado);

    final String nuevoEstado = todosCompletos
        ? 'completada'
        : (currentTask.estado == 'completada' ? 'en_progreso' : currentTask.estado);

    final userId = _currentUserId;

    await _client.from('planificador_tareas').update({
      'checklist': updatedChecklist.map((e) => e.toJson()).toList(),
      'estado': nuevoEstado,
      if (todosCompletos) 'completada_por': userId,
      if (todosCompletos)
        'completada_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', tareaId);
  }

  @override
  Future<void> agregarComentarioTarea({
    required String tareaId,
    required ComentarioTareaModel comentario,
  }) async {
    final row = await _client
        .from('planificador_tareas')
        .select('comentarios')
        .eq('id', tareaId)
        .single();

    final raw = row['comentarios'];
    List<dynamic> currentComentarios = [];
    if (raw is List) {
      currentComentarios = List<dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          currentComentarios = List<dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final updated = [...currentComentarios, comentario.toJson()];

    await _client.from('planificador_tareas').update({
      'comentarios': updated,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', tareaId);
  }

  @override
  Future<void> eliminarTarea(String tareaId) async {
    await _client.from('planificador_tareas').delete().eq('id', tareaId);
  }

  // ===========================================================================
  // 5. CRUD Eventos y Cumpleaños
  // ===========================================================================

  @override
  Future<EventoModel> crearEvento({
    required String entornoId,
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
    final userId = _currentUserId;
    if (userId == null) throw StateError('Usuario no autenticado');

    final Map<String, dynamic> insertPayload = {
      'entorno_id': entornoId,
      'titulo': titulo,
      'descripcion': ?descripcion,
      'tipo': tipo,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': ?fechaFin?.toIso8601String(),
      'es_todo_el_dia': esTodoElDia,
      'persona_cumpleanos': ?personaCumpleanos,
      'ideas_regalo': ?ideasRegalo,
      'checklist': checklist.map((e) => e.toJson()).toList(),
      'created_by': userId,
    };

    if (recordatorios.isNotEmpty) {
      insertPayload['recordatorios'] =
          recordatorios.map((e) => e.toJson()).toList();
    }

    try {
      final res = await _client
          .from('planificador_eventos')
          .insert(insertPayload)
          .select()
          .single();

      return EventoModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      // Si la columna 'recordatorios' aún no existe en Supabase remoto, reintentar sin ella
      if (insertPayload.containsKey('recordatorios') &&
          e.toString().contains('recordatorios')) {
        insertPayload.remove('recordatorios');
        final res = await _client
            .from('planificador_eventos')
            .insert(insertPayload)
            .select()
            .single();
        final model = EventoModel.fromJson(Map<String, dynamic>.from(res));
        return model.copyWith(recordatorios: recordatorios);
      }
      rethrow;
    }
  }

  @override
  Future<void> actualizarEvento(EventoModel evento) async {
    final Map<String, dynamic> updatePayload = {
      'titulo': evento.titulo,
      'descripcion': evento.descripcion,
      'tipo': evento.tipo,
      'fecha_inicio': evento.fechaInicio.toIso8601String(),
      'fecha_fin': evento.fechaFin?.toIso8601String(),
      'es_todo_el_dia': evento.esTodoElDia,
      'persona_cumpleanos': evento.personaCumpleanos,
      'ideas_regalo': evento.ideasRegalo,
      'checklist': evento.checklist.map((e) => e.toJson()).toList(),
      'recordatorios': evento.recordatorios.map((e) => e.toJson()).toList(),
    };

    try {
      await _client
          .from('planificador_eventos')
          .update(updatePayload)
          .eq('id', evento.id);
    } catch (e) {
      if (updatePayload.containsKey('recordatorios') &&
          e.toString().contains('recordatorios')) {
        updatePayload.remove('recordatorios');
        await _client
            .from('planificador_eventos')
            .update(updatePayload)
            .eq('id', evento.id);
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> toggleEventoChecklistItem(String eventoId, String itemId) async {
    final row = await _client
        .from('planificador_eventos')
        .select('checklist')
        .eq('id', eventoId)
        .single();

    final currentEvent = EventoModel.fromJson(Map<String, dynamic>.from(row));
    final updatedChecklist = currentEvent.checklist.map((item) {
      if (item.id == itemId) {
        return item.copyWith(completado: !item.completado);
      }
      return item;
    }).toList();

    await _client.from('planificador_eventos').update({
      'checklist': updatedChecklist.map((e) => e.toJson()).toList(),
    }).eq('id', eventoId);
  }

  @override
  Future<void> eliminarEvento(String eventoId) async {
    await _client.from('planificador_eventos').delete().eq('id', eventoId);
  }

  // ===========================================================================
  // 6. Reparto Equitativo de Tareas
  // ===========================================================================

  @override
  Future<SesionRepartoModel> ejecutarRepartoAutomatico({
    required String entornoId,
    required List<String> usuariosParticipantes,
    List<String>? tareaIds,
  }) async {
    try {
      // 1. Intentar llamar a la función PostgreSQL RPC planificador_ejecutar_reparto_equitativo
      final res = await _client.rpc(
        'planificador_ejecutar_reparto_equitativo',
        params: {
          'p_entorno_id': entornoId,
          'p_usuarios_participantes': usuariosParticipantes,
          if (tareaIds != null && tareaIds.isNotEmpty) 'p_tarea_ids': tareaIds,
        },
      );

      if (res is Map) {
        final sesionId = res['sesion_id'] as String;
        // Consultar la sesión generada con sus ítems
        final sesionRow = await _client
            .from('planificador_repartos_sesiones')
            .select('*, items:planificador_repartos_items(*)')
            .eq('id', sesionId)
            .single();

        return SesionRepartoModel.fromJson(
            Map<String, dynamic>.from(sesionRow));
      }
    } catch (rpcError) {
      debugPrint('RPC reparto falló o no existe, usando fallback local: $rpcError');
    }

    // 2. Fallback determinista en cliente si la RPC no estuviese compilada
    return _ejecutarRepartoGreedyLocal(
      entornoId: entornoId,
      usuariosParticipantes: usuariosParticipantes,
      tareaIds: tareaIds,
    );
  }

  Future<SesionRepartoModel> _ejecutarRepartoGreedyLocal({
    required String entornoId,
    required List<String> usuariosParticipantes,
    List<String>? tareaIds,
  }) async {
    // Consultar tareas pendientes
    var query = _client
        .from('planificador_tareas')
        .select()
        .eq('entorno_id', entornoId)
        .eq('estado', 'pendiente');

    if (tareaIds != null && tareaIds.isNotEmpty) {
      query = query.inFilter('id', tareaIds);
    }

    final res = await query;
    final List<dynamic> rows = res as List<dynamic>? ?? [];
    final tareas = rows
        .map((r) => TareaModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();

    if (tareas.isEmpty) {
      throw StateError('No hay tareas pendientes para repartir');
    }

    // Heurística Greedy: ordenar por tiempo_estimado desc, desempate por id asc
    tareas.sort((a, b) {
      final cmp =
          b.tiempoEstimadoMinutos.compareTo(a.tiempoEstimadoMinutos);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    final Map<String, int> cargas = {
      for (final u in usuariosParticipantes) u: 0
    };

    final List<ItemRepartoModel> itemsGenerados = [];
    final sesionId = DateTime.now().millisecondsSinceEpoch.toString();

    for (final tarea in tareas) {
      // Usuario con menor carga
      String mejorUsuario = usuariosParticipantes.first;
      int menorCarga = cargas[mejorUsuario]!;

      for (final u in usuariosParticipantes) {
        if (cargas[u]! < menorCarga) {
          menorCarga = cargas[u]!;
          mejorUsuario = u;
        }
      }

      cargas[mejorUsuario] = menorCarga + tarea.tiempoEstimadoMinutos;

      itemsGenerados.add(
        ItemRepartoModel(
          id: '${tarea.id}_rep',
          sesionId: sesionId,
          tareaId: tarea.id,
          usuarioAsignadoInicial:
              tarea.asignadoA ?? mejorUsuario,
          usuarioAsignadoFinal: mejorUsuario,
          tiempoMinutos: tarea.tiempoEstimadoMinutos,
          tituloTarea: tarea.titulo,
        ),
      );
    }

    final minutosTotales =
        cargas.values.fold<int>(0, (sum, val) => sum + val);

    // Persistir sesión e ítems
    await guardarSesionRepartoManual(
      entornoId: entornoId,
      usuariosParticipantes: usuariosParticipantes,
      asignacionesFinales: {
        for (final item in itemsGenerados)
          item.tareaId: item.usuarioAsignadoFinal
      },
      todasLasTareas: tareas,
    );

    return SesionRepartoModel(
      id: sesionId,
      entornoId: entornoId,
      fechaSesion: DateTime.now(),
      usuariosParticipantes: usuariosParticipantes,
      minutosTotales: minutosTotales,
      items: itemsGenerados,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<SesionRepartoModel> guardarSesionRepartoManual({
    required String entornoId,
    required List<String> usuariosParticipantes,
    required Map<String, String> asignacionesFinales,
    required List<TareaModel> todasLasTareas,
  }) async {
    // 1. Crear sesión
    int minutosTotales = 0;
    final Map<String, TareaModel> tareasMap = {
      for (final t in todasLasTareas) t.id: t
    };

    for (final entry in asignacionesFinales.entries) {
      final t = tareasMap[entry.key];
      if (t != null) {
        minutosTotales += t.tiempoEstimadoMinutos;
      }
    }

    final sesionRow = await _client
        .from('planificador_repartos_sesiones')
        .insert({
          'entorno_id': entornoId,
          'fecha_sesion':
              DateTime.now().toIso8601String().split('T').first,
          'usuarios_participantes': usuariosParticipantes,
          'minutos_totales': minutosTotales,
          'estado': 'borrador',
        })
        .select()
        .single();

    final sesionId = sesionRow['id'] as String;

    // 2. Insertar ítems de reparto
    final List<Map<String, dynamic>> itemsPayload = [];
    for (final entry in asignacionesFinales.entries) {
      final tareaId = entry.key;
      final nuevoUsuario = entry.value;
      final t = tareasMap[tareaId];
      if (t != null) {
        itemsPayload.add({
          'sesion_id': sesionId,
          'tarea_id': tareaId,
          'usuario_asignado_inicial': t.asignadoA ?? nuevoUsuario,
          'usuario_asignado_final': nuevoUsuario,
          'tiempo_minutos': t.tiempoEstimadoMinutos,
        });
      }
    }

    if (itemsPayload.isNotEmpty) {
      await _client
          .from('planificador_repartos_items')
          .insert(itemsPayload);

      // 3. Actualizar asignación en planificador_tareas
      for (final entry in asignacionesFinales.entries) {
        await _client
            .from('planificador_tareas')
            .update({
              'asignado_a': entry.value,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', entry.key);
      }
    }

    // 4. Confirmar sesión de reparto atómicamente para disparar las notificaciones
    // push libres de condiciones de carrera (todos los items ya están comprometidos en BD)
    await _client
        .from('planificador_repartos_sesiones')
        .update({'estado': 'completado'})
        .eq('id', sesionId);

    return SesionRepartoModel.fromJson(
        Map<String, dynamic>.from(sesionRow)..['estado'] = 'completado');
  }

  // ===========================================================================
  // 7. Registro de Tokens FCM
  // ===========================================================================

  @override
  Future<void> registrarActualizarFcmToken({
    required String entornoId,
    required String fcmToken,
    String? dispositivoInfo,
  }) async {
    if (_supabase == null) return;
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _client.from('usuario_fcm_tokens').upsert(
        {
          'user_id': userId,
          'entorno_id': entornoId,
          'fcm_token': fcmToken,
          'dispositivo_info': ?dispositivoInfo,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
    } catch (e) {
      debugPrint('Error registrando fcm_token: $e');
    }
  }
}
