import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_model.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_danger_zone.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_members_list.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_selection_list.dart';
import 'package:marth_app/features/environments/presentation/widgets/friend_invite_tile.dart';
import 'package:marth_app/features/environments/presentation/widgets/personal_environment_view.dart';
import 'package:marth_app/features/friends/domain/models/profile_model.dart';

void main() {
  group('PersonalEnvironmentView Tests', () {
    testWidgets('renders protected personal space details correctly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PersonalEnvironmentView(),
          ),
        ),
      );

      expect(find.text('Espacio Personal Protegido'), findsOneWidget);
      expect(find.textContaining('Este es tu entorno base personal'),
          findsOneWidget);
      expect(find.textContaining('Acceso exclusivo para tu usuario'),
          findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      // Verify no invite or delete buttons are present
      expect(find.text('Eliminar Entorno'), findsNothing);
      expect(find.text('Abandonar Entorno'), findsNothing);
      expect(find.text('Invitar Amigo'), findsNothing);
    });
  });

  group('EnvironmentDangerZone Tests', () {
    testWidgets('renders delete button for owner and triggers callback',
        (tester) async {
      bool deleteCalled = false;
      bool leaveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentDangerZone(
              isOwner: true,
              isActionLoading: false,
              onDeleteEnvironment: () => deleteCalled = true,
              onLeaveEnvironment: () => leaveCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Eliminar Entorno'), findsOneWidget);
      expect(find.text('Abandonar Entorno'), findsNothing);

      await tester.tap(find.text('Eliminar Entorno'));
      await tester.pump();

      expect(deleteCalled, isTrue);
      expect(leaveCalled, isFalse);
    });

    testWidgets('renders leave button for non-owner and triggers callback',
        (tester) async {
      bool deleteCalled = false;
      bool leaveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentDangerZone(
              isOwner: false,
              isActionLoading: false,
              onDeleteEnvironment: () => deleteCalled = true,
              onLeaveEnvironment: () => leaveCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Abandonar Entorno'), findsOneWidget);
      expect(find.text('Eliminar Entorno'), findsNothing);

      await tester.tap(find.text('Abandonar Entorno'));
      await tester.pump();

      expect(leaveCalled, isTrue);
      expect(deleteCalled, isFalse);
    });

    testWidgets('shows loading state when isActionLoading is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentDangerZone(
              isOwner: true,
              isActionLoading: true,
              onDeleteEnvironment: () {},
              onLeaveEnvironment: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('FriendInviteTile Tests', () {
    final mockFriend = ProfileModel(
      id: 'friend_1',
      username: 'Lucas',
      avatarData: const AvatarData(
        type: AvatarType.icon,
        iconKey: 'gamepad',
        bgColorHex: '#6C5CE7',
      ),
      updatedAt: DateTime.now(),
    );

    testWidgets('renders alreadyMember status badge and no invite button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendInviteTile(
              friend: mockFriend,
              status: FriendInvitationStatus.alreadyMember,
              onInvite: () {},
            ),
          ),
        ),
      );

      expect(find.text('Lucas'), findsOneWidget);
      expect(find.text('Miembro'), findsOneWidget);
      expect(find.text('Invitar'), findsNothing);
    });

    testWidgets('renders pending status badge and no invite button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendInviteTile(
              friend: mockFriend,
              status: FriendInvitationStatus.pending,
              onInvite: () {},
            ),
          ),
        ),
      );

      expect(find.text('Lucas'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Invitar'), findsNothing);
    });

    testWidgets('renders notInvited status with interactive invite button',
        (tester) async {
      bool inviteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendInviteTile(
              friend: mockFriend,
              status: FriendInvitationStatus.notInvited,
              onInvite: () => inviteTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Lucas'), findsOneWidget);
      expect(find.text('Invitar'), findsOneWidget);

      await tester.tap(find.text('Invitar'));
      await tester.pump();

      expect(inviteTriggered, isTrue);
    });

    testWidgets(
        'shows loading spinner when isLoading is true and ignores tap',
        (tester) async {
      bool inviteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendInviteTile(
              friend: mockFriend,
              status: FriendInvitationStatus.notInvited,
              isLoading: true,
              onInvite: () => inviteTriggered = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Invitar'), findsNothing);
      expect(inviteTriggered, isFalse);
    });
  });

  group('EnvironmentMembersList Tests', () {
    final members = [
      EnvironmentMemberModel(
        environmentId: 'env_1',
        userId: 'u1',
        role: 'owner',
        joinedAt: DateTime.now(),
        username: 'Elena',
        avatarData: const AvatarData(
            type: AvatarType.icon,
            iconKey: 'crown',
            bgColorHex: '#00E5FF'),
      ),
      EnvironmentMemberModel(
        environmentId: 'env_1',
        userId: 'u2',
        role: 'member',
        joinedAt: DateTime.now(),
        username: 'Carlos',
        avatarData: const AvatarData(
            type: AvatarType.icon,
            iconKey: 'smile',
            bgColorHex: '#B388FF'),
      ),
    ];

    testWidgets('renders member cards with roles correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentMembersList(
              members: members,
              isOwner: true,
            ),
          ),
        ),
      );

      expect(find.text('Miembros (2)'), findsOneWidget);
      expect(find.text('Elena'), findsOneWidget);
      expect(find.text('Propietario'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.text('Miembro'), findsOneWidget);
    });

    testWidgets(
        'shows invite button and triggers callback when canInviteFriends is true',
        (tester) async {
      bool inviteClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentMembersList(
              members: members,
              isOwner: true,
              canInviteFriends: true,
              onInviteFriends: () => inviteClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Invitar Amigo'), findsOneWidget);
      await tester.tap(find.text('Invitar Amigo'));
      await tester.pump();

      expect(inviteClicked, isTrue);
    });

    testWidgets('allows owner to expel non-owner members', (tester) async {
      EnvironmentMemberModel? removedMember;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentMembersList(
              members: members,
              isOwner: true,
              onRemoveMember: (m) => removedMember = m,
            ),
          ),
        ),
      );

      // Expect exactly 1 expel button (for Carlos, not for owner Elena)
      final expelButton = find.byIcon(Icons.person_remove_rounded);
      expect(expelButton, findsOneWidget);

      await tester.tap(expelButton);
      await tester.pump();

      expect(removedMember?.userId, 'u2');
    });

    testWidgets('shows empty state when members list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnvironmentMembersList(
              members: [],
              isOwner: true,
            ),
          ),
        ),
      );

      expect(find.text('No se encontraron miembros'), findsOneWidget);
    });
  });

  group('EnvironmentSelectionList Tests', () {
    final environments = [
      EnvironmentModel(
        id: 'env_1',
        name: 'Mi Espacio',
        isPersonal: true,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        role: 'owner',
      ),
      EnvironmentModel(
        id: 'env_2',
        name: 'Piso Compartido',
        isPersonal: false,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        role: 'owner',
      ),
    ];

    testWidgets(
        'renders environments and triggers onSelect and onManage callbacks',
        (tester) async {
      EnvironmentModel? selectedEnv;
      EnvironmentModel? managedEnv;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentSelectionList(
              environments: environments,
              selectedEnvironmentId: 'env_1',
              onSelect: (e) => selectedEnv = e,
              onManage: (e) => managedEnv = e,
            ),
          ),
        ),
      );

      expect(find.text('Mi Espacio'), findsOneWidget);
      expect(find.text('Piso Compartido'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Propietario'), findsOneWidget);

      // Tap on second environment
      await tester.tap(find.text('Piso Compartido'));
      await tester.pump();

      expect(selectedEnv?.id, 'env_2');

      // Tap on manage button
      final manageButtons = find.byIcon(Icons.tune_rounded);
      expect(manageButtons, findsNWidgets(2));

      await tester.tap(manageButtons.first);
      await tester.pump();

      expect(managedEnv?.id, 'env_1');
    });

    testWidgets('displays custom empty message when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnvironmentSelectionList(
              environments: const [],
              emptyMessage: 'No tienes entornos colaborativos',
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('No tienes entornos colaborativos'), findsOneWidget);
    });
  });
}
