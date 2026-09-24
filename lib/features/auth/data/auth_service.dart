import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/auth_exception.dart';
import '../domain/repositories/auth_repository.dart';

/// Implementación del repositorio de autenticación para MarthApp sobre Supabase Auth.
/// Gestiona OAuth Social (Google Nativo en móvil, GitHub), credenciales directas
/// (Email/Password con sesión inmediata) y flujo de recuperación de contraseña con OTP.
class AuthService implements IAuthRepository {
  final SupabaseClient _client;
  final GoogleSignIn? _googleSignIn;

  AuthService({SupabaseClient? client, GoogleSignIn? googleSignIn})
      : _client = client ?? Supabase.instance.client,
        // ignore: prefer_initializing_formals
        _googleSignIn = googleSignIn;

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
    if (kIsWeb) {
      return _signInWithOAuth(
        provider: OAuthProvider.google,
        mobileCallback: AppConstants.loginCallbackPath,
      );
    }
    return _signInWithGoogleNative();
  }

  Future<bool> _signInWithGoogleNative() async {
    try {
      final webClientId = SupabaseConfig.googleWebClientId;
      final GoogleSignIn googleSignIn = _googleSignIn ??
          GoogleSignIn(
            serverClientId: webClientId.isNotEmpty ? webClientId : null,
            scopes: const ['email', 'profile', 'openid'],
          );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw AppAuthException(
          'Google no devolvió un idToken válido. Verifica la configuración de serverClientId y la huella SHA-1.',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );

      return response.session != null || response.user != null;
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Error al iniciar sesión con Google: $e');
    }
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
      // Si Supabase inicia sesión de inmediato (ej. confirmación de email desactivada),
      // cerramos la sesión para evitar login automático y redirigir al login manual.
      if (response.session != null || _client.auth.currentSession != null) {
        await _client.auth.signOut();
      }
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
      await _client.auth.resetPasswordForEmail(
        email.trim(),
      );
    } on AuthException catch (e) {
      debugPrint('[AuthService] Error al enviar recuperación de contraseña: "${e.message}" (código: ${e.statusCode})');
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      debugPrint('[AuthService] Error inesperado en recuperación: $e');
      throw AppAuthException('Error al enviar correo de recuperación: $e');
    }
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );

      if (response.session == null) {
        throw AppAuthException('Código de recuperación inválido o expirado.');
      }

      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // Cierre de sesión preventivo para evitar condiciones de carrera en AuthGate
      // y obligar a un inicio de sesión limpio con las nuevas credenciales.
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AppAuthException.fromSupabase(e);
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Error al restablecer contraseña: $e');
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
