import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/auth_exception.dart';
import '../domain/repositories/auth_repository.dart';

/// Implementación del repositorio de autenticación para MarthApp sobre Supabase Auth.
/// Gestiona OAuth Social (Google, GitHub), credenciales directas
/// (Email/Password con sesión inmediata) y flujo de recuperación de contraseña.
class AuthService implements IAuthRepository {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Helper para resolver el redirectTo adecuado según plataforma
  String _resolveRedirectUrl({required String mobileCallbackPath}) {
    if (kIsWeb) {
      return '${Uri.base.origin}/';
    }
    return '${AppConstants.mobileDeepLinkScheme}://$mobileCallbackPath';
  }

  // ===========================================================================
  // 1. Métodos OAuth Social (Google, GitHub)
  // ===========================================================================

  @override
  Future<bool> signInWithGoogle() async {
    return _signInWithOAuth(
      provider: OAuthProvider.google,
      mobileCallback: AppConstants.loginCallbackPath,
    );
  }

  @override
  Future<bool> signInWithGithub() async {
    return _signInWithOAuth(
      provider: OAuthProvider.github,
      mobileCallback: AppConstants.loginCallbackPath,
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

  @override
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

  @override
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

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final redirectUrl =
          _resolveRedirectUrl(mobileCallbackPath: AppConstants.resetCallbackPath);

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

  @override
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

  @override
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
