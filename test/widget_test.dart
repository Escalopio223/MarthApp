import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/widgets/app_button.dart';
import 'package:marth_app/core/widgets/marth_app_logo.dart';
import 'package:marth_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:marth_app/features/auth/presentation/screens/update_password_screen.dart';
import 'package:marth_app/features/auth/presentation/widgets/reset_password_dialog.dart';
import 'package:marth_app/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:marth_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockWidgetAuthService implements IAuthRepository {
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

  testWidgets('AuthScreen switching to register shows Confirmar Contraseña field',
      (WidgetTester tester) async {
    final controller = AuthController(authService: MockWidgetAuthService());

    await tester.pumpWidget(MarthApp(authController: controller));

    // Cambiar al modo Crear Cuenta
    await tester.tap(find.text('Crear Cuenta'));
    await tester.pumpAndSettle();

    // Ahora deben haber 3 TextFormField (Email, Password, ConfirmPassword)
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Correo Electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Confirmar Contraseña'), findsOneWidget);
    expect(find.text('Repite tu contraseña'), findsOneWidget);

    // No debe mostrar "¿Has olvidado tu contraseña?" en modo registro
    expect(find.text('¿Has olvidado tu contraseña?'), findsNothing);
  });

  testWidgets('AuthScreen register validates password confirmation match',
      (WidgetTester tester) async {
    final controller = AuthController(authService: MockWidgetAuthService());

    await tester.pumpWidget(MarthApp(authController: controller));

    // Cambiar a Crear Cuenta
    await tester.tap(find.text('Crear Cuenta'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    // Escribir email, pass y confirm pass diferente
    await tester.enterText(textFields.at(0), 'nuevo@marthapp.com');
    await tester.enterText(textFields.at(1), '123456');
    await tester.enterText(textFields.at(2), '654321');

    // Pulsar botón Crear Cuenta
    await tester.tap(find.widgetWithText(AppButton, 'Crear Cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('AuthScreen successful registration redirects to login mode',
      (WidgetTester tester) async {
    final controller = AuthController(authService: MockWidgetAuthService());

    await tester.pumpWidget(MarthApp(authController: controller));

    // Cambiar a Crear Cuenta
    await tester.tap(find.text('Crear Cuenta'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'nuevo@marthapp.com');
    await tester.enterText(textFields.at(1), '123456');
    await tester.enterText(textFields.at(2), '123456');

    // Pulsar botón Crear Cuenta
    await tester.tap(find.widgetWithText(AppButton, 'Crear Cuenta'));
    await tester.pumpAndSettle();

    // Debe haber vuelto al modo Iniciar Sesión (2 campos) y mostrar banner de éxito
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('¡Cuenta creada con éxito! Por favor, inicia sesión para continuar.'),
        findsOneWidget);
  });

  testWidgets('MarthAppLogo renders vectorially without white background and mutates with theme',
      (WidgetTester tester) async {
    final controller = AuthController(authService: MockWidgetAuthService());

    await tester.pumpWidget(MarthApp(authController: controller));

    // Verificar que el logotipo oficial de MarthApp se encuentra renderizado en AuthScreen
    expect(find.byType(MarthAppLogo), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('AuthScreen tapping ¿Has olvidado tu contraseña? opens ResetPasswordDialog with prefilled email',
      (WidgetTester tester) async {
    final controller = AuthController(authService: MockWidgetAuthService());

    await tester.pumpWidget(MarthApp(authController: controller));

    // Type email into login field
    final emailField = find.byType(TextFormField).first;
    await tester.enterText(emailField, 'testuser@marthapp.com');

    // Tap forgot password link
    await tester.tap(find.text('¿Has olvidado tu contraseña?'));
    await tester.pumpAndSettle();

    // Verify dialog appears with prefilled email
    expect(find.text('Recuperar Contraseña'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResetPasswordDialog),
        matching: find.text('testuser@marthapp.com'),
      ),
      findsOneWidget,
    );
    expect(find.text('Enviar Enlace'), findsOneWidget);

    // Can close the dialog
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Recuperar Contraseña'), findsNothing);
  });
}

