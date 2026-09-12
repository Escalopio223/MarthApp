import 'package:flutter_test/flutter_test.dart';
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

class MockLeisureRepository implements ILeisureRepository {
  List<LeisureMediaDetails> nowPlayingMovies = [];
  List<LeisureMediaDetails> popularMedia = [];
  List<LeisureMediaDetails> searchResults = [];
  List<LeisureUserItemModel> userItems = [];
  List<LeisureSharedListModel> sharedLists = [];
  List<LeisureEnvironmentMatchModel> matches = [];

  LeisureUserItemModel? lastSavedItem;
  bool deleteUserItemCalled = false;

  @override
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({String region = 'ES', int page = 1}) async {
    return nowPlayingMovies;
  }

  @override
  Future<List<LeisureMediaDetails>> getPopularMedia({required LeisureMediaType type, int page = 1}) async {
    return popularMedia;
  }

  @override
  Future<List<LeisureMediaDetails>> searchMedia({required String query, required LeisureMediaType type, int page = 1}) async {
    return searchResults;
  }

  @override
  Future<LeisureMediaDetails> getMediaDetails({required String mediaId, required LeisureMediaType type, bool forceRefresh = false}) async {
    return LeisureMediaDetails(mediaId: mediaId, mediaType: type, title: 'Detalle $mediaId');
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
  Future<List<LeisureUserItemModel>> getUserItems({LeisureMediaType? type, LeisureItemStatus? status}) async {
    return userItems;
  }

  @override
  Future<LeisureUserItemModel> saveUserItem(LeisureUserItemModel item) async {
    lastSavedItem = item;
    return item;
  }

  @override
  Future<void> deleteUserItem({required String mediaId, required LeisureMediaType type}) async {
    deleteUserItemCalled = true;
  }

  @override
  Future<List<LeisureSharedListModel>> getSharedLists({required String environmentId}) async {
    return sharedLists;
  }

  @override
  Future<LeisureSharedListModel> createSharedList({required String environmentId, required String title, String? description}) async {
    final list = LeisureSharedListModel(
      id: 'list_123',
      environmentId: environmentId,
      createdBy: 'u1',
      title: title,
      description: description,
      createdAt: DateTime.now(),
    );
    sharedLists.add(list);
    return list;
  }

  @override
  Future<void> deleteSharedList({required String listId}) async {}

  @override
  Future<List<LeisureSharedListItemModel>> getSharedListItems({required String listId}) async => [];

  @override
  Future<LeisureSharedListItemModel> addSharedListItem({
    required String listId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    String? posterUrl,
    LeisureMediaDetails? detailsToCache,
  }) async {
    return LeisureSharedListItemModel(
      id: 'item_123',
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
  Future<List<LeisureEnvironmentMatchModel>> getEnvironmentMatches({required String environmentId}) async {
    return matches;
  }

  @override
  Future<LeisureEnvironmentMatchModel> recordEnvironmentMatch({
    required String environmentId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    required String matchedUserId,
  }) async {
    return LeisureEnvironmentMatchModel(
      id: 'match_123',
      environmentId: environmentId,
      mediaId: mediaId,
      mediaType: mediaType,
      title: title,
      matchedUserIds: [matchedUserId],
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  late MockLeisureRepository mockRepo;
  late LeisureController controller;

  setUp(() {
    mockRepo = MockLeisureRepository();
    controller = LeisureController(repository: mockRepo);
  });

  test('LeisureController initializes with personal environment and loads catalog', () async {
    final movie = const LeisureMediaDetails(
      mediaId: 'm1',
      mediaType: LeisureMediaType.movie,
      title: 'Inception',
    );
    mockRepo.nowPlayingMovies = [movie];

    await controller.initialize('user_1', environmentId: 'env_1', isPersonal: true);

    expect(controller.currentUserId, 'user_1');
    expect(controller.isPersonalEnvironment, isTrue);
    expect(controller.selectedType, LeisureMediaType.movie);
    expect(controller.catalogItems.length, 1);
    expect(controller.catalogItems.first.title, 'Inception');
    // En entorno personal, no carga listas compartidas
    expect(controller.sharedLists, isEmpty);
  });

  test('LeisureController updates environment to collaborative and loads shared lists', () async {
    mockRepo.sharedLists = [
      LeisureSharedListModel(
        id: 'list_1',
        environmentId: 'collab_env',
        createdBy: 'u1',
        title: 'Viernes de Cine',
        createdAt: DateTime.now(),
      )
    ];

    await controller.initialize('user_1', environmentId: 'env_pers', isPersonal: true);
    expect(controller.sharedLists, isEmpty);

    await controller.setEnvironment('collab_env', isPersonal: false);
    expect(controller.isPersonalEnvironment, isFalse);
    expect(controller.sharedLists.length, 1);
    expect(controller.sharedLists.first.title, 'Viernes de Cine');
  });

  test('LeisureController performs optimistic update for status and rating 1.0 to 10.0', () async {
    await controller.initialize('user_1');

    const media = LeisureMediaDetails(
      mediaId: '101',
      mediaType: LeisureMediaType.movie,
      title: 'Dune',
    );

    // Initial state is null
    expect(controller.getUserItem(LeisureMediaType.movie, '101'), isNull);

    // Optimistic status update
    await controller.setUserItemStatus(
      media: media,
      newStatus: LeisureItemStatus.favorite,
      rating: 9.4,
    );

    final item = controller.getUserItem(LeisureMediaType.movie, '101');
    expect(item, isNotNull);
    expect(item!.status, LeisureItemStatus.favorite);
    expect(item.rating, 9.4);
    expect(mockRepo.lastSavedItem?.rating, 9.4);
  });

  test('LeisureController roulette toggle tracks items in memory', () {
    const media1 = LeisureMediaDetails(mediaId: '1', mediaType: LeisureMediaType.movie, title: 'M1');
    const media2 = LeisureMediaDetails(mediaId: '2', mediaType: LeisureMediaType.game, title: 'G1');

    expect(controller.rouletteCount, 0);

    final added1 = controller.toggleRouletteItem(media1);
    expect(added1, isTrue);
    expect(controller.rouletteCount, 1);
    expect(controller.isRouletteSelected(LeisureMediaType.movie, '1'), isTrue);

    controller.toggleRouletteItem(media2);
    expect(controller.rouletteCount, 2);

    // Toggle again removes
    final removed = controller.toggleRouletteItem(media1);
    expect(removed, isFalse);
    expect(controller.rouletteCount, 1);
    expect(controller.isRouletteSelected(LeisureMediaType.movie, '1'), isFalse);
  });
}
