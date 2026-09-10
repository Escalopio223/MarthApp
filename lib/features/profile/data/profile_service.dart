import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/profile_model.dart';
import '../domain/repositories/profile_repository.dart';

/// Implementación del repositorio de perfil con Supabase PostgreSQL y Supabase Storage
class ProfileService implements IProfileRepository {
  final SupabaseClient? _supabase;

  ProfileService({SupabaseClient? client})
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
  Future<ProfileModel?> getProfile(String userId, {String? defaultEmail}) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        return ProfileModel.fromJson(res);
      }

      // Si no existe, crear perfil con el username por defecto
      final fallbackName = defaultEmail != null && defaultEmail.contains('@')
          ? defaultEmail.split('@').first
          : 'Usuario';

      final inserted = await _client
          .from('profiles')
          .insert({
            'id': userId,
            'username': fallbackName,
            'avatar_type': 'initials',
          })
          .select()
          .single();

      return ProfileModel.fromJson(inserted);
    } catch (e) {
      debugPrint('[ProfileService] Error al obtener perfil ($userId): $e');
      return null;
    }
  }

  @override
  Future<bool> updateUsername(String userId, String newUsername) async {
    try {
      final cleanName = newUsername.trim();
      if (cleanName.isEmpty) return false;

      await _client.from('profiles').update({
        'username': cleanName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return true;
    } on PostgrestException catch (e) {
      debugPrint('[ProfileService] PostgrestException al actualizar username: ${e.message} (code: ${e.code})');
      rethrow;
    } catch (e) {
      debugPrint('[ProfileService] Error al actualizar username: $e');
      return false;
    }
  }

  @override
  Future<bool> updateAvatarIcon(
    String userId, {
    required String iconKey,
    required String colorHex,
  }) async {
    try {
      await _client.from('profiles').update({
        'avatar_type': 'icon',
        'avatar_icon': iconKey,
        'avatar_bg_color': colorHex,
        'avatar_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('[ProfileService] Error al actualizar avatar a icono: $e');
      return false;
    }
  }

  @override
  Future<String?> uploadAvatarImage(
    String userId, {
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
      final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

      final mimeType = cleanExt == 'png'
          ? 'image/png'
          : (cleanExt == 'webp' ? 'image/webp' : 'image/jpeg');

      // 1. Subir a Supabase Storage con sobrescritura limpia
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      // 2. Resolver URL pública CDN
      final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

      // 3. Mutación atómica en profiles nulificando estado de icono
      await _client.from('profiles').update({
        'avatar_type': 'image',
        'avatar_url': publicUrl,
        'avatar_icon': null,
        'avatar_bg_color': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return publicUrl;
    } catch (e) {
      debugPrint('[ProfileService] Error al subir avatar de imagen a Storage: $e');
      return null;
    }
  }

  @override
  Future<bool> resetToInitials(String userId) async {
    try {
      await _client.from('profiles').update({
        'avatar_type': 'initials',
        'avatar_url': null,
        'avatar_icon': null,
        'avatar_bg_color': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return true;
    } catch (e) {
      debugPrint('[ProfileService] Error al restablecer avatar a iniciales: $e');
      return false;
    }
  }

  @override
  RealtimeChannel? subscribeToProfile(
    String userId,
    void Function(ProfileModel profile) onProfileUpdated,
  ) {
    try {
      final channel = _client.channel('profile_realtime_$userId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isNotEmpty) {
                try {
                  final profile = ProfileModel.fromJson(record);
                  onProfileUpdated(profile);
                } catch (e) {
                  debugPrint('[ProfileService] Error al procesar evento Realtime de perfil: $e');
                }
              }
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('[ProfileService] Error al suscribir a Realtime de perfil: $e');
      return null;
    }
  }

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (e) {
        debugPrint('[ProfileService] Error al desuscribir canal de perfil: $e');
      }
    }
  }
}
