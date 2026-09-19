import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/environments/domain/models/environment_model.dart';
import 'package:marth_app/features/environments/domain/repositories/i_environment_repository.dart';
import 'package:marth_app/features/environments/presentation/controllers/environment_controller.dart';
import 'package:marth_app/features/environments/presentation/widgets/create_environment_modal.dart';
import 'package:marth_app/features/environments/domain/models/environment_invitation_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockCustomEnvRepository implements IEnvironmentRepository {
  String? lastCreatedName;
  String? lastCreatedIcon;
  String? lastCreatedColor;

  @override
  Future<EnvironmentModel?> createEnvironment({
    required String name,
    String? icon,
    String? color,
  }) async {
    lastCreatedName = name;
    lastCreatedIcon = icon;
    lastCreatedColor = color;
    return EnvironmentModel(
      id: 'env_custom_1',
      name: name,
      isPersonal: false,
      createdBy: 'user_test',
      createdAt: DateTime.now(),
      role: 'owner',
      icon: icon,
      color: color,
    );
  }

  @override
  Future<List<EnvironmentModel>> getEnvironments(String userId) async => [];

  @override
  Future<EnvironmentModel?> ensurePersonalEnvironment() async => null;

  @override
  Future<List<String>> getPendingInvitedUserIds(String environmentId) async =>
      [];

  @override
  Future<bool> deleteEnvironment(String environmentId) async => true;

  @override
  Future<List<EnvironmentMemberModel>> getEnvironmentMembers(
    String environmentId,
  ) async => [];

  @override
  Future<bool> removeMember({
    required String environmentId,
    required String userId,
  }) async => true;

  @override
  Future<bool> leaveEnvironment({
    required String environmentId,
    required String userId,
  }) async => true;

  @override
  Future<List<EnvironmentInvitationModel>> getPendingInvitations(
    String userId,
  ) async => [];

  @override
  Future<bool> sendInvitation({
    required String environmentId,
    required String receiverId,
    required String senderId,
  }) async => true;

  @override
  Future<bool> respondInvitation({
    required String invitationId,
    required bool accept,
  }) async => true;

  @override
  Future<bool> migrateContent({
    required String sourceEnvironmentId,
    required String targetEnvironmentId,
  }) async => true;

  @override
  RealtimeChannel? subscribeToInvitations(
    String userId,
    void Function() onInvitationsChanged,
  ) => null;

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {}
}

void main() {
  group('EnvironmentModel & Theme Helper Tests', () {
    test('resolves custom icon and custom color correctly', () {
      final env = EnvironmentModel(
        id: 'env_1',
        name: 'Cinefilos',
        isPersonal: false,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        icon: 'movie',
        color: '#EC4899',
      );

      expect(env.iconData, equals(Icons.movie_filter_rounded));
      expect(env.colorValue, equals(const Color(0xFFEC4899)));
    });

    test('falls back safely when icon or color is null or unknown', () {
      final personalEnv = EnvironmentModel(
        id: 'env_personal',
        name: 'Mi espacio',
        isPersonal: true,
        createdBy: 'u1',
        createdAt: DateTime.now(),
      );

      expect(personalEnv.iconData, equals(Icons.person_pin_rounded));
      expect(personalEnv.colorValue, equals(const Color(0xFF06B6D4)));

      final collabEnv = EnvironmentModel(
        id: 'env_collab',
        name: 'Equipo',
        isPersonal: false,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        icon: 'non_existing_icon',
      );

      expect(collabEnv.iconData, equals(Icons.groups_rounded));
      expect(collabEnv.colorValue, equals(const Color(0xFF10B981)));
    });

    test('toJson and fromJson preserves icon and color', () {
      final original = EnvironmentModel(
        id: 'env_3',
        name: 'Gamers',
        isPersonal: false,
        createdBy: 'u1',
        createdAt: DateTime.parse('2026-01-01T12:00:00.000Z'),
        icon: 'game',
        color: '#6366F1',
      );

      final json = original.toJson();
      expect(json['icon'], equals('game'));
      expect(json['color'], equals('#6366F1'));

      final reconstructed = EnvironmentModel.fromJson(json);
      expect(reconstructed.icon, equals('game'));
      expect(reconstructed.color, equals('#6366F1'));
      expect(reconstructed.iconData, equals(Icons.sports_esports_rounded));
      expect(reconstructed.colorValue, equals(const Color(0xFF6366F1)));
    });
  });

  group('EnvironmentController Customization Integration', () {
    test(
      'passes custom icon and color to repository during creation',
      () async {
        final mockRepo = MockCustomEnvRepository();
        final controller = EnvironmentController(
          environmentRepository: mockRepo,
        );

        final ok = await controller.createEnvironment(
          'Club de Lectura',
          icon: 'book',
          color: '#F59E0B',
        );

        expect(ok, isTrue);
        expect(mockRepo.lastCreatedName, equals('Club de Lectura'));
        expect(mockRepo.lastCreatedIcon, equals('book'));
        expect(mockRepo.lastCreatedColor, equals('#F59E0B'));
        expect(controller.activeEnvironment?.name, equals('Club de Lectura'));
        expect(controller.activeEnvironment?.icon, equals('book'));
        expect(controller.activeEnvironment?.color, equals('#F59E0B'));
        expect(
          controller.activeEnvironment?.iconData,
          equals(Icons.auto_stories_rounded),
        );
        expect(
          controller.activeEnvironment?.colorValue,
          equals(const Color(0xFFF59E0B)),
        );
      },
    );
  });

  group('CreateEnvironmentModal Widget Tests', () {
    testWidgets(
      'renders icon and color selectors and creates custom environment',
      (tester) async {
        final mockRepo = MockCustomEnvRepository();
        final controller = EnvironmentController(
          environmentRepository: mockRepo,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CreateEnvironmentModal(environmentController: controller),
            ),
          ),
        );

        expect(find.text('Nuevo entorno'), findsOneWidget);
        expect(find.text('Color del Entorno'), findsOneWidget);
        expect(find.text('Icono del Entorno'), findsOneWidget);
        expect(find.text('Nombre del Entorno'), findsOneWidget);

        // Verify colors and icons rendered
        expect(
          find.byKey(const ValueKey('color_option_#EC4899')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('icon_option_travel')),
          findsOneWidget,
        );

        // Enter environment name
        await tester.enterText(find.byType(TextFormField), 'Viaje Tokio');
        await tester.pump();

        // Live preview should show entered name
        expect(
          find.byWidgetPredicate((w) => w is Text && w.data == 'Viaje Tokio'),
          findsOneWidget,
        );

        // Select hot pink color and travel icon
        await tester.tap(find.byKey(const ValueKey('color_option_#EC4899')));
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('icon_option_travel')));
        await tester.pump();

        // Submit
        await tester.tap(find.text('Crear Entorno'));
        await tester.pumpAndSettle();

        expect(mockRepo.lastCreatedName, equals('Viaje Tokio'));
        expect(mockRepo.lastCreatedIcon, equals('travel'));
        expect(mockRepo.lastCreatedColor, equals('#EC4899'));
      },
    );
  });
}
