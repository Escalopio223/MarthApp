import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/friends/data/friends_service.dart';
import 'package:marth_app/features/friends/domain/models/friend_request_model.dart';
import 'package:marth_app/features/friends/domain/models/profile_model.dart';
import 'package:marth_app/features/settings/domain/friend_code_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('FriendCodeManager Tests', () {
    test('Initial state should be empty and inactive', () {
      final manager = FriendCodeManager();
      expect(manager.currentCode, isNull);
      expect(manager.hasActiveCode, isFalse);
      expect(manager.remainingSeconds, equals(0));
      expect(manager.isExpired, isFalse);
      expect(manager.addedFriends, isEmpty);
      manager.dispose();
    });

    test('generateNewCode creates valid code and starts 60s timer', () {
      final manager = FriendCodeManager();
      manager.generateNewCode();

      expect(manager.currentCode, isNotNull);
      expect(manager.currentCode!.startsWith('MARTH-'), isTrue);
      expect(manager.currentCode!.length, equals(10)); // MARTH-XXXX = 10 chars
      expect(manager.hasActiveCode, isTrue);
      expect(manager.remainingSeconds, equals(60));
      expect(manager.isExpired, isFalse);
      expect(manager.progress, equals(1.0));

      manager.dispose();
    });

    test('addFriend adds unique code and prevents duplicates in offline mode', () async {
      final manager = FriendCodeManager();

      final added = await manager.addFriend('MARTH-1234');
      expect(added, isTrue);
      expect(manager.addedFriends, contains('MARTH-1234'));

      // Trying to add the same code again should throw
      expect(
        () async => await manager.addFriend('MARTH-1234'),
        throwsException,
      );

      manager.dispose();
    });

    test('addFriend with IFriendsService saves friend USERNAME instead of code string', () async {
      final service = _MockFriendService();
      // Setup user A with code MARTH-8K2A and username "lucia_gamer"
      await service.saveFriendCode('user_a', 'MARTH-8K2A');
      service.mockProfiles['user_a'] = ProfileModel(
        id: 'user_a',
        username: 'lucia_gamer',
        updatedAt: DateTime.now(),
      );

      final manager = FriendCodeManager(friendsService: service, userId: 'user_b');
      final success = await manager.addFriend('MARTH-8K2A');

      expect(success, isTrue);
      // Crucial requirement: It must save the real USERNAME, NOT the code!
      expect(manager.addedFriends, contains('lucia_gamer'));
      expect(manager.addedFriends, isNot(contains('MARTH-8K2A')));

      // Duplicate friend username should throw
      expect(
        () async => await manager.addFriend('MARTH-8K2A'),
        throwsException,
      );

      manager.dispose();
    });

    test('generateNewCode with IFriendsService persists code with 60s expiration', () async {
      final service = _MockFriendService();
      final manager = FriendCodeManager(friendsService: service, userId: 'user_123');

      final code = await manager.generateNewCode();
      expect(code.startsWith('MARTH-'), isTrue);
      expect(manager.remainingSeconds, equals(60));
      expect(service.savedCodes[code], equals('user_123'));

      manager.dispose();
    });
  });
}

class _MockFriendService implements IFriendsService {
  final Map<String, String> savedCodes = {}; // code -> userId
  final Map<String, ProfileModel> mockProfiles = {};

  @override
  Future<void> saveFriendCode(String userId, String code, {int durationSeconds = 60}) async {
    savedCodes[code.toUpperCase()] = userId;
  }

  @override
  Future<ProfileModel> redeemFriendCode(String currentUserId, String code) async {
    final clean = code.trim().toUpperCase();
    final ownerId = savedCodes[clean];
    if (ownerId == null) throw Exception('Código no encontrado');
    if (ownerId == currentUserId) throw Exception('No puedes canjear tu propio código');
    final profile = mockProfiles[ownerId] ??
        ProfileModel(id: ownerId, username: 'usuario_$ownerId', updatedAt: DateTime.now());
    return profile;
  }

  @override
  Future<ProfileModel?> getMyProfile(String userId, {String? defaultEmail}) async => mockProfiles[userId];
  @override
  Future<ProfileModel> updateUsername(String userId, String newUsername) async => mockProfiles[userId]!;
  @override
  Future<ProfileModel?> searchProfileByUsername(String username) async => null;
  @override
  Future<FriendRequestModel> sendFriendRequest(String senderId, String targetUsername) async =>
      throw UnimplementedError();
  @override
  Future<void> acceptFriendRequest(String requestId) async {}
  @override
  Future<void> rejectFriendRequest(String requestId) async {}
  @override
  Future<void> removeFriend(String friendshipId) async {}
  @override
  Future<List<FriendRequestModel>> fetchPendingIncomingRequests(String userId) async => [];
  @override
  Future<List<ProfileModel>> fetchFriends(String userId) async => [];
  @override
  RealtimeChannel subscribeToFriendRequests({
    required String userId,
    required void Function(Map<String, dynamic> record, String eventType) onEvent,
  }) => throw UnimplementedError();
  @override
  RealtimeChannel subscribeToProfiles({
    required void Function(ProfileModel updatedProfile) onProfileUpdated,
  }) => throw UnimplementedError();
  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {}
}
