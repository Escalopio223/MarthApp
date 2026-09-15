import 'package:flutter/material.dart';
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
import 'package:marth_app/features/leisure/presentation/widgets/leisure_detail_sheet.dart';
import 'package:marth_app/features/leisure/presentation/widgets/leisure_media_card.dart';
import 'package:marth_app/features/leisure/presentation/widgets/leisure_provider_filter_bar.dart';

class MockStreamingRepo implements ILeisureRepository {
  List<StreamingProviderDto> lastProvidedList = [];
  String? lastRequestedRegion;

  @override
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({String region = 'ES', int page = 1}) async => [];

  @override
  Future<List<LeisureMediaDetails>> getPopularMedia({required LeisureMediaType type, int page = 1}) async => [];

  @override
  Future<List<LeisureMediaDetails>> searchMedia({required String query, required LeisureMediaType type, int page = 1}) async => [];

  @override
  Future<List<LeisureMediaDetails>> getMediaByProvider({
    required LeisureMediaType type,
    required int providerId,
    String region = 'ES',
    int page = 1,
  }) async => [];

  @override
  Future<LeisureMediaDetails> getMediaDetails({required String mediaId, required LeisureMediaType type, bool forceRefresh = false}) async {
    return LeisureMediaDetails(
      mediaId: mediaId,
      mediaType: type,
      title: 'Título de Prueba',
      watchProviders: lastProvidedList,
    );
  }

  @override
  Future<List<StreamingProviderDto>> getWatchProviders({
    required String mediaId,
    required LeisureMediaType type,
    String region = 'ES',
  }) async {
    lastRequestedRegion = region;
    if (region == 'US') {
      return const [
        StreamingProviderDto(providerId: 15, providerName: 'Hulu', logoPath: '/hulu.jpg'),
      ];
    }
    return const [
      StreamingProviderDto(providerId: 8, providerName: 'Netflix', logoPath: '/n.jpg'),
      StreamingProviderDto(providerId: 337, providerName: 'Disney+', logoPath: '/d.jpg'),
    ];
  }

  @override
  Future<TvSeasonDetailsDto> getTvSeasonDetails({required String seriesId, required int seasonNumber, bool forceRefresh = false}) async =>
      TvSeasonDetailsDto(id: 1, seriesId: seriesId, seasonNumber: seasonNumber, name: 'T1', episodes: []);

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
  Future<LeisureSharedListModel> createSharedList({required String environmentId, required String title, String? description}) async =>
      LeisureSharedListModel(id: '1', environmentId: environmentId, createdBy: 'u1', title: title, createdAt: DateTime.now());

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
    String? year,
    double? rating,
    List<String>? genres,
    int? customOrder,
    LeisureMediaDetails? detailsToCache,
    bool? isFreeToPlay,
  }) async =>
      LeisureSharedListItemModel(
        id: '1',
        listId: listId,
        mediaId: mediaId,
        mediaType: mediaType,
        title: title,
        isFreeToPlay: isFreeToPlay,
        addedBy: 'u1',
        createdAt: DateTime.now(),
      );

  @override
  Future<void> removeSharedListItem({required String itemId}) async {}

  @override
  Future<void> reorderSharedListItems({
    required String listId,
    required List<String> orderedItemIds,
  }) async {}

  @override
  Future<List<LeisureEnvironmentMatchModel>> getEnvironmentMatches({required String environmentId}) async => [];

  @override
  Future<void> clearEnvironmentMatches({required String environmentId}) async {}

  @override
  Future<LeisureEnvironmentMatchModel> recordEnvironmentMatch({
    required String environmentId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    required String matchedUserId,
  }) async =>
      LeisureEnvironmentMatchModel(
        id: 'match_1',
        environmentId: environmentId,
        mediaId: mediaId,
        mediaType: mediaType,
        title: title,
        matchedUserIds: [matchedUserId],
        createdAt: DateTime.now(),
      );
}

void main() {
  group('Streaming Providers UI Widget Tests', () {
    testWidgets('LeisureProviderFilterBar renders platforms and triggers callback', (tester) async {
      int? selectedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeisureProviderFilterBar(
              selectedProviderId: selectedId,
              onProviderSelected: (id) => selectedId = id,
            ),
          ),
        ),
      );

      // Verify "Todas", "Netflix", "Disney+", "Hulu" are rendered
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Disney+'), findsOneWidget);

      // Tap Netflix
      await tester.tap(find.text('Netflix'));
      await tester.pump();
      expect(selectedId, equals(8));

      // Rerender with Netflix selected
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeisureProviderFilterBar(
              selectedProviderId: 8,
              onProviderSelected: (id) => selectedId = id,
            ),
          ),
        ),
      );

      // Tap Netflix again to deselect
      await tester.tap(find.text('Netflix'));
      await tester.pump();
      expect(selectedId, isNull);
    });

    testWidgets('LeisureMediaCard renders provider overlay when providers are present', (tester) async {
      const mediaWithProviders = LeisureMediaDetails(
        mediaId: '550',
        mediaType: LeisureMediaType.movie,
        title: 'El Club de la Lucha',
        watchProviders: [
          StreamingProviderDto(providerId: 8, providerName: 'Netflix', logoPath: ''),
          StreamingProviderDto(providerId: 337, providerName: 'Disney+', logoPath: ''),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 280,
              child: LeisureMediaCard(
                media: mediaWithProviders,
                isRouletteSelected: false,
                onTap: () {},
                onRouletteToggle: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('El Club de la Lucha'), findsOneWidget);
      // Play icon fallback for logoPath=''
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNWidgets(2));
    });

    testWidgets('LeisureDetailSheet renders Dónde Ver section and supports region switching to US for Hulu', (tester) async {
      final mockRepo = MockStreamingRepo();
      mockRepo.lastProvidedList = [
        const StreamingProviderDto(providerId: 8, providerName: 'Netflix', logoPath: ''),
      ];

      final controller = LeisureController(repository: mockRepo);

      const media = LeisureMediaDetails(
        mediaId: '100',
        mediaType: LeisureMediaType.movie,
        title: 'Película Genial',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeisureDetailSheet(
              initialMedia: media,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Dónde Ver" section exists
      expect(find.text('Dónde Ver'), findsOneWidget);
      expect(find.text('🇪🇸 ES'), findsOneWidget);
      expect(find.text('🇺🇸 US'), findsOneWidget);
      expect(find.text('🇲🇽 MX'), findsOneWidget);

      // Verify initial Netflix provider is rendered
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Suscripción'), findsOneWidget);

      // Tap US region to check Hulu
      await tester.tap(find.text('🇺🇸 US'));
      await tester.pumpAndSettle();

      expect(mockRepo.lastRequestedRegion, equals('US'));
      expect(find.text('Hulu'), findsOneWidget);
    });
  });
}
