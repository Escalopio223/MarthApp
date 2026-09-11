import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/environment_invitation_model.dart';
import '../models/environment_member_model.dart';
import '../models/environment_model.dart';

/// Contrato desacoplado para la capa de acceso a datos de entornos
abstract class IEnvironmentRepository {
  /// Obtiene todos los entornos a los que pertenece el usuario
  Future<List<EnvironmentModel>> getEnvironments(String userId);

  /// Auto-healing atómico de 'Mi Espacio' (Personal) delegado 100% en RPC
  Future<EnvironmentModel?> ensurePersonalEnvironment();

  /// Obtiene los IDs de usuarios con invitación pendiente para un entorno específico
  Future<List<String>> getPendingInvitedUserIds(String environmentId);

  /// Crea un nuevo entorno de forma atómica mediante RPC
  Future<EnvironmentModel?> createEnvironment({required String name});

  /// Elimina un entorno mediante RPC (valida owner y regla estricta de miembros)
  Future<bool> deleteEnvironment(String environmentId);

  /// Obtiene los miembros de un entorno mediante RPC seguro
  Future<List<EnvironmentMemberModel>> getEnvironmentMembers(String environmentId);

  /// Expulsa a un miembro del entorno (solo owner)
  Future<bool> removeMember({required String environmentId, required String userId});

  /// Permite a un miembro abandonar voluntariamente el entorno
  Future<bool> leaveEnvironment({required String environmentId, required String userId});

  /// Obtiene las invitaciones pendientes recibidas por el usuario
  Future<List<EnvironmentInvitationModel>> getPendingInvitations(String userId);

  /// Envía una invitación a un amigo para unirse al entorno
  Future<bool> sendInvitation({
    required String environmentId,
    required String receiverId,
    required String senderId,
  });

  /// Acepta o rechaza una invitación recibida
  Future<bool> respondInvitation({
    required String invitationId,
    required bool accept,
  });

  /// Migra de forma atómica el contenido propio entre entornos mediante RPC
  Future<bool> migrateContent({
    required String sourceEnvironmentId,
    required String targetEnvironmentId,
  });

  /// Suscripción Realtime WebSocket exclusiva para environment_invitations
  RealtimeChannel? subscribeToInvitations(
    String userId,
    void Function() onInvitationsChanged,
  );

  /// Cancela la suscripción del canal Realtime
  Future<void> unsubscribe(RealtimeChannel? channel);
}
