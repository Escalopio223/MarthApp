import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/profile/domain/models/avatar_data.dart';
import 'package:marth_app/features/profile/domain/models/profile_model.dart';
import 'package:marth_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:marth_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockProfileRepository implements IProfileRepository {
  ProfileModel? mockProfile;
  String? lastUpdatedUsername;
  String? lastSelectedIconKey;
  String? lastSelectedColorHex;
  bool returnError = false;

  @override
  Future<ProfileModel?> getProfile(String userId, {String? defaultEmail}) async {
    if (returnError) throw Exception('Database error');
    return mockProfile ??
        ProfileModel(
          id: userId,
          username: defaultEmail?.split('@').first ?? 'test_user',
          avatarData: const AvatarData.initials(),
          updatedAt: DateTime.now(),
        );
  }

  @override
  Future<bool> updateUsername(String userId, String newUsername) async {
    if (returnError) throw Exception('Collision error');
    lastUpdatedUsername = newUsername;
    return true;
  }

  @override
  Future<bool> updateAvatarIcon(
    String userId, {
    required String iconKey,
    required String colorHex,
  }) async {
    if (returnError) return false;
    lastSelectedIconKey = iconKey;
    lastSelectedColorHex = colorHex;
    return true;
  }

  @override
  Future<String?> uploadAvatarImage(
    String userId, {
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    if (returnError) return null;
    return 'https://supabase.co/storage/v1/object/public/avatars/$userId/avatar.png';
  }

  @override
  Future<bool> resetToInitials(String userId) async {
    return true;
  }

  @override
  RealtimeChannel? subscribeToProfile(
    String userId,
    void Function(ProfileModel profile) onProfileUpdated,
  ) {
    return null;
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {}
}

void main() {
  group('ProfileController Tests', () {
    late MockProfileRepository mockRepo;
    late ProfileController controller;

    setUp(() {
      mockRepo = MockProfileRepository();
      controller = ProfileController(profileRepository: mockRepo);
    });

    test('initialize loads profile and clears loading state', () async {
      await controller.initialize('user_abc', defaultEmail: 'arturo@marthapp.com');

      expect(controller.isLoading, isFalse);
      expect(controller.currentProfile, isNotNull);
      expect(controller.currentProfile?.username, equals('arturo'));
      expect(controller.currentProfile?.avatarType, equals(AvatarType.initials));
    });

    test('updateUsername validates length and characters', () async {
      await controller.initialize('u1');

      final shortOk = await controller.updateUsername('ab');
      expect(shortOk, isFalse);
      expect(controller.errorMessage, contains('al menos 3 caracteres'));

      final invalidOk = await controller.updateUsername('bad name!');
      expect(invalidOk, isFalse);
      expect(controller.errorMessage, contains('Solo letras'));

      final validOk = await controller.updateUsername('cool_user_99');
      expect(validOk, isTrue);
      expect(mockRepo.lastUpdatedUsername, equals('cool_user_99'));
      expect(controller.currentProfile?.username, equals('cool_user_99'));
      expect(controller.successMessage, contains('actualizado con éxito'));
    });

    test('selectAvatarIcon updates avatar state and calls repository', () async {
      await controller.initialize('u1');

      final ok = await controller.selectAvatarIcon('gamepad', '#00E5FF');
      expect(ok, isTrue);
      expect(mockRepo.lastSelectedIconKey, equals('gamepad'));
      expect(mockRepo.lastSelectedColorHex, equals('#00E5FF'));
      expect(controller.currentProfile?.avatarType, equals(AvatarType.icon));
      expect(controller.currentProfile?.avatarIcon, equals('gamepad'));
      expect(controller.currentProfile?.avatarBgColor, equals('#00E5FF'));
    });

    test('uploadAvatarImage updates avatar state with storage public url', () async {
      await controller.initialize('u1');

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final ok = await controller.uploadAvatarImage(bytes, 'png');
      expect(ok, isTrue);
      expect(controller.currentProfile?.avatarType, equals(AvatarType.image));
      expect(controller.currentProfile?.avatarUrl, contains('avatars/u1/avatar.png'));
    });

    test('resetToInitials restores initials state', () async {
      await controller.initialize('u1');
      await controller.selectAvatarIcon('rocket', '#FF3366');
      expect(controller.currentProfile?.avatarType, equals(AvatarType.icon));

      final ok = await controller.resetToInitials();
      expect(ok, isTrue);
      expect(controller.currentProfile?.avatarType, equals(AvatarType.initials));
    });

    test('reset clears in-memory state on logout', () async {
      await controller.initialize('u1');
      expect(controller.currentProfile, isNotNull);

      controller.reset();
      expect(controller.currentProfile, isNull);
      expect(controller.errorMessage, isNull);
    });
  });
}
