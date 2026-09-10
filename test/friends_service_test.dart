import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/friends/data/friends_service.dart';
import 'package:marth_app/features/friends/domain/models/friend_request_model.dart';
import 'package:marth_app/features/friends/domain/models/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeFriendsService implements IFriendsService {
  final Map<String, ProfileModel> profiles = {};
  final List<FriendRequestModel> requests = [];

  @override
  Future<ProfileModel?> getMyProfile(String userId, {String? defaultEmail}) async {
    if (profiles.containsKey(userId)) {
      return profiles[userId];
    }
    final fallback = defaultEmail != null && defaultEmail.contains('@')
        ? defaultEmail.split('@').first
        : 'usuario_$userId';
    final profile = ProfileModel(
      id: userId,
      username: fallback,
      updatedAt: DateTime.now(),
    );
    profiles[userId] = profile;
    return profile;
  }

  @override
  Future<ProfileModel> updateUsername(String userId, String newUsername) async {
    final clean = newUsername.trim();
    if (clean.isEmpty) throw Exception('El nombre de usuario no puede estar vacío');
    if (clean.length < 3) throw Exception('El nombre de usuario debe tener al menos 3 caracteres');
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
      throw Exception('Solo se permiten letras, números y guiones bajos (_)');
    }

    // Verificar colisión de unicidad
    final collision = profiles.values.any(
        (p) => p.id != userId && p.username.toLowerCase() == clean.toLowerCase());
    if (collision) {
      throw Exception('El nombre de usuario "$clean" ya está en uso');
    }

    final updated = ProfileModel(
      id: userId,
      username: clean,
      updatedAt: DateTime.now(),
    );
    profiles[userId] = updated;
    return updated;
  }

  @override
  Future<ProfileModel?> searchProfileByUsername(String username) async {
    final clean = username.trim().toLowerCase();
    return profiles.values
        .cast<ProfileModel?>()
        .firstWhere((p) => p?.username.toLowerCase() == clean, orElse: () => null);
  }

  @override
  Future<FriendRequestModel> sendFriendRequest(
      String senderId, String targetUsername) async {
    final clean = targetUsername.trim();
    if (clean.isEmpty) throw Exception('Introduce un nombre de usuario');

    final target = await searchProfileByUsername(clean);
    if (target == null) {
      throw Exception('No se encontró ningún usuario con el nombre "$clean"');
    }
    if (target.id == senderId) {
      throw Exception('No puedes enviarte una solicitud de amistad a ti mismo');
    }

    final existing = requests.cast<FriendRequestModel?>().firstWhere(
          (r) =>
              (r?.senderId == senderId && r?.receiverId == target.id) ||
              (r?.senderId == target.id && r?.receiverId == senderId),
          orElse: () => null,
        );

    if (existing != null) {
      if (existing.status == 'accepted') {
        throw Exception('Ya tienes a este usuario en tu lista de amigos');
      } else if (existing.status == 'pending') {
        throw Exception('Ya has enviado una solicitud pendiente a este usuario');
      }
    }

    final newRequest = FriendRequestModel(
      id: 'req-${requests.length + 1}',
      senderId: senderId,
      receiverId: target.id,
      status: 'pending',
      createdAt: DateTime.now(),
      senderProfile: profiles[senderId],
      receiverProfile: target,
    );
    requests.add(newRequest);
    return newRequest;
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      requests[index] = requests[index].copyWith(status: 'accepted');
    }
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      requests[index] = requests[index].copyWith(status: 'rejected');
    }
  }

  @override
  Future<void> removeFriend(String friendshipId) async {
    requests.removeWhere((r) => r.id == friendshipId);
  }

  @override
  Future<List<FriendRequestModel>> fetchPendingIncomingRequests(String userId) async {
    return requests.where((r) => r.receiverId == userId && r.status == 'pending').toList();
  }

  @override
  Future<List<ProfileModel>> fetchFriends(String userId) async {
    final accepted = requests.where((r) =>
        r.status == 'accepted' && (r.senderId == userId || r.receiverId == userId));

    final List<ProfileModel> result = [];
    for (final req in accepted) {
      final friendId = req.senderId == userId ? req.receiverId : req.senderId;
      if (profiles.containsKey(friendId)) {
        result.add(profiles[friendId]!);
      }
    }
    return result;
  }

  @override
  RealtimeChannel subscribeToFriendRequests({
    required String userId,
    required void Function(Map<String, dynamic> record, String eventType) onEvent,
  }) {
    // Retornamos un canal mockeado
    return _MockRealtimeChannel('friend_requests_$userId');
  }

  @override
  RealtimeChannel subscribeToProfiles({
    required void Function(ProfileModel updatedProfile) onProfileUpdated,
  }) {
    return _MockRealtimeChannel('profiles_all');
  }

  bool wasUnsubscribed = false;

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    wasUnsubscribed = true;
  }
}

