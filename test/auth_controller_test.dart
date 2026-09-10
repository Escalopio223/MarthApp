import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock que implementa IAuthRepository simulando operaciones sin conexión a red
class MockFullAuthService implements IAuthRepository {
  bool shouldFail = false;
  String? failMessage;
  String? lastAction;

  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> signInWithGoogle() async {
    lastAction = 'signInWithGoogle';
    if (shouldFail) throw Exception(failMessage ?? 'Google error');
    return true;
  }

  @override
  Future<bool> signInWithGithub() async {
    lastAction = 'signInWithGithub';
    if (shouldFail) throw Exception(failMessage ?? 'Github error');
    return true;
  }

  @override
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    lastAction = 'signInWithEmail';
    if (shouldFail) throw Exception(failMessage ?? 'Credenciales inválidas');
    return AuthResponse();
  }

  @override
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    lastAction = 'signUpWithEmail';
    if (shouldFail) throw Exception(failMessage ?? 'Error en registro');
    return AuthResponse();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastAction = 'sendPasswordResetEmail';
    if (shouldFail) throw Exception(failMessage ?? 'Error al enviar enlace');
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    lastAction = 'updatePassword';
    if (shouldFail) throw Exception(failMessage ?? 'Error al actualizar');
    return UserResponse.fromJson({
      'id': 'test-user-id',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> signOut() async {
    lastAction = 'signOut';
    if (shouldFail) throw Exception('Error al cerrar sesión');
  }
}

void main() {
  group('AuthController Tests - Hybrid & Recovery Flows', () {
    late MockFullAuthService mockAuthService;
    late AuthController controller;

    setUp(() {
      mockAuthService = MockFullAuthService();
      controller = AuthController(authService: mockAuthService);
    });

    test('Initial state is completely clean', () {
      expect(controller.isLoading, isFalse);
      expect(controller.isEmailLoading, isFalse);
      expect(controller.isResetLoading, isFalse);
      expect(controller.isUpdateLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.successMessage, isNull);
      expect(controller.isAuthenticated, isFalse);
    });

    test('signInWithGoogle executes successfully', () async {
      final success = await controller.signInWithGoogle();
      expect(success, isTrue);
      expect(mockAuthService.lastAction, equals('signInWithGoogle'));
      expect(controller.errorMessage, isNull);
    });

    test('signInWithGithub executes successfully', () async {
      final success = await controller.signInWithGithub();
      expect(success, isTrue);
      expect(mockAuthService.lastAction, equals('signInWithGithub'));
      expect(controller.errorMessage, isNull);
    });

    test('signInWithEmail executes and updates state', () async {
      final success = await controller.signInWithEmail(
        email: 'user@marthapp.com',
        password: 'password123',
      );
      expect(success, isTrue);
      expect(mockAuthService.lastAction, equals('signInWithEmail'));
      expect(controller.errorMessage, isNull);
    });

    test('signUpWithEmail registers user without auto-login and sets success message', () async {
      final success = await controller.signUpWithEmail(
        email: 'newuser@marthapp.com',
        password: 'password123',
      );
      expect(success, isTrue);
      expect(mockAuthService.lastAction, equals('signUpWithEmail'));
      expect(controller.errorMessage, isNull);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.successMessage, isNotNull);
    });

    test('sendPasswordResetEmail sets successMessage and triggers service', () async {
      final success = await controller.sendPasswordResetEmail('user@marthapp.com');
      expect(success, isTrue);
      expect(mockAuthService.lastAction, equals('sendPasswordResetEmail'));
      expect(controller.successMessage, isNotNull);
      expect(controller.errorMessage, isNull);
    });

    test('updatePassword updates password and sets successMessage', () async {
      final success = await controller.updatePassword('newSecurePassword123');
      expect(success, isTrue);
      expect(mockAuthService.lastAction, equals('updatePassword'));
      expect(controller.successMessage, isNotNull);
      expect(controller.errorMessage, isNull);
    });

    test('Failed operation properly updates errorMessage', () async {
      mockAuthService.shouldFail = true;
      mockAuthService.failMessage = 'Credenciales no válidas';

      final success = await controller.signInWithEmail(
        email: 'fail@marthapp.com',
        password: 'wrong',
      );

      expect(success, isFalse);
      expect(controller.errorMessage, contains('Credenciales no válidas'));
    });
  });
}
