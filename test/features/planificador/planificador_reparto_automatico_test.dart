import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/planificador/domain/models/tarea_model.dart';
import 'package:marth_app/features/planificador/presentation/controllers/planificador_controller.dart';
import 'package:marth_app/features/planificador/presentation/widgets/planificador_hoy_view.dart';
import 'package:marth_app/features/planificador/presentation/widgets/reparto_preview_dialog.dart';
import 'package:marth_app/features/profile/domain/models/avatar_data.dart';

import 'planificador_controller_and_views_test.dart';

void main() {
  late MockPlanificadorRepository mockRepo;
  late PlanificadorController controller;

  setUp(() {
    mockRepo = MockPlanificadorRepository();
    controller = PlanificadorController(repository: mockRepo);
  });

  tearDown(() {
    controller.dispose();
  });

  group('PlanificadorHoyView - Reparto Automático y Modo Selección', () {
    final now = DateTime.now();

    final miembros = [
      EnvironmentMemberModel(
        environmentId: 'env-1',
        userId: 'usr-1',
        role: 'admin',
        joinedAt: now,
        username: 'Carlos',
        avatarData: const AvatarData.initials(),
      ),
      EnvironmentMemberModel(
        environmentId: 'env-1',
        userId: 'usr-2',
        role: 'member',
        joinedAt: now,
        username: 'Diana',
        avatarData: const AvatarData.initials(),
      ),
    ];

    testWidgets(
        'Muestra botón Reparto automático y activa modo de selección múltiple',
        (tester) async {
      mockRepo.tareas = [
        TareaModel(
          id: 't-1',
          entornoId: 'env-1',
          titulo: 'Pintar habitación',
          tiempoEstimadoMinutos: 60,
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-2',
          entornoId: 'env-1',
          titulo: 'Arreglar grifo',
          tiempoEstimadoMinutos: 30,
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              miembros: miembros,
              usuarioActualId: 'usr-1',
            ),
          ),
        ),
      );
      await tester.pump();

      // Botón "Reparto automático" visible en la cabecera
      final btnReparto = find.text('Reparto automático');
      expect(btnReparto, findsOneWidget);

      // El FAB de tarea rápida está visible antes de entrar a selección
      expect(find.text('Tarea rápida'), findsOneWidget);

      // Activar modo de selección
      await tester.tap(btnReparto);
      await tester.pumpAndSettle();

      // Verifica barra de selección
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Seleccionar todas'), findsOneWidget);
      expect(find.text('Deseleccionar todas'), findsOneWidget);
      expect(find.text('2 seleccionadas'), findsOneWidget);
      expect(find.text('Repartir (2)'), findsOneWidget);

      // En modo selección el FAB se oculta para no estorbar
      expect(find.text('Tarea rápida'), findsNothing);

      // Cancelar selección
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Sale del modo de selección
      expect(find.text('Cancelar'), findsNothing);
      expect(find.text('Tarea rápida'), findsOneWidget);
      expect(find.text('Reparto automático'), findsOneWidget);
    });

    testWidgets(
        'Opciones rápidas Seleccionar todas y Deseleccionar todas actualizan contador',
        (tester) async {
      mockRepo.tareas = [
        TareaModel(
          id: 't-1',
          entornoId: 'env-1',
          titulo: 'Barrer terraza',
          tiempoEstimadoMinutos: 20,
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-2',
          entornoId: 'env-1',
          titulo: 'Fregar suelo',
          tiempoEstimadoMinutos: 25,
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              miembros: miembros,
              usuarioActualId: 'usr-1',
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Reparto automático'));
      await tester.pump();

      expect(find.text('2 seleccionadas'), findsOneWidget);

      // Deseleccionar todas
      await tester.tap(find.text('Deseleccionar todas'));
      await tester.pump();

      expect(find.text('0 seleccionadas'), findsOneWidget);
      expect(find.text('Repartir (0)'), findsOneWidget);

      // Seleccionar todas de nuevo
      await tester.tap(find.text('Seleccionar todas'));
      await tester.pump();

      expect(find.text('2 seleccionadas'), findsOneWidget);
      expect(find.text('Repartir (2)'), findsOneWidget);
    });

    testWidgets(
        'Flujo completo de previsualización y confirmación de reparto equitativo',
        (tester) async {
      mockRepo.tareas = [
        TareaModel(
          id: 't-pesada',
          entornoId: 'env-1',
          titulo: 'Limpieza a fondo',
          tiempoEstimadoMinutos: 60,
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-ligera',
          entornoId: 'env-1',
          titulo: 'Sacar reciclaje',
          tiempoEstimadoMinutos: 15,
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              miembros: miembros,
              usuarioActualId: 'usr-1',
            ),
          ),
        ),
      );
      await tester.pump();

      // Entrar en modo selección
      await tester.tap(find.text('Reparto automático'));
      await tester.pump();

      // Abrir modal de previsualización
      await tester.tap(find.text('Repartir (2)'));
      await tester.pumpAndSettle();

      // Verifica contenido del modal RepartoPreviewDialog
      expect(find.byType(RepartoPreviewDialog), findsOneWidget);
      expect(find.text('Reparto automático'), findsWidgets);
      expect(find.text('2 tareas balanceadas (~75 min)'), findsOneWidget);

      // Ambos miembros deben aparecer en el modal de previsualización
      expect(
        find.descendant(
          of: find.byType(RepartoPreviewDialog),
          matching: find.text('Carlos'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(RepartoPreviewDialog),
          matching: find.text('Diana'),
        ),
        findsOneWidget,
      );

      // Tareas listadas dentro de la previsualización
      expect(find.text('Limpieza a fondo'), findsWidgets);
      expect(find.text('Sacar reciclaje'), findsWidgets);

      // Confirmar y aplicar reparto
      await tester.tap(find.text('Confirmar y aplicar'));
      await tester.pumpAndSettle();

      // El diálogo se cierra
      expect(find.byType(RepartoPreviewDialog), findsNothing);

      // Feedback visual de éxito
      expect(find.text('¡Tareas repartidas equitativamente con éxito! 🎉'),
          findsOneWidget);

      // Sale automáticamente del modo de selección
      expect(find.text('Reparto automático'), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
    });

    testWidgets(
        'Defensivo: Muestra feedback si no hay miembros activos o tareas pendientes',
        (tester) async {
      // Sin miembros
      mockRepo.tareas = [
        TareaModel(
          id: 't-1',
          entornoId: 'env-1',
          titulo: 'Tarea de prueba',
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              miembros: const [], // Sin miembros
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Reparto automático'));
      await tester.pump();

      expect(
        find.text('No hay miembros activos en el entorno para repartir tareas'),
        findsOneWidget,
      );
      // No debe entrar en modo selección
      expect(find.text('Cancelar'), findsNothing);
    });

    testWidgets(
        'Tocar tarjeta individual alterna su estado de selección en modo lote',
        (tester) async {
      mockRepo.tareas = [
        TareaModel(
          id: 't-1',
          entornoId: 'env-1',
          titulo: 'Tarea Uno',
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
        TareaModel(
          id: 't-2',
          entornoId: 'env-1',
          titulo: 'Tarea Dos',
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              miembros: miembros,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Reparto automático'));
      await tester.pump();

      expect(find.text('2 seleccionadas'), findsOneWidget);

      // Tocar la tarjeta de Tarea Uno para deseleccionarla
      await tester.tap(find.text('Tarea Uno'));
      await tester.pump();

      expect(find.text('1 seleccionada'), findsOneWidget);

      // Tocar nuevamente para volver a seleccionarla
      await tester.tap(find.text('Tarea Uno'));
      await tester.pump();

      expect(find.text('2 seleccionadas'), findsOneWidget);
    });

    testWidgets(
        'Cancelar en el diálogo de previsualización no persiste cambios y preserva selección',
        (tester) async {
      mockRepo.tareas = [
        TareaModel(
          id: 't-1',
          entornoId: 'env-1',
          titulo: 'Hacer cama',
          tiempoEstimadoMinutos: 10,
          estado: 'pendiente',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      controller.setEntorno('env-1');
      mockRepo.emitAll();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanificadorHoyView(
              controller: controller,
              miembros: miembros,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Reparto automático'));
      await tester.pump();

      await tester.tap(find.text('Repartir (1)'));
      await tester.pumpAndSettle();

      expect(find.byType(RepartoPreviewDialog), findsOneWidget);

      // Tocar Cancelar dentro del diálogo
      await tester.tap(find.descendant(
        of: find.byType(RepartoPreviewDialog),
        matching: find.text('Cancelar'),
      ));
      await tester.pumpAndSettle();

      // Diálogo cerrado
      expect(find.byType(RepartoPreviewDialog), findsNothing);

      // Modo selección sigue activo y listo para editar
      expect(find.text('1 seleccionada'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });
}
