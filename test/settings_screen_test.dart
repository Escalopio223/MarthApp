import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:marth_app/features/settings/domain/friend_code_manager.dart';
import 'package:marth_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSettingsAuthService implements IAuthRepository {
  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> signInWithGoogle() async => true;

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
  testWidgets('SettingsScreen displays clean layout with UserProfile, Friends Nav, and Theme selector',
      (WidgetTester tester) async {
    final authController =
        AuthController(authService: FakeSettingsAuthService());

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          authController: authController,
        ),
      ),
    );

    // Verify title and clean layout
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Cuenta Activa'), findsOneWidget);
    expect(find.text('Amigos y Solicitudes'), findsOneWidget);
    expect(find.text('Apariencia y Temas'), findsOneWidget);
    expect(find.text('Cerrar Sesión'), findsOneWidget);

    // Verify friend code sections were cleanly moved out of SettingsScreen
    expect(find.text('Mi Código de Amigo'), findsNothing);
    expect(find.text('Añadir Amigo con Código'), findsNothing);
  });

  testWidgets('SettingsScreen displays ThemeSelectorCard and shows theme options',
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

    expect(find.text('Apariencia y Temas'), findsOneWidget);

    // Expand accordion
    await tester.tap(find.text('Apariencia y Temas'));
    await tester.pumpAndSettle();

    expect(find.text('Oscuros (5)'), findsOneWidget);
    expect(find.text('Claros (5)'), findsOneWidget);
    expect(find.text('Midnight Blue'), findsAtLeastNWidgets(1));

    // Switch to light themes tab
    await tester.ensureVisible(find.text('Claros (5)'));
    await tester.tap(find.text('Claros (5)'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Frosted Glacier'));
    expect(find.text('Frosted Glacier'), findsOneWidget);
    expect(find.text('Rose Quartz'), findsOneWidget);

    friendCodeManager.dispose();
  });

  testWidgets('SettingsScreen clicking Cambiar Contraseña opens UpdatePasswordModal directly without email',
      (WidgetTester tester) async {
    final authController =
        AuthController(authService: FakeSettingsAuthService());

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          authController: authController,
        ),
      ),
    );

    // Verify button exists
    expect(find.text('Cambiar Contraseña'), findsOneWidget);

    // Tap Cambiar Contraseña
    await tester.tap(find.text('Cambiar Contraseña'));
    await tester.pumpAndSettle();

    // Verify modal is displayed directly with new password fields
    expect(find.text('Actualizar Contraseña'), findsOneWidget);
    expect(find.text('Nueva Contraseña'), findsOneWidget);
    expect(find.text('Confirmar Nueva Contraseña'), findsOneWidget);
    expect(find.text('Confirmar y Guardar'), findsOneWidget);

    // Close button exists and works
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Modal is dismissed
    expect(find.text('Actualizar Contraseña'), findsNothing);
  });
}

