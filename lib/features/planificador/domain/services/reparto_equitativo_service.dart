import 'package:flutter/foundation.dart';

import '../../../environments/domain/models/environment_member_model.dart';
import '../../../profile/domain/models/avatar_data.dart';
import '../models/tarea_model.dart';
import '../repositories/i_planificador_repository.dart';

/// Resumen de asignación para un miembro en el reparto equitativo.
@immutable
class MiembroRepartoResumen {
  final String userId;
  final String username;
  final AvatarData avatarData;
  final int totalTareas;
  final int minutosTotales;
  final List<TareaModel> tareas;
  final int tareasPreviamenteAsignadas;
  final int minutosPreviamenteAsignados;

  const MiembroRepartoResumen({
    required this.userId,
    required this.username,
    required this.avatarData,
    required this.totalTareas,
    required this.minutosTotales,
    required this.tareas,
    this.tareasPreviamenteAsignadas = 0,
    this.minutosPreviamenteAsignados = 0,
  });

  int get nuevasTareasAsignadas => totalTareas - tareasPreviamenteAsignadas;
  int get nuevosMinutosAsignados => minutosTotales - minutosPreviamenteAsignados;
}

/// Detalle de una tarea asignada en el reparto equitativo.
@immutable
class ItemRepartoCalculado {
  final String tareaId;
  final String tituloTarea;
  final String? usuarioAsignadoInicial;
  final String usuarioAsignadoFinal;
  final int tiempoMinutos;

  const ItemRepartoCalculado({
    required this.tareaId,
    required this.tituloTarea,
    this.usuarioAsignadoInicial,
    required this.usuarioAsignadoFinal,
    required this.tiempoMinutos,
  });
}

/// Resultado global del cálculo del reparto equitativo.
@immutable
class ResultadoRepartoCalculado {
  final List<ItemRepartoCalculado> items;
  final Map<String, String> asignacionesFinales; // { tareaId: usuarioId }
  final List<MiembroRepartoResumen> resumenMiembros;
  final int minutosTotales;
  final int tareasTotales;
  final int tareasNuevamenteRepartidas;

  const ResultadoRepartoCalculado({
    required this.items,
    required this.asignacionesFinales,
    required this.resumenMiembros,
    required this.minutosTotales,
    required this.tareasTotales,
    this.tareasNuevamenteRepartidas = 0,
  });

  /// Retorna un resultado vacío si no hay datos que procesar.
  factory ResultadoRepartoCalculado.empty() => const ResultadoRepartoCalculado(
        items: [],
        asignacionesFinales: {},
        resumenMiembros: [],
        minutosTotales: 0,
        tareasTotales: 0,
        tareasNuevamenteRepartidas: 0,
      );
}

/// Servicio de dominio que implementa la heurística Greedy para el Partition Problem
/// (LPT: Longest Processing Time First) y orquesta la persistencia en lote de asignaciones.
class RepartoEquitativoService {
  /// Tiempo estimado por defecto si una tarea carece de estimación explícita (<= 0 min).
  static const int kTiempoEstimadoFallbackMinutos = 15;

