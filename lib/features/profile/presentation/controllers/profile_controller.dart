import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_service.dart';
import '../../domain/models/avatar_data.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/repositories/profile_repository.dart';

/// Controlador reactivo del perfil de usuario independiente del dominio de amistades
class ProfileController extends ChangeNotifier {
  final IProfileRepository _profileRepository;

  ProfileModel? _currentProfile;
  bool _isLoading = false;
  bool _isUpdatingUsername = false;
  bool _isUpdatingAvatar = false;
  String? _errorMessage;
  String? _successMessage;

  String? _userId;
  RealtimeChannel? _profileChannel;

  ProfileController({IProfileRepository? profileRepository})
      : _profileRepository = profileRepository ?? ProfileService();

  ProfileModel? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  bool get isUpdatingUsername => _isUpdatingUsername;
  bool get isUpdatingAvatar => _isUpdatingAvatar;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Inicializa el perfil y establece la suscripción en tiempo real
  Future<void> initialize(String userId, {String? defaultEmail}) async {
    _userId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentProfile = await _profileRepository.getProfile(
        userId,
        defaultEmail: defaultEmail,
      );

      // Cancelar canal previo si existía
      if (_profileChannel != null) {
        await _profileRepository.unsubscribe(_profileChannel);
        _profileChannel = null;
      }

      // Suscripción Realtime a la fila propia
      _profileChannel = _profileRepository.subscribeToProfile(
        userId,
        (updatedProfile) {
          _currentProfile = updatedProfile;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Error al cargar perfil: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza el nombre de usuario verificando disponibilidad
  Future<bool> updateUsername(String newUsername) async {
    if (_userId == null) return false;
    final cleanName = newUsername.trim();

    if (cleanName.length < 3) {
      _errorMessage = 'El nombre debe tener al menos 3 caracteres';
      notifyListeners();
      return false;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanName)) {
      _errorMessage = 'Solo letras, números y guión bajo';
      notifyListeners();
      return false;
    }

    _isUpdatingUsername = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final ok = await _profileRepository.updateUsername(_userId!, cleanName);
      if (ok) {
        _currentProfile = _currentProfile?.copyWith(
          username: cleanName,
          updatedAt: DateTime.now(),
        );
        _successMessage = '¡Nombre de usuario actualizado con éxito!';
        return true;
      } else {
        _errorMessage = 'No se pudo actualizar el nombre de usuario';
        return false;
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _errorMessage = 'El nombre de usuario ya está en uso. Elige otro.';
      } else {
        _errorMessage = 'Error de base de datos: ${e.message}';
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error inesperado: $e';
      return false;
    } finally {
      _isUpdatingUsername = false;
      notifyListeners();
    }
  }

  /// Configura el avatar con un icono y color de fondo seleccionados
  Future<bool> selectAvatarIcon(String iconKey, String colorHex) async {
    if (_userId == null) return false;

    _isUpdatingAvatar = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final ok = await _profileRepository.updateAvatarIcon(
        _userId!,
        iconKey: iconKey,
        colorHex: colorHex,
      );

      if (ok) {
        _currentProfile = _currentProfile?.copyWith(
          avatarData: AvatarData.icon(iconKey: iconKey, bgColorHex: colorHex),
          updatedAt: DateTime.now(),
        );
        _successMessage = 'Avatar actualizado con éxito';
        return true;
      } else {
        _errorMessage = 'No se pudo actualizar el icono de perfil';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar icono: $e';
      return false;
    } finally {
      _isUpdatingAvatar = false;
      notifyListeners();
    }
  }

  /// Sube los bytes de la imagen a Supabase Storage y actualiza el avatar en modo imagen
  Future<bool> uploadAvatarImage(Uint8List bytes, String fileExtension) async {
    if (_userId == null) return false;

    _isUpdatingAvatar = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final publicUrl = await _profileRepository.uploadAvatarImage(
        _userId!,
        bytes: bytes,
        fileExtension: fileExtension,
      );

      if (publicUrl != null) {
        _currentProfile = _currentProfile?.copyWith(
          avatarData: AvatarData.image(imageUrl: publicUrl),
          updatedAt: DateTime.now(),
        );
        _successMessage = 'Foto de perfil subida y actualizada con éxito';
        return true;
      } else {
        _errorMessage = 'Error al subir la imagen al servidor';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al procesar la imagen: $e';
      return false;
    } finally {
      _isUpdatingAvatar = false;
      notifyListeners();
    }
  }

  /// Restablece el avatar al modo iniciales
  Future<bool> resetToInitials() async {
    if (_userId == null) return false;

    _isUpdatingAvatar = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final ok = await _profileRepository.resetToInitials(_userId!);
      if (ok) {
        _currentProfile = _currentProfile?.copyWith(
          avatarData: const AvatarData.initials(),
          updatedAt: DateTime.now(),
        );
        _successMessage = 'Avatar restablecido a iniciales';
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error al restablecer avatar: $e';
      return false;
    } finally {
      _isUpdatingAvatar = false;
      notifyListeners();
    }
  }

  /// Limpia la sesión en memoria al cerrar sesión
  void reset() {
    if (_profileChannel != null) {
      _profileRepository.unsubscribe(_profileChannel);
      _profileChannel = null;
    }
    _currentProfile = null;
    _userId = null;
    _isLoading = false;
    _isUpdatingUsername = false;
    _isUpdatingAvatar = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_profileChannel != null) {
      _profileRepository.unsubscribe(_profileChannel);
      _profileChannel = null;
    }
    super.dispose();
  }
}
