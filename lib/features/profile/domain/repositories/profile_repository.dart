import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

/// Contrato abstracto del repositorio de perfil de usuario
abstract class IProfileRepository {
  /// Obtiene el perfil de un usuario por su ID
  Future<ProfileModel?> getProfile(String userId, {String? defaultEmail});

  /// Actualiza el nombre de usuario
  Future<bool> updateUsername(String userId, String newUsername);

  /// Configura el avatar en modo icono con un color de fondo
  Future<bool> updateAvatarIcon(
    String userId, {
    required String iconKey,
    required String colorHex,
  });

  /// Sube los bytes de la imagen a Supabase Storage y actualiza el avatar en modo imagen
  Future<String?> uploadAvatarImage(
    String userId, {
    required Uint8List bytes,
    required String fileExtension,
  });

  /// Restablece el avatar al modo iniciales
  Future<bool> resetToInitials(String userId);

  /// Se suscribe a cambios en tiempo real del perfil del usuario
  RealtimeChannel? subscribeToProfile(
    String userId,
    void Function(ProfileModel profile) onProfileUpdated,
  );

  /// Cancela la suscripción a un canal Realtime
  Future<void> unsubscribe(RealtimeChannel? channel);
}
