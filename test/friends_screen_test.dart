import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/friends/domain/models/friend_request_model.dart';
import 'package:marth_app/features/friends/domain/models/profile_model.dart';
import 'package:marth_app/features/friends/presentation/controllers/friends_controller.dart';
import 'package:marth_app/features/friends/presentation/screens/friends_screen.dart';
import 'package:marth_app/features/settings/presentation/widgets/user_profile_card.dart';
import 'friends_controller_test.dart';

void main() {
  group('FriendsScreen & Profile UI Widget Tests', () {
    late ControllerTestFriendsService service;
    late FriendsController controller;

    setUp(() {
      service = ControllerTestFriendsService();
      service.profiles['user-me'] = ProfileModel(
        id: 'user-me',
        username: 'arturo_dev',
        updatedAt: DateTime.now(),
      );
      service.profiles['user-friend-1'] = ProfileModel(
        id: 'user-friend-1',
        username: 'martha_star',
        updatedAt: DateTime.now(),
      );
      service.profiles['user-requester'] = ProfileModel(
        id: 'user-requester',
        username: 'carlos_99',
        updatedAt: DateTime.now(),
      );

      // Solicitud entrante pendiente de carlos_99
      service.requests.add(FriendRequestModel(
        id: 'req-pending-1',
        senderId: 'user-requester',
        receiverId: 'user-me',
        status: 'pending',
        createdAt: DateTime.now(),
        senderProfile: service.profiles['user-requester'],
      ));

      // Amigo aceptado: martha_star
      service.requests.add(FriendRequestModel(
        id: 'req-accepted-1',
        senderId: 'user-me',
        receiverId: 'user-friend-1',
        status: 'accepted',
        createdAt: DateTime.now(),
      ));

      controller = FriendsController(friendsService: service);
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('FriendsScreen renders search, pending requests and friends list',
        (WidgetTester tester) async {
      await controller.initialize('user-me');

      await tester.pumpWidget(
        MaterialApp(
          home: FriendsScreen(friendsController: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar títulos
      expect(find.text('Amigos y Solicitudes'), findsOneWidget);
      expect(find.text('Mi Código de Amigo'), findsOneWidget);
      expect(find.text('Enviar Solicitud de Amistad'), findsOneWidget);
      expect(find.text('Solicitudes Recibidas (1)'), findsOneWidget);
      expect(find.text('Mis Amigos (1)'), findsOneWidget);

      // Verificar elementos de la solicitud entrante
      expect(find.text('carlos_99'), findsOneWidget);
      expect(find.text('Quiere ser tu amigo'), findsOneWidget);
      expect(find.byTooltip('Aceptar'), findsOneWidget);
      expect(find.byTooltip('Rechazar'), findsOneWidget);

      // Verificar amigo aceptado
      expect(find.text('martha_star'), findsOneWidget);
      expect(find.text('Conectado en MarthApp'), findsOneWidget);
    });

    testWidgets('Tapping Aceptar on pending request moves user to friends list',
        (WidgetTester tester) async {
      await controller.initialize('user-me');

      await tester.pumpWidget(
        MaterialApp(
          home: FriendsScreen(friendsController: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.incomingRequests.length, equals(1));
      expect(controller.friends.length, equals(1));

      // Scroll hasta que el botón Aceptar sea visible y pulsar
      final aceptarBtn = find.byTooltip('Aceptar');
      await tester.ensureVisible(aceptarBtn);
      await tester.pumpAndSettle();
      await tester.tap(aceptarBtn);
      await tester.pumpAndSettle();

      // Ya no hay solicitudes pendientes y ahora hay 2 amigos
      expect(controller.incomingRequests.length, equals(0));
      expect(controller.friends.length, equals(2));
      expect(find.text('Solicitudes Recibidas (1)'), findsNothing);
      expect(find.text('Mis Amigos (2)'), findsOneWidget);
    });

    testWidgets('UserProfileCard allows editing and saving username',
        (WidgetTester tester) async {
      await controller.initialize('user-me');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserProfileCard(
              email: 'arturo@marthapp.com',
              friendsController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@arturo_dev'), findsOneWidget);
      expect(find.byTooltip('Editar nombre de usuario'), findsOneWidget);

      // Pulsar lápiz de edición
      await tester.tap(find.byTooltip('Editar nombre de usuario'));
      await tester.pumpAndSettle();

      // Aparece campo de texto
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Guardar'), findsOneWidget);
      expect(find.byTooltip('Cancelar'), findsOneWidget);

      // Escribir nuevo nombre
      await tester.enterText(find.byType(TextField), 'arturo_king');
      await tester.tap(find.byTooltip('Guardar'));
      await tester.pumpAndSettle();

      // Verifica que se guardó y volvió a modo vista
      expect(find.text('@arturo_king'), findsOneWidget);
      expect(controller.currentProfile?.username, equals('arturo_king'));
    });
  });
}
