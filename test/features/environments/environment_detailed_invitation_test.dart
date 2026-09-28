import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_invitation_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_model.dart';
import 'package:marth_app/features/environments/domain/repositories/i_environment_repository.dart';
import 'package:marth_app/features/environments/presentation/controllers/environment_controller.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_invitation_details_modal.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_invitation_tile.dart';
import 'package:marth_app/features/environments/presentation/widgets/invite_to_environment_sheet.dart';
import 'package:marth_app/features/profile/domain/models/avatar_data.dart';
import 'package:marth_app/features/profile/domain/models/profile_model.dart';
import 'package:marth_app/features/profile/presentation/widgets/user_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockDetailedEnvironmentRepository implements IEnvironmentRepository {
  List<EnvironmentModel> environments = [];
  List<EnvironmentInvitationModel> invitations = [];
  Map<String, List<EnvironmentMemberModel>> environmentMembers = {};

  @override
  Future<List<EnvironmentModel>> getEnvironments(String userId) async =>
      List.from(environments);

  @override
  Future<EnvironmentModel?> ensurePersonalEnvironment() async => null;

  @override
  Future<List<String>> getPendingInvitedUserIds(String environmentId) async =>
      [];

  @override
  Future<EnvironmentModel?> createEnvironment({
    required String name,
    String? icon,
    String? color,
  }) async =>
      null;

  @override
  Future<bool> deleteEnvironment(String environmentId) async => true;

  @override
  Future<List<EnvironmentMemberModel>> getEnvironmentMembers(
      String environmentId) async {
    return List.from(environmentMembers[environmentId] ?? []);
  }

  @override
  RealtimeChannel? subscribeToMembers(
          String environmentId, void Function() onMembersChanged) =>
      null;

  @override
  Future<bool> removeMember(
          {required String environmentId, required String userId}) async =>
      true;

  @override
  Future<bool> leaveEnvironment(
          {required String environmentId, required String userId}) async =>
      true;

  @override
  Future<List<EnvironmentInvitationModel>> getPendingInvitations(
          String userId) async =>
      List.from(invitations);

  @override
  Future<bool> sendInvitation({
    required String environmentId,
    required String receiverId,
    required String senderId,
  }) async =>
      true;

  @override
  Future<bool> respondInvitation({
    required String invitationId,
    required bool accept,
  }) async =>
      true;

  @override
  RealtimeChannel? subscribeToInvitations(
          String userId, void Function() onInvitationReceived) =>
      null;

  @override
  Future<bool> migrateContent({
    required String sourceEnvironmentId,
    required String targetEnvironmentId,
  }) async =>
      true;

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {}
}

