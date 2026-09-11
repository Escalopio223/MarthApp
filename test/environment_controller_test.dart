import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_invitation_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_model.dart';
import 'package:marth_app/features/environments/domain/repositories/i_environment_repository.dart';
import 'package:marth_app/features/environments/presentation/controllers/environment_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockEnvironmentRepository implements IEnvironmentRepository {
  List<EnvironmentModel> environments = [];
  List<EnvironmentInvitationModel> invitations = [];
  bool createCalled = false;
  bool deleteCalled = false;
  bool respondCalled = false;
  bool migrateCalled = false;

  String? lastCreatedName;
  String? lastDeletedId;
  String? lastSourceMigrate;
  String? lastTargetMigrate;

  @override
  Future<List<EnvironmentModel>> getEnvironments(String userId) async {
    return List.from(environments);
  }

  @override
  Future<EnvironmentModel?> ensurePersonalEnvironment() async {
    final existing = environments.where((e) => e.isPersonal).firstOrNull;
    if (existing != null) return existing;
    final personal = EnvironmentModel(
      id: 'env_personal',
      name: 'Mi Espacio',
      isPersonal: true,
      createdBy: 'u1',
      createdAt: DateTime.now(),
      role: 'owner',
    );
    environments.insert(0, personal);
    return personal;
  }

  @override
  Future<List<String>> getPendingInvitedUserIds(String environmentId) async {
    return invitations
        .where((i) => i.environmentId == environmentId && i.status == 'pending')
        .map((i) => i.receiverId)
        .toList();
  }

  @override
  Future<EnvironmentModel?> createEnvironment({required String name}) async {
    createCalled = true;
    lastCreatedName = name;
    final newEnv = EnvironmentModel(
      id: 'env_new_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      isPersonal: false,
      createdBy: 'u1',
      createdAt: DateTime.now(),
      role: 'owner',
    );
    environments.add(newEnv);
    return newEnv;
  }

  @override
  Future<bool> deleteEnvironment(String environmentId) async {
    deleteCalled = true;
    lastDeletedId = environmentId;
    environments.removeWhere((e) => e.id == environmentId);
    return true;
  }

  @override
  Future<List<EnvironmentMemberModel>> getEnvironmentMembers(
      String environmentId) async {
    return [];
  }

  @override
  Future<bool> removeMember(
      {required String environmentId, required String userId}) async {
    return true;
  }

  @override
  Future<bool> leaveEnvironment(
      {required String environmentId, required String userId}) async {
    environments.removeWhere((e) => e.id == environmentId);
    return true;
  }

  @override
  Future<List<EnvironmentInvitationModel>> getPendingInvitations(
      String userId) async {
    return List.from(invitations);
  }

  @override
  Future<bool> sendInvitation({
    required String environmentId,
    required String receiverId,
    required String senderId,
  }) async {
    return true;
  }

  @override
  Future<bool> respondInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    respondCalled = true;
    invitations.removeWhere((i) => i.id == invitationId);
    if (accept) {
      environments.add(EnvironmentModel(
        id: 'env_accepted',
        name: 'Entorno Aceptado',
        isPersonal: false,
        createdBy: 'u2',
        createdAt: DateTime.now(),
        role: 'member',
      ));
    }
    return true;
  }

  @override
  Future<bool> migrateContent({
    required String sourceEnvironmentId,
    required String targetEnvironmentId,
  }) async {
    migrateCalled = true;
    lastSourceMigrate = sourceEnvironmentId;
    lastTargetMigrate = targetEnvironmentId;
    return true;
  }

  @override
  RealtimeChannel? subscribeToInvitations(
    String userId,
    void Function() onInvitationsChanged,
  ) {
    return null;
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {}
}

