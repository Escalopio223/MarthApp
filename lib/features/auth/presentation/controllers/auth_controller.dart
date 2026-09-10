import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/auth_service.dart';

/// Controlador de estado reactivo para autenticación híbrida y recuperación de clave
class AuthController extends ChangeNotifier {
  final AuthService _authService;

  bool _isEmailLoading = false;
  OAuthProvider? _loadingProvider;
  bool _isResetLoading = false;
  bool _isUpdateLoading = false;

  String? _errorMessage;
  String? _successMessage;
  User? _user;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _user = _authService.currentUser;

    _authService.authStateChanges.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  bool get isEmailLoading => _isEmailLoading;
  OAuthProvider? get loadingProvider => _loadingProvider;
  bool isProviderLoading(OAuthProvider provider) =>
      _loadingProvider == provider;
  bool get isResetLoading => _isResetLoading;
  bool get isUpdateLoading => _isUpdateLoading;
  bool get isLoading =>
      _isEmailLoading ||
      _loadingProvider != null ||
      _isResetLoading ||
      _isUpdateLoading;

  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  User? get user => _user;
  bool get isAuthenticated => _user != null;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // ===========================================================================
  // Métodos OAuth Social
  // ===========================================================================

  Future<bool> signInWithGoogle() =>
      _handleOAuth(OAuthProvider.google, _authService.signInWithGoogle);

  Future<bool> signInWithGithub() =>
      _handleOAuth(OAuthProvider.github, _authService.signInWithGithub);

  Future<bool> _handleOAuth(
    OAuthProvider provider,
    Future<bool> Function() action,
  ) async {
    _loadingProvider = provider;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final success = await action();
      if (!success) {
        _errorMessage = 'El inicio de sesión con ${provider.name} fue cancelado.';
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _loadingProvider = null;
      notifyListeners();
    }
  }

  // ===========================================================================
  // Métodos Email / Contraseña
  // ===========================================================================

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isEmailLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signInWithEmail(email, password);
      _user = response.user;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isEmailLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _isEmailLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signUpWithEmail(email, password);
      _user = response.user;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isEmailLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // Métodos Recuperación y Cambio de Contraseña
  // ===========================================================================

  Future<bool> sendPasswordResetEmail(String email) async {
    _isResetLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _successMessage =
          'Enlace de recuperación enviado. Revisa tu bandeja de entrada.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isResetLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _isUpdateLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _authService.updatePassword(newPassword);
      _successMessage = 'Tu contraseña ha sido actualizada con éxito.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isUpdateLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }
}