void main() {
  group('EnvironmentInvitationModel Tests', () {
    test('serializes and deserializes senderAvatarData and members correctly', () {
      final json = {
        'id': 'inv_123',
        'environment_id': 'env_456',
        'environment_name': 'Hogar Dulce Hogar',
        'sender_id': 'user_host',
        'sender_username': 'AliceHost',
        'sender_avatar_type': 'icon',
        'sender_avatar_icon': 'home',
        'sender_avatar_bg_color': '#4CAF50',
        'receiver_id': 'user_guest',
        'status': 'pending',
        'created_at': '2026-09-28T12:00:00.000Z',
        'members': [
          {
            'environment_id': 'env_456',
            'user_id': 'user_host',
            'role': 'owner',
            'joined_at': '2026-09-01T10:00:00.000Z',
            'username': 'AliceHost',
            'avatar_type': 'icon',
            'avatar_icon': 'home',
            'avatar_bg_color': '#4CAF50',
          },
          {
            'environment_id': 'env_456',
            'user_id': 'user_roommate1',
            'role': 'member',
            'joined_at': '2026-09-05T10:00:00.000Z',
            'username': 'BobRoommate',
            'avatar_type': 'initials',
          },
          {
            'environment_id': 'env_456',
            'user_id': 'user_roommate2',
            'role': 'member',
            'joined_at': '2026-09-10T10:00:00.000Z',
            'username': 'CharlieRoommate',
            'avatar_type': 'initials',
          },
        ],
      };

      final inv = EnvironmentInvitationModel.fromJson(json);

      expect(inv.id, equals('inv_123'));
      expect(inv.environmentName, equals('Hogar Dulce Hogar'));
      expect(inv.senderUsername, equals('AliceHost'));
      expect(inv.senderAvatarData.type, equals(AvatarType.icon));
      expect(inv.senderAvatarData.iconKey, equals('home'));
      expect(inv.members.length, equals(3));

      // otherMembers excluye al host (user_host)
      expect(inv.otherMembers.length, equals(2));
      expect(inv.otherMembers.map((m) => m.username),
          containsAll(['BobRoommate', 'CharlieRoommate']));
      expect(inv.otherMembers.any((m) => m.userId == 'user_host'), isFalse);

      final serialized = inv.toJson();
      expect(serialized['sender_avatar_type'], equals('icon'));
      expect(serialized['members'], isA<List>());
      expect((serialized['members'] as List).length, equals(3));
    });
  });

  group('EnvironmentInvitationTile Detailed Invitation Tests', () {
    testWidgets(
      'renders inviter photo/avatar, username, environment name, and other members with avatars and names',
      (tester) async {
        final members = [
          EnvironmentMemberModel(
            environmentId: 'env_1',
            userId: 'u_host',
            role: 'owner',
            joinedAt: DateTime(2026, 9, 1),
            username: 'MariaHost',
            avatarData: const AvatarData.icon(iconKey: 'star', bgColorHex: '#FF9800'),
          ),
          EnvironmentMemberModel(
            environmentId: 'env_1',
            userId: 'u_other1',
            role: 'member',
            joinedAt: DateTime(2026, 9, 2),
            username: 'DavidCompi',
            avatarData: const AvatarData.initials(),
          ),
          EnvironmentMemberModel(
            environmentId: 'env_1',
            userId: 'u_other2',
            role: 'member',
            joinedAt: DateTime(2026, 9, 3),
            username: 'ElenaCompi',
            avatarData: const AvatarData.initials(),
          ),
        ];

        final invitation = EnvironmentInvitationModel(
          id: 'inv_1',
          environmentId: 'env_1',
          environmentName: 'Piso Compartido Sol',
          senderId: 'u_host',
          senderUsername: 'MariaHost',
          senderAvatarData:
              const AvatarData.icon(iconKey: 'star', bgColorHex: '#FF9800'),
          members: members,
          receiverId: 'u_me',
          createdAt: DateTime.now(),
        );

        bool acceptCalled = false;
        bool declineCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnvironmentInvitationTile(
                invitation: invitation,
                onAccept: () => acceptCalled = true,
                onDecline: () => declineCalled = true,
              ),
            ),
          ),
        );

        // 1. Verifica nombre del entorno
        expect(find.text('Piso Compartido Sol'), findsOneWidget);

        // 2. Verifica nombre del anfitrión
        expect(find.text('Invitación de @MariaHost'), findsOneWidget);

        // 3. Verifica etiqueta de Anfitrión
        expect(find.text('Anfitrión'), findsOneWidget);

        // 4. Verifica que los demás integrantes aparecen con su nombre y avatar
        expect(find.text('Otros integrantes (2):'), findsOneWidget);
        expect(find.text('DavidCompi'), findsOneWidget);
        expect(find.text('ElenaCompi'), findsOneWidget);

        // Verifica que hay avatares renderizados (anfitrión + 2 compañeros)
        expect(find.byType(UserAvatar), findsNWidgets(3));

        // 5. Botones de acción funcionan
        await tester.tap(find.text('Aceptar'));
        expect(acceptCalled, isTrue);

        await tester.tap(find.text('Rechazar'));
        expect(declineCalled, isTrue);
      },
    );

    testWidgets(
      'renders initial member note when there are no other members in the environment',
      (tester) async {
        final invitation = EnvironmentInvitationModel(
          id: 'inv_empty',
          environmentId: 'env_empty',
          environmentName: 'Proyecto Secreto',
          senderId: 'u_solo',
          senderUsername: 'SoloLeader',
          members: [
            EnvironmentMemberModel(
              environmentId: 'env_empty',
              userId: 'u_solo',
              role: 'owner',
              joinedAt: DateTime(2026, 9, 1),
              username: 'SoloLeader',
              avatarData: const AvatarData.initials(),
            ),
          ],
          receiverId: 'u_me',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnvironmentInvitationTile(
                invitation: invitation,
                onAccept: () {},
                onDecline: () {},
              ),
            ),
          ),
        );

        expect(find.text('Proyecto Secreto'), findsOneWidget);
        expect(find.text('Invitación de @SoloLeader'), findsOneWidget);
        expect(
          find.text('Serás el primer nuevo integrante en unirte'),
          findsOneWidget,
        );
        expect(find.textContaining('Otros integrantes'), findsNothing);
      },
    );

    testWidgets('tapping tile opens EnvironmentInvitationDetailsModal',
        (tester) async {
      final invitation = EnvironmentInvitationModel(
        id: 'inv_modal',
        environmentId: 'env_modal',
        environmentName: 'Casa Rural Pirineos',
        senderId: 'u_h',
        senderUsername: 'GuiaSender',
        members: [
          EnvironmentMemberModel(
            environmentId: 'env_modal',
            userId: 'u_h',
            role: 'owner',
            joinedAt: DateTime(2026, 9, 1),
            username: 'GuiaSender',
            avatarData: const AvatarData.initials(),
          ),
          EnvironmentMemberModel(
            environmentId: 'env_modal',
            userId: 'u_friend',
            role: 'member',
            joinedAt: DateTime(2026, 9, 2),
            username: 'AmigoViajero',
            avatarData: const AvatarData.initials(),
          ),
        ],
        receiverId: 'u_me',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentInvitationTile(
              invitation: invitation,
              onAccept: () {},
              onDecline: () {},
            ),
          ),
        ),
      );

      // Toca la tarjeta
      await tester.tap(find.byType(EnvironmentInvitationTile));
      await tester.pumpAndSettle();

      // Verifica apertura del modal de detalles completos
      expect(find.byType(EnvironmentInvitationDetailsModal), findsOneWidget);
      expect(find.text('Invitación a Entorno'), findsOneWidget);
      expect(find.text('Espacio Colaborativo'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EnvironmentInvitationDetailsModal),
          matching: find.text('AmigoViajero'),
        ),
        findsOneWidget,
      );
      expect(find.text('Aceptar y unirme'), findsOneWidget);
    });
  });

  group('InviteToEnvironmentSheet Detailed Flow Tests', () {
    testWidgets(
      'selecting collaborative environment shows confirmation preview with host, friend and members',
      (tester) async {
        final mockRepo = MockDetailedEnvironmentRepository();
        final envColab = EnvironmentModel(
          id: 'env_colab_1',
          name: 'Mi Piso Fantástico',
          isPersonal: false,
          createdBy: 'u_current',
          createdAt: DateTime(2026, 9, 1),
          role: 'owner',
        );
        mockRepo.environments.add(envColab);
        mockRepo.environmentMembers['env_colab_1'] = [
          EnvironmentMemberModel(
            environmentId: 'env_colab_1',
            userId: 'u_current',
            role: 'owner',
            joinedAt: DateTime(2026, 9, 1),
            username: 'CurrentOwner',
            avatarData: const AvatarData.initials(),
          ),
          EnvironmentMemberModel(
            environmentId: 'env_colab_1',
            userId: 'u_roommate',
            role: 'member',
            joinedAt: DateTime(2026, 9, 5),
            username: 'CompiExistente',
            avatarData: const AvatarData.initials(),
          ),
        ];

        final controller =
            EnvironmentController(environmentRepository: mockRepo);
        await controller.initialize('u_current');

        final friendToInvite = ProfileModel(
          id: 'u_friend_target',
          username: 'NuevoAmigo',
          avatarData: const AvatarData.initials(),
          updatedAt: DateTime(2026, 9, 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => InviteToEnvironmentSheet.show(
                    context,
                    friend: friendToInvite,
                    environmentController: controller,
                  ),
                  child: const Text('Abrir Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Sheet'));
        await tester.pumpAndSettle();

        // 1. Selector de entornos disponible
        expect(find.text('Invitar a "NuevoAmigo"'), findsOneWidget);
        expect(find.text('Mi Piso Fantástico'), findsOneWidget);

        // 2. Seleccionar el entorno
        await tester.tap(find.text('Mi Piso Fantástico'));
        await tester.pumpAndSettle();

        // 3. Vista de Confirmar invitación
        expect(find.text('Confirmar invitación'), findsOneWidget);
        expect(find.text('Invitando a @NuevoAmigo'), findsOneWidget);
        expect(find.text('CompiExistente'), findsOneWidget);
        expect(find.text('Enviar invitación'), findsOneWidget);

        // 4. Enviar invitación
        await tester.tap(find.text('Enviar invitación'));
        await tester.pumpAndSettle();

        // Sheet cerrado tras éxito
        expect(find.byType(InviteToEnvironmentSheet), findsNothing);
      },
    );
  });
}
