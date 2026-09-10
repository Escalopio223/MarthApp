import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/friends/data/friends_service.dart';
import 'package:marth_app/features/friends/domain/models/friend_request_model.dart';
import 'package:marth_app/features/friends/domain/models/profile_model.dart';
import 'package:marth_app/features/friends/presentation/controllers/friends_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControllerTestFriendsService implements IFriendsService {
  final Map<String, ProfileModel> profiles = {};
  final List<FriendRequestModel> requests = [];

  void Function(Map<String, dynamic> record, String eventType)? onFriendRequestsCallback;
  void Function(ProfileModel updatedProfile)? onProfilesCallback;
  bool wasUnsubscribed = false;

  @override
  Future<ProfileModel?> getMyProfile(String userId, {String? defaultEmail}) async {
    return profiles[userId];
  }

  @override
  Future<ProfileModel> updateUsername(String userId, String newUsername) async {
    final clean = newUsername.trim();
    if (clean.isEmpty) throw Exception('El nombre de usuario no puede estar vacío');
    if (clean.length < 3) throw Exception('El nombre de usuario debe tener al menos 3 caracteres');

    final collision = profiles.values.any(
        (p) => p.id != userId && p.username.toLowerCase() == clean.toLowerCase());
    if (collision) {
      throw Exception('El nombre de usuario "$clean" ya está en uso');
    }

    final updated = ProfileModel(id: userId, username: clean, updatedAt: DateTime.now());
    profiles[userId] = updated;
    return updated;
  }

  @override
  Future<ProfileModel?> searchProfileByUsername(String username) async {
    return profiles.values
        .cast<ProfileModel?>()
        .firstWhere((p) => p?.username.toLowerCase() == username.toLowerCase(), orElse: () => null);
  }

  @override
  Future<FriendRequestModel> sendFriendRequest(String senderId, String targetUsername) async {
    final target = await searchProfileByUsername(targetUsername);
    if (target == null) throw Exception('No se encontró ningún usuario con el nombre "$targetUsername"');
    if (target.id == senderId) throw Exception('No puedes enviarte una solicitud a ti mismo');

    final req = FriendRequestModel(
      id: 'req-${requests.length + 1}',
      senderId: senderId,
      receiverId: target.id,
      status: 'pending',
      createdAt: DateTime.now(),
      senderProfile: profiles[senderId],
      receiverProfile: target,
    );
    requests.add(req);
    return req;
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
    requests.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<void> removeFriend(String userId, String friendId) async {
    requests.removeWhere((r) =>
        (r.senderId == userId && r.receiverId == friendId) ||
        (r.senderId == friendId && r.receiverId == userId));
  }

  @override
  Future<List<FriendRequestModel>> fetchPendingIncomingRequests(String userId) async {
    return requests.where((r) => r.receiverId == userId && r.status == 'pending').toList();
  }

  @override
  Future<List<ProfileModel>> fetchFriends(String userId) async {
    final accepted = requests.where(
        (r) => r.status == 'accepted' && (r.senderId == userId || r.receiverId == userId));
    final List<ProfileModel> list = [];
    for (final req in accepted) {
      final friendId = req.senderId == userId ? req.receiverId : req.senderId;
      if (profiles.containsKey(friendId)) {
        list.add(profiles[friendId]!);
      }
    }
    return list;
  }

  @override
  RealtimeChannel subscribeToFriendRequests({
    required String userId,
    required void Function(Map<String, dynamic> record, String eventType) onEvent,
  }) {
    onFriendRequestsCallback = onEvent;
    return _FakeRealtimeChannel();
  }

  @override
  RealtimeChannel subscribeToProfiles({
    required void Function(ProfileModel updatedProfile) onProfileUpdated,
  }) {
    onProfilesCallback = onProfileUpdated;
    return _FakeRealtimeChannel();
  }

  final Map<String, String> activeCodes = {};

  @override
  Future<void> saveFriendCode(String userId, String code, {int durationSeconds = 60}) async {
    activeCodes[code.toUpperCase()] = userId;
  }

  @override
  Future<ProfileModel> redeemFriendCode(String currentUserId, String code) async {
    final clean = code.trim().toUpperCase();
    final ownerId = activeCodes[clean];
    if (ownerId == null) {
      if (clean == 'MARTH-EXPIRED') {
        throw Exception('El código ha expirado (validez: 60 segundos).');
      }
      throw Exception('El código "$clean" no existe.');
    }
    if (ownerId == currentUserId) {
      throw Exception('No puedes canjear tu propio código de amigo.');
    }
    final ownerProfile = profiles[ownerId];
    if (ownerProfile == null) throw Exception('Perfil no encontrado.');

    final req = FriendRequestModel(
      id: 'req-${requests.length + 1}',
      senderId: currentUserId,
      receiverId: ownerId,
      status: 'pending',
      createdAt: DateTime.now(),
      senderProfile: profiles[currentUserId],
      receiverProfile: ownerProfile,
    );
    requests.add(req);
    return ownerProfile;
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    wasUnsubscribed = true;
  }
}

