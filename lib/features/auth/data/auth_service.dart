import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/auth_exception.dart';

/// Servicio modular de autenticación para MarthApp sobre Supabase Auth.
/// Gestiona OAuth Social (Google, Microsoft, GitHub), credenciales directas
/// (Email/Password con sesión inmediata) y flujo de recuperación de contraseña.
class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Obtener usuario actualmente autenticado
  User? get currentUser => _client.auth.currentUser;

  /// Obtener sesión activa
  Session? get currentSession => _client.auth.currentSession;

  /// Stream reactivo de cambios de autenticación
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Helper para resolver el redirectTo adecuado según plataforma
  String _resolveRedirectUrl({required String mobileCallbackPath}) {
    if (kIsWeb) {
      return '${Uri.base.origin}/';
    }
    return 'io.supabase.marthapp://$mobileCallbackPath';
  }

  // ===========================================================================
  // 1. Métodos OAuth Social (Google, Microsoft, GitHub)
  // ===========================================================================

  /// Iniciar sesión con Google
  Future<bool> signInWithGoogle() async {
    return _signInWithOAuth(
      provider: OAuthProvider.google,
      mobileCallback: 'login-callback',
    );
  }

  /// Iniciar sesión con GitHub
  Future<bool> signInWithGithub() async {
    return _signInWithOAuth(
      provider: OAuthProvider.github,
      mobileCallback: 'login-callback',
    );
  }

  Future<bool> _signInWithOAuth({
    required OAuthProvider provider,
    required String mobileCallback,
  }) async {
    try {
      final redirectUrl =
          _resolveRedirectUrl(mobileCallbackPath: mobileCallback);

      final success = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      return success;
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      throw AppAuthException('Error al conectar con ${provider.name}: $e');
    }
  }

  // ===========================================================================
  // 2. Credenciales directas (Email + Contraseña)
  // ===========================================================================

  /// Registrar nuevo usuario con Email y Contraseña.
  /// Conforme a la regla estricta: sesión activa inmediata sin esperar correo.
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      throw AppAuthException('Error al registrar usuario: $e');
    }
  }

  /// Iniciar sesión con Email y Contraseña existentes
  Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      throw AppAuthException('Error al iniciar sesión: $e');
    }
  }

  // ===========================================================================
  // 3. Flujo de Recuperación y Actualización de Contraseña
  // ===========================================================================

  /// Envía el correo de recuperación de contraseña con Deep Link condicional
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final redirectUrl =
          _resolveRedirectUrl(mobileCallbackPath: 'reset-callback');

      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectUrl,
      );
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      throw AppAuthException('Error al enviar correo de recuperación: $e');
    }
  }

  /// Actualiza la contraseña del usuario tras capturar la sesión de recuperación
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      throw AppAuthException('Error al actualizar contraseña: $e');
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      throw AppAuthException('Error al cerrar sesión: $e');
    }
  }
}
