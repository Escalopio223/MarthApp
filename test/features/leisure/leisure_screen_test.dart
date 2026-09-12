import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:marth_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:marth_app/features/home/presentation/screens/home_screen.dart';
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

class FakeLeisureRepo implements ILeisureRepository {
  List<LeisureMediaDetails> movies = [
    const LeisureMediaDetails(
      mediaId: 'm1',
      mediaType: LeisureMediaType.movie,
      title: 'Interstellar',
      creatorOrDirector: 'Christopher Nolan',
      year: '2014',
      rating: 8.7,
      genres: ['Ciencia Ficción', 'Aventura'],
    ),
  ];

  @override
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({String region = 'ES', int page = 1}) async => movies;

  @override
  Future<List<LeisureMediaDetails>> getPopularMedia({required LeisureMediaType type, int page = 1}) async => movies;

  @override
  Future<List<LeisureMediaDetails>> searchMedia({required String query, required LeisureMediaType type, int page = 1}) async {
    return movies.where((m) => m.title.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  Future<LeisureMediaDetails> getMediaDetails({required String mediaId, required LeisureMediaType type, bool forceRefresh = false}) async {
    return movies.first;
  }

  @override
  Future<List<StreamingProviderDto>> getWatchProviders({required String mediaId, required LeisureMediaType type, String region = 'ES'}) async => [];

  @override
  Future<TvSeasonDetailsDto> getTvSeasonDetails({required String seriesId, required int seasonNumber, bool forceRefresh = false}) async {
    return TvSeasonDetailsDto(
      id: 1,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      name: 'Temporada $seasonNumber',
      episodes: [],
    );
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
    return LeisureSharedListModel(
      id: '1',
      environmentId: environmentId,
      createdBy: 'u1',
      title: title,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteSharedList({required String listId}) async {}

  @override
  Future<List<LeisureSharedListItemModel>> getSharedListItems({required String listId}) async => [];

  @override
  Future<LeisureSharedListItemModel> addSharedListItem({required String listId, required String mediaId, required LeisureMediaType mediaType, required String title, String? posterUrl, LeisureMediaDetails? detailsToCache}) async {
    return LeisureSharedListItemModel(
      id: '1',
      listId: listId,
      mediaId: mediaId,
      mediaType: mediaType,
      title: title,
      addedBy: 'u1',
      createdAt: DateTime.now(),
    );
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
  testWidgets('LeisureScreen renders categories, search bar and catalog cards', (tester) async {
    final repo = FakeLeisureRepo();
    final controller = LeisureController(repository: repo);
    await controller.initialize('user_123');

    await tester.pumpWidget(
      MaterialApp(
        home: LeisureScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ocio & Cultura'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Películas'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('Libros'), findsOneWidget);
    expect(find.text('Videojuegos'), findsOneWidget);
    expect(find.text('Explorar Catálogo'), findsOneWidget);
    expect(find.text('Mis Guardados'), findsOneWidget);
    expect(find.text('Interstellar'), findsOneWidget);
  });

  testWidgets('HomeScreen displays Ocio & Cultura card and tapping opens LeisureScreen', (tester) async {
    final repo = FakeLeisureRepo();
    final leisureController = LeisureController(repository: repo);
    await leisureController.initialize('user_123');

    final authController = AuthController(authService: FakeAuthRepo());

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          authController: authController,
          leisureController: leisureController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Ocio & Cultura card is present on HomeScreen
    expect(find.text('Ocio & Cultura'), findsOneWidget);
    expect(find.text('Películas, Series, Libros y Videojuegos'), findsOneWidget);

    // Tap on Ocio & Cultura card
    await tester.tap(find.text('Ocio & Cultura'));
    await tester.pumpAndSettle();

    // LeisureScreen should be visible
    expect(find.byType(LeisureScreen), findsOneWidget);
    expect(find.text('Explorar Catálogo'), findsOneWidget);
  });
}