class _FakeRealtimeChannel extends RealtimeChannel {
  _FakeRealtimeChannel()
      : super(
          'fake_topic',
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
  group('FriendsController Realtime Flow Tests', () {
    late ControllerTestFriendsService service;
    late FriendsController controller;

    setUp(() {
      service = ControllerTestFriendsService();
      service.profiles['user-me'] = ProfileModel(
        id: 'user-me',
        username: 'mi_usuario',
        updatedAt: DateTime.now(),
      );
      service.profiles['user-friend'] = ProfileModel(
        id: 'user-friend',
        username: 'amigo_juan',
        updatedAt: DateTime.now(),
      );
      service.profiles['user-other'] = ProfileModel(
        id: 'user-other',
        username: 'lucas_cool',
        updatedAt: DateTime.now(),
      );

      controller = FriendsController(friendsService: service);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initialize loads current profile and sets up realtime subscriptions', () async {
      await controller.initialize('user-me');

      expect(controller.currentProfile?.username, equals('mi_usuario'));
      expect(controller.isLoading, isFalse);
      expect(service.onFriendRequestsCallback, isNotNull);
      expect(service.onProfilesCallback, isNotNull);
    });

    test('updateUsername updates own profile and handles collision errors', () async {
      await controller.initialize('user-me');

      // Colisión con amigo_juan
      final collisionSuccess = await controller.updateUsername('amigo_juan');
      expect(collisionSuccess, isFalse);
      expect(controller.errorMessage, contains('ya está en uso'));

      // Actualización válida
      final success = await controller.updateUsername('mi_nuevo_nick');
      expect(success, isTrue);
      expect(controller.currentProfile?.username, equals('mi_nuevo_nick'));
      expect(controller.errorMessage, isNull);
    });

    test('Realtime INSERT in friend_requests adds incoming request immediately', () async {
      await controller.initialize('user-me');
      expect(controller.incomingRequests.length, equals(0));

      // Simular evento INSERT desde Supabase Realtime
      service.onFriendRequestsCallback?.call(
        {
          'id': 'req-999',
          'sender_id': 'user-other',
          'receiver_id': 'user-me',
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        },
        'INSERT',
      );

      // Esperar resolución asíncrona de búsqueda de perfil del emisor
      await Future.delayed(const Duration(milliseconds: 10));

      // Debe aparecer instantáneamente en la bandeja de pendientes
      expect(controller.incomingRequests.length, equals(1));
      expect(controller.incomingRequests.first.id, equals('req-999'));
    });

    test('Realtime UPDATE to accepted moves request to friends list immediately', () async {
      await controller.initialize('user-me');

      // Crear solicitud aceptada en el servicio
      service.requests.add(FriendRequestModel(
        id: 'req-accepted',
        senderId: 'user-other',
        receiverId: 'user-me',
        status: 'accepted',
        createdAt: DateTime.now(),
      ));

      // Disparar evento UPDATE en tiempo real
      service.onFriendRequestsCallback?.call(
        {
          'id': 'req-accepted',
          'sender_id': 'user-other',
          'receiver_id': 'user-me',
          'status': 'accepted',
        },
        'UPDATE',
      );

      // Esperar microtask para carga reactiva de amigos
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.friends.any((f) => f.id == 'user-other'), isTrue);
    });

    test('Realtime UPDATE on profiles propagates friend username change without reload', () async {
      // 1. Establecer relación de amistad previa
      service.requests.add(FriendRequestModel(
        id: 'req-1',
        senderId: 'user-me',
        receiverId: 'user-friend',
        status: 'accepted',
        createdAt: DateTime.now(),
      ));

      await controller.initialize('user-me');
      expect(controller.friends.first.username, equals('amigo_juan'));

      // 2. El amigo cambia su nombre a 'juan_el_pro' en su propio perfil
      final friendUpdated = ProfileModel(
        id: 'user-friend',
        username: 'juan_el_pro',
        updatedAt: DateTime.now(),
      );

      // 3. Supabase Realtime emite evento UPDATE en la tabla profiles
      service.onProfilesCallback?.call(friendUpdated);

      // 4. Se debe haber actualizado al instante en nuestra lista de amigos sin parpadeo
      expect(controller.friends.first.username, equals('juan_el_pro'));
    });

    test('redeemFriendCode sends friend request to code owner and resolves username', () async {
      await controller.initialize('user-me');

      // Configurar código para el usuario 'user-friend' (amigo_juan)
      await service.saveFriendCode('user-friend', 'MARTH-8K2A');

      final success = await controller.redeemFriendCode('MARTH-8K2A');
      expect(success, isTrue);
      expect(controller.successMessage, contains('amigo_juan'));
      expect(service.requests.any((r) => r.senderId == 'user-me' && r.receiverId == 'user-friend'), isTrue);
    });

    test('removeFriend deletes friendship and updates friend list', () async {
      service.requests.add(FriendRequestModel(
        id: 'req-friend',
        senderId: 'user-me',
        receiverId: 'user-friend',
        status: 'accepted',
        createdAt: DateTime.now(),
      ));

      await controller.initialize('user-me');
      expect(controller.friends.any((f) => f.id == 'user-friend'), isTrue);

      final removed = await controller.removeFriend('user-friend');
      expect(removed, isTrue);
      expect(controller.friends.any((f) => f.id == 'user-friend'), isFalse);
      expect(service.requests.any((r) => r.receiverId == 'user-friend'), isFalse);
      expect(controller.successMessage, contains('Amigo eliminado'));
    });

    test('dispose cleans up channels to avoid memory leaks', () {
      controller.dispose();
      expect(service.wasUnsubscribed, isTrue);
    });
  });
}
