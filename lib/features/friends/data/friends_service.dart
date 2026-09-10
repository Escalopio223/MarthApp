import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/friend_request_model.dart';
import '../domain/models/profile_model.dart';

/// Interfaz abstracta del servicio de amistades y perfiles para permitir testing desacoplado
abstract class IFriendsService {
  Future<ProfileModel?> getMyProfile(String userId, {String? defaultEmail});
  Future<ProfileModel> updateUsername(String userId, String newUsername);
  Future<ProfileModel?> searchProfileByUsername(String username);
  Future<FriendRequestModel> sendFriendRequest(String senderId, String targetUsername);
  Future<void> acceptFriendRequest(String requestId);
  Future<void> rejectFriendRequest(String requestId);
  Future<void> removeFriend(String friendshipId);
  Future<List<FriendRequestModel>> fetchPendingIncomingRequests(String userId);
  Future<List<ProfileModel>> fetchFriends(String userId);
  RealtimeChannel subscribeToFriendRequests({
    required String userId,
    required void Function(Map<String, dynamic> record, String eventType) onEvent,
  });
  RealtimeChannel subscribeToProfiles({
    required void Function(ProfileModel updatedProfile) onProfileUpdated,
  });
  Future<void> unsubscribe(RealtimeChannel? channel);
}

/// Implementación concreta conectada al SDK oficial de Supabase
class FriendsService implements IFriendsService {
  final SupabaseClient? _supabase;

  FriendsService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? _safeGetClient();

  static SupabaseClient? _safeGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _client {
    final client = _supabase;
    if (client == null) {
      throw StateError('Supabase no está inicializado.');
    }
    return client;
  }

  @override
  Future<ProfileModel?> getMyProfile(String userId, {String? defaultEmail}) async {
    final fallbackUsername = defaultEmail != null && defaultEmail.contains('@')
        ? defaultEmail.split('@').first
        : 'usuario_${userId.length > 6 ? userId.substring(0, 6) : userId}';

    final client = _supabase;
    if (client == null) {
      return ProfileModel(
        id: userId,
        username: fallbackUsername,
        updatedAt: DateTime.now(),
      );
    }

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        return ProfileModel.fromJson(data);
      }

      final newProfile = await client
          .from('profiles')
          .insert({
            'id': userId,
            'username': fallbackUsername,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return ProfileModel.fromJson(newProfile);
    } catch (e) {
      debugPrint('[FriendsService] Error al obtener perfil: $e');
      return null;
    }
  }

  @override
  Future<ProfileModel> updateUsername(String userId, String newUsername) async {
    final cleanUsername = newUsername.trim();
    if (cleanUsername.isEmpty) {
      throw Exception('El nombre de usuario no puede estar vacío');
    }
    if (cleanUsername.length < 3) {
      throw Exception('El nombre de usuario debe tener al menos 3 caracteres');
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanUsername)) {
      throw Exception('Solo se permiten letras, números y guiones bajos (_)');
    }

