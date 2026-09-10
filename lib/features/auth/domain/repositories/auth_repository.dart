import 'package:supabase_flutter/supabase_flutter.dart';

/// Contrato abstracto del repositorio de autenticación para MarthApp.
/// Permite desacoplar la lógica de presentación del SDK de Supabase,
/// facilitando tests unitarios, inyección de dependencias y futuros proveedores.
abstract class IAuthRepository {
  /// Obtener usuario actual
  User? get currentUser;

  /// Obtener sesión activa
  Session? get currentSession;

  /// Stream reactivo de cambios de autenticación
  Stream<AuthState> get authStateChanges;

  /// Iniciar sesión con Google OAuth
  Future<bool> signInWithGoogle();

  /// Iniciar sesión con GitHub OAuth
  Future<bool> signInWithGithub();

  /// Iniciar sesión con Email y Contraseña
  Future<AuthResponse> signInWithEmail(String email, String password);

  /// Registrar usuario con Email y Contraseña (sesión inmediata sin esperar correo)
  Future<AuthResponse> signUpWithEmail(String email, String password);

  /// Solicitar correo de restablecimiento de contraseña
  Future<void> sendPasswordResetEmail(String email);

  /// Actualizar contraseña del usuario tras recibir el enlace de recuperación
  Future<UserResponse> updatePassword(String newPassword);

  /// Cerrar sesión actual
  Future<void> signOut();
}
