import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/auth/data/auth_service.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:marth_app/features/auth/presentation/screens/update_password_screen.dart';
import 'package:marth_app/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:marth_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockWidgetAuthService implements AuthService {
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
  testWidgets('AuthScreen renders Email/Password inputs, recover link and 2 OAuth buttons',
      (WidgetTester tester) async {
    final controller = AuthController(authService: MockWidgetAuthService());

    await tester.pumpWidget(MarthApp(authController: controller));

    // Verificar Título
    expect(find.text('MarthApp'), findsOneWidget);

    // Verificar Selector de Modo
    expect(find.text('Iniciar Sesión'), findsNWidgets(2)); // En el selector y en el botón CTA
    expect(find.text('Crear Cuenta'), findsOneWidget);

    // Verificar Campos de Texto
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);

    // Verificar Enlace de Recuperación
    expect(find.text('¿Has olvidado tu contraseña?'), findsOneWidget);

    // Verificar 2 Proveedores OAuth (Google y GitHub)
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con GitHub'), findsOneWidget);
    expect(find.byType(SocialAuthButton), findsNWidgets(2));
  });

  testWidgets('UpdatePasswordScreen renders password fields and submit button',
      (WidgetTester tester) async {
    final controller = AuthController(authService: MockWidgetAuthService());

    await tester.pumpWidget(
      MaterialApp(
        home: UpdatePasswordScreen(
          controller: controller,
          onPasswordUpdated: () {},
        ),
      ),
    );

    expect(find.text('Actualizar Contraseña'), findsOneWidget);
    expect(find.text('Nueva Contraseña'), findsOneWidget);
    expect(find.text('Confirmar Nueva Contraseña'), findsOneWidget);
    expect(find.text('Guardar Nueva Contraseña'), findsOneWidget);
  });
}
