import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/auth/data/auth_service.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:marth_app/features/settings/domain/friend_code_manager.dart';
import 'package:marth_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSettingsAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> signInWithGoogle() async => true;

  @override
  Future<bool> signInWithMicrosoft() async => true;

  @override
  Future<bool> signInWithGithub() async => true;

  @override
  Future<AuthResponse> signInWithEmail(String email, String password) async =>
      AuthResponse();

  @override
  Future<AuthResponse> signUpWithEmail(String email, String password) async =>
      AuthResponse();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    return UserResponse.fromJson({
      'id': 'test-id',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('SettingsScreen starts without auto-generated code and generates manually on tap',
      (WidgetTester tester) async {
    final authController =
        AuthController(authService: FakeSettingsAuthService());
    final friendCodeManager = FriendCodeManager();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          authController: authController,
          friendCodeManager: friendCodeManager,
        ),
      ),
    );

    // Verify title and friend code section
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Mi Código de Amigo'), findsOneWidget);
    expect(find.text('Añadir Amigo con Código'), findsOneWidget);

    // Verify code does NOT auto-generate upon entry
    expect(friendCodeManager.hasActiveCode, isFalse);
    expect(
      find.text('No tienes ningún código activo. Pulsa el botón para generar uno válido durante 1 minuto.'),
      findsOneWidget,
    );
    expect(find.text('Generar Código (1 min)'), findsOneWidget);

    // User manually taps 'Generar Código (1 min)'
    await tester.tap(find.text('Generar Código (1 min)'));
    await tester.pump();

    // Verify generated code appears and timer starts
    expect(friendCodeManager.hasActiveCode, isTrue);
    expect(find.text(friendCodeManager.currentCode!), findsOneWidget);
    expect(find.textContaining('Expira en'), findsOneWidget);

    friendCodeManager.dispose();
  });
}
