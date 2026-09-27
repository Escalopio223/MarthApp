import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/planificador/domain/models/task_form_basic_payload.dart';
import 'package:marth_app/features/planificador/presentation/widgets/task_advanced_accordion.dart';
import 'package:marth_app/features/planificador/presentation/widgets/task_form_basic.dart';
import 'package:marth_app/features/profile/domain/models/avatar_data.dart';

void main() {
  final testMembers = [
    EnvironmentMemberModel(
      userId: 'user-1',
      environmentId: 'env-1',
      username: 'Alice',
      role: 'member',
      joinedAt: DateTime(2026, 1, 1),
      avatarData: const AvatarData.initials(),
    ),
    EnvironmentMemberModel(
      userId: 'user-2',
      environmentId: 'env-1',
      username: 'Bob',
      role: 'member',
      joinedAt: DateTime(2026, 1, 1),
      avatarData: const AvatarData.initials(),
    ),
  ];

  Widget buildTestWidget({
    required Future<void> Function(TaskFormBasicPayload) onSubmit,
    VoidCallback? onCancel,
    TaskFormMode mode = TaskFormMode.create,
    TaskFormBasicPayload? initialPayload,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TaskFormBasic(
          mode: mode,
          initialPayload: initialPayload,
          miembros: testMembers,
          usuarioActualId: 'user-1',
          onSubmit: onSubmit,
          onCancel: onCancel,
        ),
      ),
    );
  }

  testWidgets('TaskFormBasic renders clean hero input card and quick chips', (tester) async {
    TaskFormBasicPayload? submittedPayload;

    await tester.pumpWidget(
      buildTestWidget(
        onSubmit: (payload) async {
          submittedPayload = payload;
        },
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify clean header
    expect(find.text('Nueva tarea'), findsOneWidget);

    // 2. Verify hero input card with title and description placeholders
    expect(find.text('¿Qué hay que hacer?'), findsOneWidget);
    expect(find.text('Añadir descripción o notas (opcional)...'), findsOneWidget);

    // 3. Verify date chips
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.text('Sin fecha'), findsOneWidget);

    // 4. Verify assignee chips
    expect(find.text('Sin asignar'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // 5. Verify accordion is initially collapsed with clean subtitle
    expect(find.text('Opciones avanzadas'), findsOneWidget);
    expect(find.text('Proyecto, etiquetas, subtareas, repetición...'), findsOneWidget);

    // 6. Enter title and description
    await tester.enterText(find.byType(TextField).first, 'Comprar pan');
    await tester.enterText(find.byType(TextField).at(1), 'Barra de pan integral');
    await tester.pump();

    // 7. Tap submit button
    final submitFinder = find.text('Crear tarea');
    expect(submitFinder, findsOneWidget);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    // 8. Assert submitted payload
    expect(submittedPayload, isNotNull);
    expect(submittedPayload!.titulo, 'Comprar pan');
    expect(submittedPayload!.descripcion, 'Barra de pan integral');
    expect(submittedPayload!.asignadoA, 'user-1');
  });

  testWidgets('TaskFormBasic toggles date and time chips correctly', (tester) async {
    TaskFormBasicPayload? submittedPayload;

    await tester.pumpWidget(
      buildTestWidget(
        onSubmit: (payload) async {
          submittedPayload = payload;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Mañana"
    await tester.tap(find.text('Mañana'));
    await tester.pumpAndSettle();

    // Verify "+ Hora" chip is visible when date is active
    expect(find.text('+ Hora'), findsOneWidget);

    // Tap "Sin fecha"
    await tester.tap(find.text('Sin fecha'));
    await tester.pumpAndSettle();

    // Verify "+ Hora" is hidden when task has no date
    expect(find.text('+ Hora'), findsNothing);

    // Enter title and submit
    await tester.enterText(find.byType(TextField).first, 'Tarea sin fecha');
    await tester.tap(find.text('Crear tarea'));
    await tester.pumpAndSettle();

    expect(submittedPayload, isNotNull);
    expect(submittedPayload!.titulo, 'Tarea sin fecha');
    expect(submittedPayload!.fechaEjecucion, isNull);
  });

  testWidgets('TaskAdvancedAccordion expands and displays refined Title Case sections', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        onSubmit: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    // Accordion is initially closed
    expect(find.byType(TaskAdvancedAccordion), findsOneWidget);
    expect(find.text('Estimación de tiempo'), findsNothing);

    // Tap to expand
    await tester.tap(find.text('Opciones avanzadas'));
    await tester.pumpAndSettle();

    // Verify refined sections inside
    expect(find.text('Estimación de tiempo'), findsOneWidget);
    expect(find.text('Categoría / Etiqueta'), findsOneWidget);
    expect(find.text('Tarea recurrente'), findsOneWidget);
    expect(find.text('Notas adicionales'), findsOneWidget);
    expect(find.text('Subtareas / Checklist'), findsOneWidget);
    expect(find.text('Recordatorio de alerta'), findsOneWidget);
  });
}
