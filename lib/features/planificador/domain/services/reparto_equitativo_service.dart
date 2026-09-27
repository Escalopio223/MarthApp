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

  const MiembroRepartoResumen({
    required this.userId,
    required this.username,
    required this.avatarData,
    required this.totalTareas,
    required this.minutosTotales,
    required this.tareas,
  });
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

  const ResultadoRepartoCalculado({
    required this.items,
    required this.asignacionesFinales,
    required this.resumenMiembros,
    required this.minutosTotales,
    required this.tareasTotales,
  });

  /// Retorna un resultado vacío si no hay datos que procesar.
  factory ResultadoRepartoCalculado.empty() => const ResultadoRepartoCalculado(
        items: [],
        asignacionesFinales: {},
        resumenMiembros: [],
        minutosTotales: 0,
        tareasTotales: 0,
      );
}

/// Servicio de dominio que implementa la heurística Greedy para el Partition Problem
/// (LPT: Longest Processing Time First) y orquesta la persistencia en lote de asignaciones.
class RepartoEquitativoService {
  /// Tiempo estimado por defecto si una tarea carece de estimación explícita (<= 0 min).
  static const int kTiempoEstimadoFallbackMinutos = 15;

  /// Ejecuta el algoritmo determinista de partición equitativa:
  /// 1. Extrae y normaliza los tiempos estimados de cada tarea (con fallback coherente).
  /// 2. Ordena de mayor a menor duración (LPT); desempate lexicográfico por ID.
  /// 3. Asigna de forma voraz (Greedy) a quien acumule menor carga de tiempo.
  static ResultadoRepartoCalculado calcularRepartoEquitativo({
    required List<TareaModel> tareas,
    required List<EnvironmentMemberModel> miembros,
    int fallbackTiempoMinutos = kTiempoEstimadoFallbackMinutos,
  }) {
    if (miembros.isEmpty || tareas.isEmpty) {
      return ResultadoRepartoCalculado.empty();
    }

    // 1. Clonar y ordenar tareas: mayor duración primero, desempate por id ASC
    final tareasOrdenadas = List<TareaModel>.from(tareas)..sort((a, b) {
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

    // 2. Inicializar acumuladores de carga en minutos por miembro
    final Map<String, int> cargas = {
      for (final m in miembros) m.userId: 0,
    };
    final Map<String, List<TareaModel>> tareasPorMiembro = {
      for (final m in miembros) m.userId: [],
    };

    final List<ItemRepartoCalculado> items = [];
    final Map<String, String> asignacionesFinales = {};
    int minutosTotales = 0;

    // 3. Asignación Greedy (voraz balanceada)
    for (final tarea in tareasOrdenadas) {
      final minutos = tarea.tiempoEstimadoMinutos > 0
          ? tarea.tiempoEstimadoMinutos
          : fallbackTiempoMinutos;
      minutosTotales += minutos;

      // Buscar el miembro con menor carga acumulada
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

    // 4. Construir resumen estructurado por miembro
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
      );
    }).toList();

    return ResultadoRepartoCalculado(
      items: items,
      asignacionesFinales: asignacionesFinales,
      resumenMiembros: resumenMiembros,
      minutosTotales: minutosTotales,
      tareasTotales: tareas.length,
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
