import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_invitation_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_model.dart';
import 'package:marth_app/features/environments/presentation/controllers/environment_controller.dart';
import 'package:marth_app/features/environments/presentation/widgets/create_environment_modal.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_invitation_tile.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_selector_chip.dart';
import 'package:marth_app/features/environments/presentation/widgets/migrate_content_dialog.dart';
import 'environment_controller_test.dart';

void main() {
  group('Environment Widgets Tests', () {
    late MockEnvironmentRepository mockRepo;
    late EnvironmentController controller;

    setUp(() {
      mockRepo = MockEnvironmentRepository();
      mockRepo.environments = [
        EnvironmentModel(
          id: 'env_personal',
          name: 'Mi Espacio',
          isPersonal: true,
          createdBy: 'u1',
          createdAt: DateTime.now(),
          role: 'owner',
        ),
        EnvironmentModel(
          id: 'env_shared',
          name: 'Piso Compartido',
          isPersonal: false,
          createdBy: 'u1',
          createdAt: DateTime.now(),
          role: 'owner',
        ),
      ];

      mockRepo.invitations = [
        EnvironmentInvitationModel(
          id: 'inv_1',
          environmentId: 'env_proj',
          environmentName: 'Proyecto Hackathon',
          senderId: 'u2',
          senderUsername: 'Elena',
          receiverId: 'u1',
          createdAt: DateTime.now(),
        ),
      ];

      controller = EnvironmentController(environmentRepository: mockRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('EnvironmentSelectorChip renders active workspace and opens sheet on tap',
        (WidgetTester tester) async {
      await controller.initialize('u1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                EnvironmentSelectorChip(
                  environmentController: controller,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify chip shows "Mi Espacio"
      expect(find.text('Mi Espacio'), findsOneWidget);

      // Tap chip
      await tester.tap(find.byType(EnvironmentSelectorChip));
      await tester.pumpAndSettle();

      // Bottom sheet is now open
      expect(find.text('Entornos de Trabajo'), findsOneWidget);
      expect(find.text('Todos los entornos'), findsOneWidget);
      expect(find.text('Piso Compartido'), findsOneWidget);
      expect(find.text('Crear Nuevo Entorno'), findsOneWidget);

      // Tap "Todos los entornos"
      await tester.tap(find.text('Todos los entornos'));
      await tester.pumpAndSettle();

      expect(controller.isAllSelected, isTrue);
      expect(find.text('Todos'), findsOneWidget);
    });

    testWidgets('CreateEnvironmentModal validates input length and calls controller',
        (WidgetTester tester) async {
      await controller.initialize('u1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateEnvironmentModal(
              environmentController: controller,
            ),
          ),
        ),
      );

      expect(find.text('Nuevo Entorno'), findsOneWidget);
      expect(find.text('Crear Entorno'), findsOneWidget);

      // Submit short name
      await tester.enterText(find.byType(TextFormField), '12');
      await tester.tap(find.text('Crear Entorno'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre debe tener al menos 3 caracteres'), findsOneWidget);
      expect(mockRepo.createCalled, isFalse);

      // Submit valid name
      await tester.enterText(find.byType(TextFormField), 'Oficina Central');
      await tester.tap(find.text('Crear Entorno'));
      await tester.pumpAndSettle();

      expect(mockRepo.createCalled, isTrue);
      expect(mockRepo.lastCreatedName, equals('Oficina Central'));
    });

    testWidgets('EnvironmentInvitationTile renders invitation details and triggers callbacks',
        (WidgetTester tester) async {
      final inv = EnvironmentInvitationModel(
        id: 'inv_10',
        environmentId: 'env_10',
        environmentName: 'Equipo de Desarrollo',
        senderId: 'u3',
        senderUsername: 'Marcos',
        receiverId: 'u1',
        createdAt: DateTime.now(),
      );

      bool acceptClicked = false;
      bool declineClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentInvitationTile(
              invitation: inv,
              onAccept: () => acceptClicked = true,
              onDecline: () => declineClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Equipo de Desarrollo'), findsOneWidget);
      expect(find.text('Invitación de @Marcos'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      expect(acceptClicked, isTrue);

      await tester.tap(find.text('Rechazar'));
      expect(declineClicked, isTrue);
    });

    testWidgets('MigrateContentDialog triggers onMigrateAndProceed on confirmation',
        (WidgetTester tester) async {
      bool migrateCalled = false;
      bool proceedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MigrateContentDialog.show(
                    context,
                    environmentName: 'Piso Compartido',
                    actionTitle: 'Eliminar',
                    onMigrateAndProceed: () async {
                      migrateCalled = true;
                      return true;
                    },
                    onProceedWithoutMigrating: () async {
                      proceedCalled = true;
                      return true;
                    },
                  );
                },
                child: const Text('Abrir Dialogo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Dialogo'));
      await tester.pumpAndSettle();

      expect(find.text('¿Deseas migrar tu contenido?'), findsOneWidget);
      expect(find.text('Migrar a "Mi Espacio" y Continuar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);

      await tester.tap(find.text('Migrar a "Mi Espacio" y Continuar'));
      await tester.pumpAndSettle();

      expect(migrateCalled, isTrue);
      expect(proceedCalled, isFalse);
    });
  });
}
