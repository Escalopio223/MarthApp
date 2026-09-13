import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/widgets/marth_app_logo.dart';
import 'package:marth_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:marth_app/features/environments/domain/models/environment_invitation_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_member_model.dart';
import 'package:marth_app/features/environments/domain/models/environment_model.dart';
import 'package:marth_app/features/environments/domain/repositories/i_environment_repository.dart';
import 'package:marth_app/features/environments/presentation/controllers/environment_controller.dart';
import 'package:marth_app/features/environments/presentation/widgets/environment_selector_chip.dart';
import 'package:marth_app/features/environments/presentation/widgets/environments_home_view.dart';
import 'package:marth_app/features/friends/presentation/controllers/friends_controller.dart';
import 'package:marth_app/features/home/presentation/screens/home_screen.dart';
import 'package:marth_app/features/home/presentation/widgets/marth_bottom_nav_bar.dart';
import 'package:marth_app/features/leisure/domain/models/book_edition_dto.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_environment_match_model.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_item_status.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_media_details.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_media_type.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_shared_list_item_model.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_shared_list_model.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_user_item_model.dart';
import 'package:marth_app/features/leisure/domain/models/streaming_provider_dto.dart';
import 'package:marth_app/features/leisure/domain/models/tv_season_details_dto.dart';
import 'package:marth_app/features/leisure/domain/repositories/i_leisure_repository.dart';
import 'package:marth_app/features/leisure/presentation/controllers/leisure_controller.dart';
import 'package:marth_app/features/leisure/presentation/screens/leisure_screen.dart';
import 'package:marth_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepo implements IAuthRepository {
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
  Future<UserResponse> updatePassword(String newPassword) async =>
      UserResponse.fromJson({
        'id': 'test-id',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': DateTime.now().toIso8601String(),
      });
  @override
  Future<void> signOut() async {}
}

class FakeEnvironmentRepo implements IEnvironmentRepository {
  final List<EnvironmentModel> _envs = [
    EnvironmentModel(
      id: 'env-personal',
      name: 'Mi Espacio',
      isPersonal: true,
      createdBy: 'user_123',
      createdAt: DateTime.now(),
      role: 'owner',
      memberCount: 1,
    ),
    EnvironmentModel(
      id: 'env-collab',
      name: 'Grupo Cinefilo',
      isPersonal: false,
      createdBy: 'user_123',
      createdAt: DateTime.now(),
      role: 'owner',
      memberCount: 3,
    ),
  ];

  @override
  Future<List<EnvironmentModel>> getEnvironments(String userId) async => List.from(_envs);

  @override
  Future<EnvironmentModel?> ensurePersonalEnvironment() async => _envs.first;

  @override
  Future<List<String>> getPendingInvitedUserIds(String environmentId) async => [];

  @override
  Future<EnvironmentModel?> createEnvironment({required String name}) async => null;

  @override
  Future<bool> deleteEnvironment(String environmentId) async => true;

  @override
  Future<List<EnvironmentMemberModel>> getEnvironmentMembers(String environmentId) async => [];

  @override
  Future<bool> removeMember({required String environmentId, required String userId}) async => true;

  @override
  Future<bool> leaveEnvironment({required String environmentId, required String userId}) async => true;

  @override
  Future<List<EnvironmentInvitationModel>> getPendingInvitations(String userId) async => [];

  @override
  Future<bool> sendInvitation({required String environmentId, required String receiverId, required String senderId}) async => true;

  @override
  Future<bool> respondInvitation({required String invitationId, required bool accept}) async => true;

  @override
  Future<bool> migrateContent({required String sourceEnvironmentId, required String targetEnvironmentId}) async => true;

  @override
  RealtimeChannel? subscribeToInvitations(String userId, VoidCallback onUpdate) => null;

  @override
  Future<void> unsubscribe(RealtimeChannel? channel) async {}
}