void main() {
  group('EnvironmentController Unit Tests', () {
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
          id: 'env_collab',
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
          environmentId: 'env_shared_2',
          environmentName: 'Proyecto Flutter',
          senderId: 'u2',
          senderUsername: 'Carlos',
          receiverId: 'u1',
          createdAt: DateTime.now(),
        ),
      ];

      controller = EnvironmentController(environmentRepository: mockRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes and selects personal environment "Mi Espacio" by default',
        () async {
      await controller.initialize('u1');

      expect(controller.environments.length, equals(2));
      expect(controller.activeEnvironment, isNotNull);
      expect(controller.activeEnvironment?.isPersonal, isTrue);
      expect(controller.activeEnvironment?.name, equals('Mi Espacio'));
      expect(controller.isAllSelected, isFalse);
      expect(controller.pendingInvitationsCount, equals(1));
    });

    test('selectEnvironment toggles active workspace and sets isAllSelected to false',
        () async {
      await controller.initialize('u1');

      final collabEnv = controller.environments[1];
      controller.selectEnvironment(collabEnv);

      expect(controller.activeEnvironment?.id, equals('env_collab'));
      expect(controller.isAllSelected, isFalse);
    });

    test('selectAllEnvironments activates "Todos" global pseudo-environment',
        () async {
      await controller.initialize('u1');

      controller.selectAllEnvironments();

      expect(controller.isAllSelected, isTrue);
      expect(controller.activeEnvironment, isNull);
    });

    test('createEnvironment creates workspace atomically and makes it active',
        () async {
      await controller.initialize('u1');

      final ok = await controller.createEnvironment('Nuevo Viaje');
      expect(ok, isTrue);
      expect(mockRepo.createCalled, isTrue);
      expect(mockRepo.lastCreatedName, equals('Nuevo Viaje'));
      expect(controller.activeEnvironment?.name, equals('Nuevo Viaje'));
      expect(controller.isAllSelected, isFalse);
      expect(controller.environments.length, equals(3));
    });

    test('createEnvironment rejects names with less than 3 characters',
        () async {
      await controller.initialize('u1');

      final ok = await controller.createEnvironment('ab');
      expect(ok, isFalse);
      expect(mockRepo.createCalled, isFalse);
      expect(controller.errorMessage, contains('al menos 3 caracteres'));
    });

    test('deleteEnvironment removes workspace and falls back to personal space if active',
        () async {
      await controller.initialize('u1');

      // Select collaborative environment
      controller.selectEnvironment(controller.environments[1]);
      expect(controller.activeEnvironment?.id, equals('env_collab'));

      // Delete it
      final ok = await controller.deleteEnvironment('env_collab');
      expect(ok, isTrue);
      expect(mockRepo.deleteCalled, isTrue);
      expect(mockRepo.lastDeletedId, equals('env_collab'));
      expect(controller.environments.any((e) => e.id == 'env_collab'), isFalse);

      // Falls back to Mi Espacio
      expect(controller.activeEnvironment?.id, equals('env_personal'));
      expect(controller.isAllSelected, isFalse);
    });

    test('respondInvitation accepts invite and updates environments list',
        () async {
      await controller.initialize('u1');
      expect(controller.pendingInvitationsCount, equals(1));

      final ok = await controller.respondInvitation(
        invitationId: 'inv_1',
        accept: true,
      );

      expect(ok, isTrue);
      expect(mockRepo.respondCalled, isTrue);
      expect(controller.pendingInvitationsCount, equals(0));
      expect(controller.environments.any((e) => e.id == 'env_accepted'), isTrue);
    });

    test('migrateAllContent delegates atomic RPC migration', () async {
      await controller.initialize('u1');

      final ok = await controller.migrateAllContent(
        sourceEnvironmentId: 'env_collab',
        targetEnvironmentId: 'env_personal',
      );

      expect(ok, isTrue);
      expect(mockRepo.migrateCalled, isTrue);
      expect(mockRepo.lastSourceMigrate, equals('env_collab'));
      expect(mockRepo.lastTargetMigrate, equals('env_personal'));
    });

    test('inviteFriend strictly rejects inviting anyone to a personal environment',
        () async {
      await controller.initialize('u1');

      final ok = await controller.inviteFriend(
        environmentId: 'env_personal',
        friendId: 'f99',
      );

      expect(ok, isFalse);
      expect(controller.errorMessage, contains('espacio personal es privado'));
    });

    test('inviteFriend sends invitation successfully to collaborative environment',
        () async {
      await controller.initialize('u1');

      final ok = await controller.inviteFriend(
        environmentId: 'env_collab',
        friendId: 'f99',
      );

      expect(ok, isTrue);
      expect(controller.successMessage, contains('enviada con éxito'));
    });

    test('getPendingInvitedUserIds retrieves pending user ids for environment',
        () async {
      mockRepo.invitations.add(
        EnvironmentInvitationModel(
          id: 'inv_test_pending',
          environmentId: 'env_collab',
          environmentName: 'Entorno Colaborativo',
          senderId: 'u1',
          senderUsername: 'Usuario',
          receiverId: 'friend_123',
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      );

      final ids = await controller.getPendingInvitedUserIds('env_collab');
      expect(ids, contains('friend_123'));
    });
  });
}
