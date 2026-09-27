import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/planificador/domain/models/tarea_model.dart';
import 'package:marth_app/features/planificador/domain/services/reparto_equitativo_service.dart';
import 'package:marth_app/features/profile/domain/models/avatar_data.dart';

void main() {
  group('RepartoEquitativoService Tests', () {
    final now = DateTime.now();

    final miembros = [
      EnvironmentMemberModel(
        environmentId: 'env-1',
        userId: 'user-a',
        role: 'admin',
        joinedAt: now,
        username: 'Ana',
        avatarData: const AvatarData.initials(),
      ),
      EnvironmentMemberModel(
        environmentId: 'env-1',
        userId: 'user-b',
        role: 'member',
        joinedAt: now,
        username: 'Bernardo',
        avatarData: const AvatarData.initials(),
      ),
    ];

    test('Defensivo: Retorna resultado vacío si la lista de miembros o de tareas está vacía', () {
      final res1 = RepartoEquitativoService.calcularRepartoEquitativo(
        tareas: [],
        miembros: miembros,
      );
      expect(res1.items, isEmpty);
      expect(res1.asignacionesFinales, isEmpty);
      expect(res1.resumenMiembros, isEmpty);
      expect(res1.minutosTotales, 0);

      final tarea = TareaModel(
        id: 't-1',
        entornoId: 'env-1',
        titulo: 'Limpiar cocina',
        createdAt: now,
        updatedAt: now,
      );

      final res2 = RepartoEquitativoService.calcularRepartoEquitativo(
        tareas: [tarea],
        miembros: [],
      );
      expect(res2.items, isEmpty);
      expect(res2.asignacionesFinales, isEmpty);
    });

    test('Reparto balanceado equitativo según heurística Greedy LPT', () {
      // Tareas con distintas duraciones: 60 min, 45 min, 30 min, 15 min
      final tareas = [
        TareaModel(
          id: 't-1',
          entornoId: 'env-1',
          titulo: 'Pintar pared',
          tiempoEstimadoMinutos: 60,
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-2',
          entornoId: 'env-1',
          titulo: 'Limpiar garaje',
          tiempoEstimadoMinutos: 45,
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-3',
          entornoId: 'env-1',
          titulo: 'Hacer compra grande',
          tiempoEstimadoMinutos: 30,
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-4',
          entornoId: 'env-1',
          titulo: 'Bajar basura',
          tiempoEstimadoMinutos: 15,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final resultado = RepartoEquitativoService.calcularRepartoEquitativo(
        tareas: tareas,
        miembros: miembros,
      );

      expect(resultado.tareasTotales, 4);
      expect(resultado.minutosTotales, 150);
      expect(resultado.resumenMiembros.length, 2);

      final resumenA = resultado.resumenMiembros.firstWhere((r) => r.userId == 'user-a');
      final resumenB = resultado.resumenMiembros.firstWhere((r) => r.userId == 'user-b');

      // Tareas ordenadas: 60 (t-1), 45 (t-2), 30 (t-3), 15 (t-4)
      // 1: t-1 (60) va a user-a (cargas: A=60, B=0)
      // 2: t-2 (45) va a user-b (cargas: A=60, B=45)
      // 3: t-3 (30) va a user-b (cargas: A=60, B=75)
      // 4: t-4 (15) va a user-a (cargas: A=75, B=75)
      // ¡Partición perfecta 75 vs 75!
      expect(resumenA.minutosTotales, 75);
      expect(resumenB.minutosTotales, 75);
      expect(resumenA.totalTareas, 2);
      expect(resumenB.totalTareas, 2);

      expect(resultado.asignacionesFinales['t-1'], 'user-a');
      expect(resultado.asignacionesFinales['t-2'], 'user-b');
      expect(resultado.asignacionesFinales['t-3'], 'user-b');
      expect(resultado.asignacionesFinales['t-4'], 'user-a');
    });

    test('Usa fallback coherente cuando tiempoEstimadoMinutos es 0 o negativo', () {
      final tareas = [
        TareaModel(
          id: 't-sin-tiempo',
          entornoId: 'env-1',
          titulo: 'Tarea sin tiempo',
          tiempoEstimadoMinutos: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final resultado = RepartoEquitativoService.calcularRepartoEquitativo(
        tareas: tareas,
        miembros: miembros,
        fallbackTiempoMinutos: 20,
      );

      expect(resultado.minutosTotales, 20);
      final item = resultado.items.first;
      expect(item.tiempoMinutos, 20);
      expect(resultado.asignacionesFinales['t-sin-tiempo'], 'user-a');
    });

    test('Desempate determinista por ID de tarea cuando tienen la misma duración', () {
      final tareas = [
        TareaModel(
          id: 't-b',
          entornoId: 'env-1',
          titulo: 'Tarea B',
          tiempoEstimadoMinutos: 30,
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-a',
          entornoId: 'env-1',
          titulo: 'Tarea A',
          tiempoEstimadoMinutos: 30,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final resultado = RepartoEquitativoService.calcularRepartoEquitativo(
        tareas: tareas,
        miembros: miembros,
      );

      // t-a va primero por orden alfabético de ID
      expect(resultado.items[0].tareaId, 't-a');
      expect(resultado.items[0].usuarioAsignadoFinal, 'user-a');
      expect(resultado.items[1].tareaId, 't-b');
      expect(resultado.items[1].usuarioAsignadoFinal, 'user-b');
    });
  });
}