class _MockRealtimeChannel extends RealtimeChannel {
  _MockRealtimeChannel(String topic)
      : super(
          topic,
          RealtimeClient('https://fake.supabase.co'),
          params: const RealtimeChannelConfig(),
        );

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    return 'ok';
  }
}

void main() {
  group('Friends Models and Fake Service Unit Tests', () {
    late FakeFriendsService service;

    setUp(() {
      service = FakeFriendsService();
      // Perfiles precargados
      service.profiles['user-1'] = ProfileModel(
        id: 'user-1',
        username: 'arturo_dev',
        updatedAt: DateTime.now(),
      );
      service.profiles['user-2'] = ProfileModel(
        id: 'user-2',
        username: 'martha_star',
        updatedAt: DateTime.now(),
      );
    });

    test('ProfileModel serializes to and from JSON correctly', () {
      final model = ProfileModel(
        id: 'test-uuid',
        username: 'super_coder',
        updatedAt: DateTime(2026, 9, 10),
      );
      final json = model.toJson();
      final fromJson = ProfileModel.fromJson(json);

      expect(fromJson.id, equals('test-uuid'));
      expect(fromJson.username, equals('super_coder'));
      expect(fromJson.updatedAt.year, equals(2026));
    });

    test('FriendRequestModel serializes correctly and evaluates helper getters', () {
      final req = FriendRequestModel(
        id: 'req-100',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      expect(req.isPending, isTrue);
      expect(req.isAccepted, isFalse);
      expect(req.isRejected, isFalse);

      final accepted = req.copyWith(status: 'accepted');
      expect(accepted.isAccepted, isTrue);
    });

    test('searchProfileByUsername is case-insensitive', () async {
      final found = await service.searchProfileByUsername('ARTURO_DEV');
      expect(found, isNotNull);
      expect(found!.id, equals('user-1'));
    });

    test('updateUsername validates requirements and detects duplicate collisions', () async {
      // Intento de usar username duplicado
      expect(
        () => service.updateUsername('user-1', 'martha_star'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('ya está en uso'),
        )),
      );

      // Intento con formato inválido
      expect(
        () => service.updateUsername('user-1', 'bad username with spaces!'),
        throwsA(isA<Exception>()),
      );

      // Actualización válida
      final updated = await service.updateUsername('user-1', 'arturo_pro');
      expect(updated.username, equals('arturo_pro'));
      expect(service.profiles['user-1']!.username, equals('arturo_pro'));
    });

    test('sendFriendRequest prevents self-friending and duplicate requests', () async {
      // Auto-solicitud
      expect(
        () => service.sendFriendRequest('user-1', 'arturo_dev'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('a ti mismo'),
        )),
      );

      // Solicitud válida a martha_star
      final req = await service.sendFriendRequest('user-1', 'martha_star');
      expect(req.status, equals('pending'));
      expect(service.requests.length, equals(1));

      // Solicitud duplicada
      expect(
        () => service.sendFriendRequest('user-1', 'martha_star'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Ya has enviado'),
        )),
      );
    });

    test('acceptFriendRequest transitions to accepted and populates friends list', () async {
      final req = await service.sendFriendRequest('user-1', 'martha_star');
      await service.acceptFriendRequest(req.id);

      final friendsOfUser1 = await service.fetchFriends('user-1');
      final friendsOfUser2 = await service.fetchFriends('user-2');

      expect(friendsOfUser1.length, equals(1));
      expect(friendsOfUser1.first.username, equals('martha_star'));

      expect(friendsOfUser2.length, equals(1));
      expect(friendsOfUser2.first.username, equals('arturo_dev'));
    });
  });
}