class FakeLeisureRepo implements ILeisureRepository {
  @override
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({String region = 'ES', int page = 1}) async => [];
  @override
  Future<List<LeisureMediaDetails>> getPopularMedia({required LeisureMediaType type, int page = 1}) async => [];
  @override
  Future<List<LeisureMediaDetails>> searchMedia({required String query, required LeisureMediaType type, int page = 1}) async => [];
  @override
  Future<LeisureMediaDetails> getMediaDetails({required String mediaId, required LeisureMediaType type, bool forceRefresh = false}) async {
    return const LeisureMediaDetails(mediaId: '1', mediaType: LeisureMediaType.movie, title: 'Test Movie');
  }
  @override
  Future<List<StreamingProviderDto>> getWatchProviders({required String mediaId, required LeisureMediaType type, String region = 'ES'}) async => [];
  @override
  Future<TvSeasonDetailsDto> getTvSeasonDetails({required String seriesId, required int seasonNumber, bool forceRefresh = false}) async {
    return TvSeasonDetailsDto(id: 1, seriesId: seriesId, seasonNumber: seasonNumber, name: 'Season 1', episodes: []);
  }
  @override
  Future<List<BookEditionDto>> getBookEditions({required String workId, bool forceRefresh = false}) async => [];
  @override
  Future<LeisureUserItemModel?> getUserItem({required String mediaId, required LeisureMediaType type}) async => null;
  @override
  Future<List<LeisureUserItemModel>> getUserItems({LeisureMediaType? type, LeisureItemStatus? status}) async => [];
  @override
  Future<LeisureUserItemModel> saveUserItem(LeisureUserItemModel item) async => item;
  @override
  Future<void> deleteUserItem({required String mediaId, required LeisureMediaType type}) async {}
  @override
  Future<List<LeisureSharedListModel>> getSharedLists({required String environmentId}) async => [];
  @override
  Future<LeisureSharedListModel> createSharedList({required String environmentId, required String title, String? description}) async {
    return LeisureSharedListModel(id: '1', environmentId: environmentId, createdBy: 'u1', title: title, createdAt: DateTime.now());
  }
  @override
  Future<void> deleteSharedList({required String listId}) async {}
  @override
  Future<List<LeisureSharedListItemModel>> getSharedListItems({required String listId}) async => [];
  @override
  Future<LeisureSharedListItemModel> addSharedListItem({required String listId, required String mediaId, required LeisureMediaType mediaType, required String title, String? posterUrl, LeisureMediaDetails? detailsToCache}) async {
    return LeisureSharedListItemModel(id: '1', listId: listId, mediaId: mediaId, mediaType: mediaType, title: title, addedBy: 'u1', createdAt: DateTime.now());
  }
  @override
  Future<void> removeSharedListItem({required String itemId}) async {}
  @override
  Future<List<LeisureEnvironmentMatchModel>> getEnvironmentMatches({required String environmentId}) async => [];
  @override
  Future<LeisureEnvironmentMatchModel> recordEnvironmentMatch({required String environmentId, required String mediaId, required LeisureMediaType mediaType, required String title, required String matchedUserId}) async {
    return LeisureEnvironmentMatchModel(id: '1', environmentId: environmentId, mediaId: mediaId, mediaType: mediaType, title: title, matchedUserIds: [matchedUserId], createdAt: DateTime.now());
  }
}

void main() {
  group('HomeScreen Minimalist Navigation Shell Tests', () {
    late AuthController authController;
    late EnvironmentController environmentController;
    late LeisureController leisureController;
    late FriendsController friendsController;
    late ProfileController profileController;

    setUp(() async {
      authController = AuthController(authRepository: FakeAuthRepo());
      environmentController = EnvironmentController(environmentRepository: FakeEnvironmentRepo());
      leisureController = LeisureController(repository: FakeLeisureRepo());
      friendsController = FriendsController();
      profileController = ProfileController();

      await environmentController.initialize('user_123');
      await leisureController.initialize('user_123');
    });

    Widget createTestApp({int initialIndex = 0}) {
      return MaterialApp(
        home: HomeScreen(
          authController: authController,
          environmentController: environmentController,
          leisureController: leisureController,
          friendsController: friendsController,
          profileController: profileController,
          initialIndex: initialIndex,
        ),
      );
    }

    testWidgets('HomeScreen mounts EnvironmentsHomeView and does NOT mount LeisureScreen on startup (deferred rendering)', (tester) async {
      await tester.pumpWidget(createTestApp(initialIndex: 0));
      await tester.pumpAndSettle();

      // EnvironmentsHomeView is mounted on Tab 0
      expect(find.byType(EnvironmentsHomeView), findsOneWidget);
      // LeisureScreen must NOT be mounted yet
      expect(find.byType(LeisureScreen), findsNothing);

      // Bottom nav bar must be visible with 2 tabs
      expect(find.byType(MarthBottomNavBar), findsOneWidget);
      expect(find.text('Entornos'), findsOneWidget);
      expect(find.text('Ocio'), findsOneWidget);
    });

    testWidgets('AppBar renders large logo, user avatar and EnvironmentSelectorChip in top menu', (tester) async {
      await tester.pumpWidget(createTestApp(initialIndex: 0));
      await tester.pumpAndSettle();

      // EnvironmentSelectorChip is present in top AppBar
      expect(find.byType(EnvironmentSelectorChip), findsOneWidget);

      // Large logo badge is present
      expect(find.byType(MarthAppLogo), findsOneWidget);
    });

    testWidgets('Tapping Ocio tab mounts LeisureScreen', (tester) async {
      await tester.pumpWidget(createTestApp(initialIndex: 0));
      await tester.pumpAndSettle();

      // Tap on the Ocio tab in bottom nav
      await tester.tap(find.text('Ocio'));
      await tester.pumpAndSettle();

      // LeisureScreen is now mounted deferred
      expect(find.byType(LeisureScreen), findsOneWidget);
    });

    testWidgets('Switching environment immediately updates LeisureController', (tester) async {
      await tester.pumpWidget(createTestApp(initialIndex: 0));
      await tester.pumpAndSettle();

      expect(environmentController.activeEnvironment?.isPersonal, isTrue);
      expect(leisureController.isPersonalEnvironment, isTrue);

      // Select collaborative environment
      final collabEnv = environmentController.environments.firstWhere((e) => !e.isPersonal);
      environmentController.selectEnvironment(collabEnv);
      await tester.pumpAndSettle();

      // LeisureController must immediately reflect the new environment
      expect(leisureController.currentEnvironmentId, equals(collabEnv.id));
      expect(leisureController.isPersonalEnvironment, isFalse);
    });
  });
}