  /// Ejecuta el algoritmo determinista de partición equitativa:
  /// 1. Considera las tareas que ya tienen un responsable asignado sumando sus minutos al balance inicial de cada miembro.
  /// 2. Toma las tareas con `asignadoA == null` (o sin asignar).
  /// 3. Normaliza duraciones usando el fallback de 15 minutos para valores <= 0.
  /// 4. Ordena las no asignadas de mayor a menor duración (LPT) y las asigna iterativamente al integrante con menor carga acumulada.
  static ResultadoRepartoCalculado calcularRepartoEquitativo({
    required List<TareaModel> tareas,
    required List<EnvironmentMemberModel> miembros,
    int fallbackTiempoMinutos = kTiempoEstimadoFallbackMinutos,
    bool balancearSoloNoAsignadas = true,
  }) {
    if (miembros.isEmpty || tareas.isEmpty) {
      return ResultadoRepartoCalculado.empty();
    }

    // Inicializar cargas y listas de tareas por miembro
    final Map<String, int> cargas = {
      for (final m in miembros) m.userId: 0,
    };
    final Map<String, List<TareaModel>> tareasPorMiembro = {
      for (final m in miembros) m.userId: [],
    };
    final Map<String, int> conteoPrevioPorMiembro = {
      for (final m in miembros) m.userId: 0,
    };
    final Map<String, int> minutosPreviosPorMiembro = {
      for (final m in miembros) m.userId: 0,
    };

    final List<ItemRepartoCalculado> items = [];
    final Map<String, String> asignacionesFinales = {};

    final List<TareaModel> tareasPendientesDeAsignar = [];

    // Paso 1: Computar balance inicial con tareas ya asignadas
    for (final tarea in tareas) {
      final minutos = tarea.tiempoEstimadoMinutos > 0
          ? tarea.tiempoEstimadoMinutos
          : fallbackTiempoMinutos;

      if (balancearSoloNoAsignadas && tarea.asignadoA != null && cargas.containsKey(tarea.asignadoA)) {
        final userId = tarea.asignadoA!;
        cargas[userId] = (cargas[userId] ?? 0) + minutos;
        tareasPorMiembro[userId]!.add(tarea);
        asignacionesFinales[tarea.id] = userId;
        conteoPrevioPorMiembro[userId] = (conteoPrevioPorMiembro[userId] ?? 0) + 1;
        minutosPreviosPorMiembro[userId] = (minutosPreviosPorMiembro[userId] ?? 0) + minutos;

        items.add(
          ItemRepartoCalculado(
            tareaId: tarea.id,
            tituloTarea: tarea.titulo,
            usuarioAsignadoInicial: userId,
            usuarioAsignadoFinal: userId,
            tiempoMinutos: minutos,
          ),
        );
      } else {
        // Tarea sin asignar o a rebalancear
        tareasPendientesDeAsignar.add(tarea);
      }
    }

    // Paso 2: Ordenar tareas no asignadas de mayor a menor duración (LPT); desempate por id ASC
    tareasPendientesDeAsignar.sort((a, b) {
      final duracionA = a.tiempoEstimadoMinutos > 0
          ? a.tiempoEstimadoMinutos
          : fallbackTiempoMinutos;
      final duracionB = b.tiempoEstimadoMinutos > 0
          ? b.tiempoEstimadoMinutos
          : fallbackTiempoMinutos;
      final cmp = duracionB.compareTo(duracionA);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    // Paso 3: Asignar iterativamente al integrante con menor tiempo acumulado
    for (final tarea in tareasPendientesDeAsignar) {
      final minutos = tarea.tiempoEstimadoMinutos > 0
          ? tarea.tiempoEstimadoMinutos
          : fallbackTiempoMinutos;

      // Buscar el miembro con menor carga acumulada (desempate determinista por orden de lista)
      EnvironmentMemberModel mejorMiembro = miembros.first;
      int menorCarga = cargas[mejorMiembro.userId] ?? 0;

      for (final miembro in miembros) {
        final cargaActual = cargas[miembro.userId] ?? 0;
        if (cargaActual < menorCarga) {
          menorCarga = cargaActual;
          mejorMiembro = miembro;
        }
      }

      cargas[mejorMiembro.userId] = menorCarga + minutos;
      tareasPorMiembro[mejorMiembro.userId]!.add(tarea);
      asignacionesFinales[tarea.id] = mejorMiembro.userId;

      items.add(
        ItemRepartoCalculado(
          tareaId: tarea.id,
          tituloTarea: tarea.titulo,
          usuarioAsignadoInicial: tarea.asignadoA,
          usuarioAsignadoFinal: mejorMiembro.userId,
          tiempoMinutos: minutos,
        ),
      );
    }

    // Paso 4: Construir resumen estructurado por miembro
    final resumenMiembros = miembros.map((m) {
      final tareasDelMiembro = tareasPorMiembro[m.userId] ?? [];
      final minutos = cargas[m.userId] ?? 0;
      return MiembroRepartoResumen(
        userId: m.userId,
        username: m.username,
        avatarData: m.avatarData,
        totalTareas: tareasDelMiembro.length,
        minutosTotales: minutos,
        tareas: tareasDelMiembro,
        tareasPreviamenteAsignadas: conteoPrevioPorMiembro[m.userId] ?? 0,
        minutosPreviamenteAsignados: minutosPreviosPorMiembro[m.userId] ?? 0,
      );
    }).toList();

    int totalMinutosGlobal = 0;
    for (final t in tareas) {
      totalMinutosGlobal += t.tiempoEstimadoMinutos > 0
          ? t.tiempoEstimadoMinutos
          : fallbackTiempoMinutos;
    }

    return ResultadoRepartoCalculado(
      items: items,
      asignacionesFinales: asignacionesFinales,
      resumenMiembros: resumenMiembros,
      minutosTotales: totalMinutosGlobal,
      tareasTotales: tareas.length,
      tareasNuevamenteRepartidas: tareasPendientesDeAsignar.length,
    );
  }

  /// Persiste en lote el resultado de un reparto mediante el repositorio.
  Future<bool> persistirRepartoEnLote({
    required IPlanificadorRepository repository,
    required String entornoId,
    required ResultadoRepartoCalculado resultado,
    required List<TareaModel> todasLasTareas,
  }) async {
    if (entornoId.isEmpty ||
        resultado.asignacionesFinales.isEmpty ||
        resultado.resumenMiembros.isEmpty) {
      return false;
    }

    try {
      final usuariosParticipantes =
          resultado.resumenMiembros.map((m) => m.userId).toList();

      await repository.guardarSesionRepartoManual(
        entornoId: entornoId,
        usuariosParticipantes: usuariosParticipantes,
        asignacionesFinales: resultado.asignacionesFinales,
        todasLasTareas: todasLasTareas,
      );
      return true;
    } catch (e) {
      debugPrint('Error en RepartoEquitativoService al persistir: $e');
      return false;
    }
  }
}
