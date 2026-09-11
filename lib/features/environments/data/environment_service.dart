import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/environment_invitation_model.dart';
import '../domain/models/environment_member_model.dart';
import '../domain/models/environment_model.dart';
import '../domain/repositories/i_environment_repository.dart';

/// Implementación del servicio de entornos conectado a Supabase PostgreSQL y RPCs transaccionales
class EnvironmentService implements IEnvironmentRepository {
  final SupabaseClient? _supabase;

  EnvironmentService({SupabaseClient? client})
      : _supabase = client ?? _safeGetClient();

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
      throw StateError('SupabaseClient no está disponible (no inicializado)');
    }
    return client;
  }

  @override
  Future<List<EnvironmentModel>> getEnvironments(String userId) async {
    try {
      final res = await _client
          .from('environments')
          .select('*, environment_members!inner(role, user_id)')
          .eq('environment_members.user_id', userId)
          .order('is_personal', ascending: false)
          .order('created_at', ascending: true);

      final List<dynamic> list = res as List<dynamic>;
      final envs = list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final members = map['environment_members'];
        String role = 'member';
        if (members is List && members.isNotEmpty) {
          role = members.first['role'] as String? ?? 'member';
        } else if (members is Map) {
          role = members['role'] as String? ?? 'member';
        }
        return EnvironmentModel.fromJson(map, userRole: role);
      }).toList();

      // Auto-healing: si el usuario no tiene "Mi Espacio" personal, delegar 100% en RPC atómica
      if (!envs.any((e) => e.isPersonal)) {
        final personalEnv = await ensurePersonalEnvironment();
        if (personalEnv != null) {
          envs.insert(0, personalEnv);
        }
      }

      return envs;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al obtener entornos ($userId): $e');
      // Intento de auto-healing si falló la consulta o la tabla no tenía al usuario
      try {
        final personalEnv = await ensurePersonalEnvironment();
        if (personalEnv != null) return [personalEnv];
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<EnvironmentModel?> ensurePersonalEnvironment() async {
    try {
      final res = await _client.rpc('ensure_personal_environment');
      if (res != null) {
        final map = Map<String, dynamic>.from(res as Map);
        return EnvironmentModel.fromJson(map, userRole: 'owner');
      }
      return null;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al auto-recuperar entorno personal: $e');
      return null;
    }
  }

  @override
  Future<List<String>> getPendingInvitedUserIds(String environmentId) async {
    try {
      final res = await _client
          .from('environment_invitations')
          .select('receiver_id')
          .eq('environment_id', environmentId)
          .eq('status', 'pending');

      final list = res as List<dynamic>;
      return list.map((item) => (item as Map)['receiver_id'] as String).toList();
    } catch (e) {
      debugPrint('[EnvironmentService] Error al obtener invitaciones pendientes de $environmentId: $e');
      return [];
    }
  }

  @override
  Future<EnvironmentModel?> createEnvironment({required String name}) async {
    try {
      final res = await _client.rpc(
        'create_environment',
        params: {'p_name': name.trim()},
      );

      if (res != null) {
        final map = Map<String, dynamic>.from(res as Map);
        return EnvironmentModel.fromJson(map, userRole: 'owner');
      }
      return null;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al crear entorno atómico: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteEnvironment(String environmentId) async {
    try {
      await _client.rpc(
        'delete_environment',
        params: {'p_environment_id': environmentId},
      );
      return true;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al eliminar entorno: $e');
      rethrow;
    }
  }

  @override
  Future<List<EnvironmentMemberModel>> getEnvironmentMembers(String environmentId) async {
    try {
      final res = await _client.rpc(
        'get_environment_members',
        params: {'p_environment_id': environmentId},
      );

      if (res is List) {
        return res
            .map((item) => EnvironmentMemberModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[EnvironmentService] Error al obtener miembros de $environmentId: $e');
      return [];
    }
  }

  @override
  Future<bool> removeMember({required String environmentId, required String userId}) async {
    try {
      await _client
          .from('environment_members')
          .delete()
          .eq('environment_id', environmentId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al expulsar miembro: $e');
      return false;
    }
  }

  @override
  Future<bool> leaveEnvironment({required String environmentId, required String userId}) async {
    try {
      await _client
          .from('environment_members')
          .delete()
          .eq('environment_id', environmentId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al abandonar entorno: $e');
      return false;
    }
  }

  @override
  Future<List<EnvironmentInvitationModel>> getPendingInvitations(String userId) async {
    try {
      final res = await _client
          .from('environment_invitations')
          .select('*, environments(name), sender_profile:profiles!environment_invitations_sender_id_fkey(username)')
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final List<dynamic> list = res as List<dynamic>;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return EnvironmentInvitationModel.fromJson(map);
      }).toList();
    } catch (e) {
      // Si la foreign key de join con alias no coincide en mock o backend, fallback a consulta directa
      try {
        final fallback = await _client
            .from('environment_invitations')
            .select()
            .eq('receiver_id', userId)
            .eq('status', 'pending')
            .order('created_at', ascending: false);

        final List<dynamic> list = fallback as List<dynamic>;
        return list
            .map((item) => EnvironmentInvitationModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (fallbackErr) {
        debugPrint('[EnvironmentService] Error al obtener invitaciones ($userId): $fallbackErr');
        return [];
      }
    }
  }

  @override
  Future<bool> sendInvitation({
    required String environmentId,
    required String receiverId,
    required String senderId,
  }) async {
    try {
      await _client.from('environment_invitations').insert({
        'environment_id': environmentId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al enviar invitación a entorno: $e');
      rethrow;
    }
  }

  @override
  Future<bool> respondInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    try {
      if (accept) {
        await _client.rpc(
          'accept_environment_invitation',
          params: {'p_invitation_id': invitationId},
        );
      } else {
        await _client
            .from('environment_invitations')
            .update({'status': 'declined'})
            .eq('id', invitationId);
      }
      return true;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al responder invitación ($invitationId): $e');
      return false;
    }
  }

  @override
  Future<bool> migrateContent({
    required String sourceEnvironmentId,
    required String targetEnvironmentId,
  }) async {
    try {
      await _client.rpc(
        'migrate_environment_content',
        params: {
          'source_environment_id': sourceEnvironmentId,
          'target_environment_id': targetEnvironmentId,
        },
      );
      return true;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al migrar contenido propio: $e');
      rethrow;
    }
  }

  @override
  RealtimeChannel? subscribeToInvitations(
    String userId,
    void Function() onInvitationsChanged,
  ) {
    try {
      final channel = _client.channel('env_invitations_realtime_$userId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'environment_invitations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: userId,
            ),
            callback: (payload) {
              onInvitationsChanged();
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('[EnvironmentService] Error al suscribir a Realtime de invitaciones: $e');
      return null;
    }
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (e) {
        debugPrint('[EnvironmentService] Error al desuscribir canal de invitaciones: $e');
      }
    }
  }
}