    try {
      final res = await _client
          .from('profiles')
          .update({
            'username': cleanUsername,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      return ProfileModel.fromJson(res);
    } on PostgrestException catch (pe) {
      // Código 23505: unique_violation en PostgreSQL
      if (pe.code == '23505' || pe.message.contains('unique') || pe.message.contains('duplicate')) {
        throw Exception('El nombre de usuario "$cleanUsername" ya está en uso');
      }
      throw Exception('Error al actualizar nombre: ${pe.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  @override
  Future<ProfileModel?> searchProfileByUsername(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final client = _supabase;
    if (client == null) return null;

    try {
      final res = await client
          .from('profiles')
          .select()
          .ilike('username', clean)
          .maybeSingle();

      if (res != null) {
        return ProfileModel.fromJson(res);
      }
      return null;
    } catch (e) {
      debugPrint('[FriendsService] Error en búsqueda de username: $e');
      return null;
    }
  }

  @override
  Future<FriendRequestModel> sendFriendRequest(
      String senderId, String targetUsername) async {
    final cleanUsername = targetUsername.trim();
    if (cleanUsername.isEmpty) {
      throw Exception('Introduce un nombre de usuario');
    }

    final targetProfile = await searchProfileByUsername(cleanUsername);
    if (targetProfile == null) {
      throw Exception('No se encontró ningún usuario con el nombre "$cleanUsername"');
    }

    if (targetProfile.id == senderId) {
      throw Exception('No puedes enviarte una solicitud de amistad a ti mismo');
    }

    final client = _client;

    // Verificar si ya existe relación previa en cualquier sentido
    final existing = await client
        .from('friend_requests')
        .select()
        .or('and(sender_id.eq.$senderId,receiver_id.eq.${targetProfile.id}),and(sender_id.eq.${targetProfile.id},receiver_id.eq.$senderId)')
        .maybeSingle();

    if (existing != null) {
      final status = existing['status'] as String?;
      if (status == 'accepted') {
        throw Exception('Ya tienes a este usuario en tu lista de amigos');
      } else if (status == 'pending') {
        if (existing['sender_id'] == senderId) {
          throw Exception('Ya has enviado una solicitud pendiente a este usuario');
        } else {
          // El otro usuario ya nos había enviado solicitud: la aceptamos directamente
          await acceptFriendRequest(existing['id'] as String);
          throw Exception('¡El usuario ya te había enviado solicitud! Se ha aceptado.');
        }
      }
    }

    // Insertar nueva solicitud
    final inserted = await client
        .from('friend_requests')
        .insert({
          'sender_id': senderId,
          'receiver_id': targetProfile.id,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return FriendRequestModel.fromJson(inserted, receiverProfile: targetProfile);
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    await _client
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    await _client
        .from('friend_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }

  @override
  Future<void> removeFriend(String friendshipId) async {
    await _client.from('friend_requests').delete().eq('id', friendshipId);
  }

  @override
  Future<List<FriendRequestModel>> fetchPendingIncomingRequests(String userId) async {
    final client = _supabase;
    if (client == null) return [];

    try {
      final res = await client
          .from('friend_requests')
          .select('*, sender:profiles!friend_requests_sender_id_fkey(*)')
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (res as List)
          .map((item) => FriendRequestModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Si la relación foránea no está nombrada así, hacer fallback manual
      return _fetchPendingIncomingFallback(userId, client);
    }
  }

  Future<List<FriendRequestModel>> _fetchPendingIncomingFallback(
      String userId, [SupabaseClient? client]) async {
    final c = client ?? _supabase;
    if (c == null) return [];

    try {
      final requestsData = await c
          .from('friend_requests')
          .select()
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final List<FriendRequestModel> list = [];
      for (final raw in (requestsData as List)) {
        final item = raw as Map<String, dynamic>;
        final senderId = item['sender_id'] as String;
        final senderProfileData = await c
            .from('profiles')
            .select()
            .eq('id', senderId)
            .maybeSingle();

        final senderProfile = senderProfileData != null
            ? ProfileModel.fromJson(senderProfileData)
            : null;

        list.add(FriendRequestModel.fromJson(item, senderProfile: senderProfile));
      }
      return list;
    } catch (e) {
      debugPrint('[FriendsService] Error al cargar pendientes fallback: $e');
      return [];
    }
  }

  @override
  Future<List<ProfileModel>> fetchFriends(String userId) async {
    final client = _supabase;
    if (client == null) return [];
    try {
      // Buscar solicitudes donde el estado sea 'accepted' y el usuario sea emisor o receptor
      final requests = await client
          .from('friend_requests')
          .select('sender_id, receiver_id')
          .eq('status', 'accepted')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId');

      final Set<String> friendIds = {};
      for (final row in (requests as List)) {
        final sender = row['sender_id'] as String;
        final receiver = row['receiver_id'] as String;
        if (sender != userId) friendIds.add(sender);
        if (receiver != userId) friendIds.add(receiver);
      }

      if (friendIds.isEmpty) return [];

      final profilesData = await client
          .from('profiles')
          .select()
          .filter('id', 'in', friendIds.toList())
          .order('username', ascending: true);

      return (profilesData as List)
          .map((p) => ProfileModel.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[FriendsService] Error al obtener amigos: $e');
      return [];
    }
  }

  @override
  RealtimeChannel subscribeToFriendRequests({
    required String userId,
    required void Function(Map<String, dynamic> record, String eventType) onEvent,
  }) {
    final client = _supabase;
    if (client == null) {
      return _NoOpRealtimeChannel('friend_requests_$userId');
    }

    final channelName = 'public:friend_requests:$userId';
    final channel = client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) {
            final record = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final eventType = payload.eventType.name; // 'insert', 'update', 'delete'
            onEvent(record, eventType);
          },
        )
        .subscribe();

    return channel;
  }

  @override
  RealtimeChannel subscribeToProfiles({
    required void Function(ProfileModel updatedProfile) onProfileUpdated,
  }) {
    final client = _supabase;
    if (client == null) {
      return _NoOpRealtimeChannel('profiles_all');
    }

    const channelName = 'public:profiles_all';
    final channel = client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final updated = ProfileModel.fromJson(payload.newRecord);
              onProfileUpdated(updated);
            }
          },
        )
        .subscribe();

    return channel;
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    final client = _supabase;
    if (channel != null && client != null) {
      try {
        await client.removeChannel(channel);
      } catch (e) {
        debugPrint('[FriendsService] Error al desuscribir canal realtime: $e');
      }
    }
  }
}

class _NoOpRealtimeChannel extends RealtimeChannel {
  _NoOpRealtimeChannel(String topic)
      : super(
          topic,
          RealtimeClient('https://noop.supabase.co'),
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
