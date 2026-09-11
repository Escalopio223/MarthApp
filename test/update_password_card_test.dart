import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:marth_app/features/auth/presentation/widgets/update_password_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockPasswordAuthRepo implements IAuthRepository {
  bool updatePasswordCalled = false;
  String? updatedPasswordValue;
  bool shouldSucceed = true;

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
    updatePasswordCalled = true;
    updatedPasswordValue = newPassword;
    if (!shouldSucceed) {
      throw const AuthException('Error al cambiar contraseña');
    }
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
  group('UpdatePasswordCard Widget Tests', () {
    late MockPasswordAuthRepo mockRepo;
    late AuthController authController;

    setUp(() {
      mockRepo = MockPasswordAuthRepo();
      authController = AuthController(authService: mockRepo);
    });

    testWidgets('enforces 8-character minimum password validation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePasswordCard(
              authController: authController,
            ),
          ),
        ),
      );

      expect(find.text('Actualizar Contraseña'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);

      final inputs = find.byType(TextFormField);
      expect(inputs, findsNWidgets(2));

      // Enter 7-character password
      await tester.enterText(inputs.first, '1234567');
      await tester.enterText(inputs.last, '1234567');
      await tester.tap(find.text('Confirmar y Guardar'));
      await tester.pumpAndSettle();

      // Check validation message
      expect(find.text('La contraseña debe tener al menos 8 caracteres'),
          findsOneWidget);
      expect(mockRepo.updatePasswordCalled, isFalse);
    });

    testWidgets('validates password confirmation mismatch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePasswordCard(
              authController: authController,
            ),
          ),
        ),
      );

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.first, 'Secret1234');
      await tester.enterText(inputs.last, 'Secret5678');
      await tester.tap(find.text('Confirmar y Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(mockRepo.updatePasswordCalled, isFalse);
    });

    testWidgets('calls onSuccess callback after valid 8+ char submission',
        (WidgetTester tester) async {
      bool successCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePasswordCard(
              authController: authController,
              onSuccess: () {
                successCalled = true;
              },
            ),
          ),
        ),
      );

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.first, 'StrongPassword123');
      await tester.enterText(inputs.last, 'StrongPassword123');
      await tester.tap(find.text('Confirmar y Guardar'));
      await tester.pump();

      expect(mockRepo.updatePasswordCalled, isTrue);
      expect(mockRepo.updatedPasswordValue, equals('StrongPassword123'));

      // Settle delayed callback
      await tester.pump(const Duration(milliseconds: 1600));
      expect(successCalled, isTrue);
    });

    testWidgets('invokes onClose when dismissible close icon is tapped',
        (WidgetTester tester) async {
      bool closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePasswordCard(
              authController: authController,
              isDismissible: true,
              onClose: () {
                closeCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
    });
  });
}
