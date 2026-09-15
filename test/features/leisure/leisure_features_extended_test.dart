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
import 'package:marth_app/features/leisure/presentation/widgets/leisure_dice_winner_dialog.dart';
import 'package:marth_app/features/leisure/presentation/widgets/leisure_media_type_selector.dart';
import 'package:marth_app/features/leisure/presentation/widgets/leisure_shared_lists_sheet.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_list_sort_option.dart';

class MockLeisureRepository implements ILeisureRepository {
  List<LeisureSharedListModel> sharedLists = [];
  Map<String, List<LeisureSharedListItemModel>> sharedItems = {};

  @override
  Future<List<LeisureMediaDetails>> getNowPlayingMovies({
    String region = 'ES',
    int page = 1,
  }) async => [];

  @override
  Future<List<LeisureMediaDetails>> getPopularMedia({
    required LeisureMediaType type,
    int page = 1,
  }) async => [];

  @override
  Future<List<LeisureMediaDetails>> searchMedia({
    required String query,
    required LeisureMediaType type,
    int page = 1,
  }) async => [];

  @override
  Future<List<LeisureMediaDetails>> getMediaByProvider({
    required LeisureMediaType type,
    required int providerId,
    String region = 'ES',
    int page = 1,
  }) async => [];

  @override
  Future<LeisureMediaDetails> getMediaDetails({
    required String mediaId,
    required LeisureMediaType type,
    bool forceRefresh = false,
  }) async {
    return LeisureMediaDetails(
      mediaId: mediaId,
      mediaType: type,
      title: 'Título de Prueba',
    );
  }

  @override
  Future<List<StreamingProviderDto>> getWatchProviders({
    required String mediaId,
    required LeisureMediaType type,
    String region = 'ES',
  }) async => [];

  @override
  Future<TvSeasonDetailsDto> getTvSeasonDetails({
    required String seriesId,
    required int seasonNumber,
    bool forceRefresh = false,
  }) async {
    return TvSeasonDetailsDto(
      id: 1,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      name: 'T1',
      episodes: [],
    );
  }

  @override
  Future<List<BookEditionDto>> getBookEditions({
    required String workId,
    bool forceRefresh = false,
  }) async => [];

  @override
  Future<LeisureUserItemModel?> getUserItem({
    required String mediaId,
    required LeisureMediaType type,
  }) async => null;

  @override
  Future<List<LeisureUserItemModel>> getUserItems({
    LeisureMediaType? type,
    LeisureItemStatus? status,
  }) async => [];

  @override
  Future<LeisureUserItemModel> saveUserItem(LeisureUserItemModel item) async =>
      item;

  @override
  Future<void> deleteUserItem({
    required String mediaId,
    required LeisureMediaType type,
  }) async {}

  @override
  Future<List<LeisureSharedListModel>> getSharedLists({
    required String environmentId,
  }) async => sharedLists;

  @override
  Future<LeisureSharedListModel> createSharedList({
    required String environmentId,
    required String title,
    String? description,
  }) async {
    final list = LeisureSharedListModel(
      id: 'list_${sharedLists.length + 1}',
      environmentId: environmentId,
      createdBy: 'user_1',
      title: title,
      description: description,
      itemsCount: 0,
      createdAt: DateTime.now(),
    );
    sharedLists.add(list);
    return list;
  }

  @override
  Future<void> deleteSharedList({required String listId}) async {
    sharedLists.removeWhere((l) => l.id == listId);
  }

  @override
  Future<List<LeisureSharedListItemModel>> getSharedListItems({
    required String listId,
  }) async {
    return sharedItems[listId] ?? [];
  }

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
  }) async {
    final item = LeisureSharedListItemModel(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}_$mediaId',
      listId: listId,
      mediaId: mediaId,
      mediaType: mediaType,
      title: title,
      posterUrl: posterUrl,
      year: year,
      rating: rating,
      genres: genres ?? const [],
      customOrder: customOrder ?? 0,
      isFreeToPlay: isFreeToPlay,
      addedBy: 'user_1',
      createdAt: DateTime.now(),
    );
    final current = sharedItems[listId] ?? [];
    sharedItems[listId] = [...current, item];
    sharedLists = sharedLists.map((l) {
      if (l.id == listId) {
        return LeisureSharedListModel(
          id: l.id,
          environmentId: l.environmentId,
          createdBy: l.createdBy,
          title: l.title,
          description: l.description,
          itemsCount: l.itemsCount + 1,
          createdAt: l.createdAt,
        );
      }
      return l;
    }).toList();
    return item;
  }

  @override
  Future<void> reorderSharedListItems({
    required String listId,
    required List<String> orderedItemIds,
  }) async {
    final list = sharedItems[listId] ?? [];
    final map = {for (final item in list) item.id: item};
    final reordered = <LeisureSharedListItemModel>[];
    for (int i = 0; i < orderedItemIds.length; i++) {
      final id = orderedItemIds[i];
      if (map.containsKey(id)) {
        reordered.add(map[id]!.copyWith(customOrder: i));
      }
    }
    sharedItems[listId] = reordered;
  }

  @override
  Future<void> removeSharedListItem({required String itemId}) async {
    for (final key in sharedItems.keys) {
      final list = sharedItems[key] ?? [];
      if (list.any((i) => i.id == itemId)) {
        sharedItems[key] = list.where((i) => i.id != itemId).toList();
        sharedLists = sharedLists.map((l) {
          if (l.id == key) {
            return LeisureSharedListModel(
              id: l.id,
              environmentId: l.environmentId,
              createdBy: l.createdBy,
              title: l.title,
              description: l.description,
              itemsCount: (l.itemsCount - 1).clamp(0, 999999),
              createdAt: l.createdAt,
            );
          }
          return l;
        }).toList();
      }
    }
  }

  @override
  Future<List<LeisureEnvironmentMatchModel>> getEnvironmentMatches({
    required String environmentId,
  }) async => [];

  @override
  Future<LeisureEnvironmentMatchModel> recordEnvironmentMatch({
    required String environmentId,
    required String mediaId,
    required LeisureMediaType mediaType,
    required String title,
    required String matchedUserId,
  }) async {
    return LeisureEnvironmentMatchModel(
      id: 'match_1',
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
  group('LeisureController Dice & Roulette Tests', () {
    late MockLeisureRepository repo;
    late LeisureController controller;

    setUp(() {
      repo = MockLeisureRepository();
      controller = LeisureController(repository: repo);
    });

    test('Selecting multiple items for dice and rolling picks winner and auto-clears', () {
      const movie1 = LeisureMediaDetails(
        mediaId: 'm1',
        mediaType: LeisureMediaType.movie,
        title: 'Origen (Inception)',
        rating: 8.8,
      );
      const movie2 = LeisureMediaDetails(
        mediaId: 'm2',
        mediaType: LeisureMediaType.movie,
        title: 'Interstellar',
        rating: 8.7,
      );
      const series1 = LeisureMediaDetails(
        mediaId: 's1',
        mediaType: LeisureMediaType.tv,
        title: 'Breaking Bad',
        rating: 9.5,
      );

      // 1. Initial state
      expect(controller.rouletteCount, equals(0));
      expect(controller.rollRoulette(), isNull);

      // 2. Select items
      controller.toggleRouletteItem(movie1);
      controller.toggleRouletteItem(movie2);
      controller.toggleRouletteItem(series1);

      expect(controller.rouletteCount, equals(3));
      expect(
        controller.isRouletteSelected(LeisureMediaType.movie, 'm1'),
        isTrue,
      );
      expect(
        controller.isRouletteSelected(LeisureMediaType.movie, 'm2'),
        isTrue,
      );
      expect(controller.isRouletteSelected(LeisureMediaType.tv, 's1'), isTrue);

      // 3. Roll the dice
      final winner = controller.rollRoulette();
      expect(winner, isNotNull);
      expect([
        'Origen (Inception)',
        'Interstellar',
        'Breaking Bad',
      ], contains(winner!.title));

      // 4. Automatic clear verification
      expect(controller.rouletteCount, equals(0));
      expect(
        controller.isRouletteSelected(LeisureMediaType.movie, 'm1'),
        isFalse,
      );
      expect(
        controller.isRouletteSelected(LeisureMediaType.movie, 'm2'),
        isFalse,
      );
      expect(controller.isRouletteSelected(LeisureMediaType.tv, 's1'), isFalse);
    });

    test('clearRoulette manually empties selection', () {
      const game1 = LeisureMediaDetails(
        mediaId: 'g1',
        mediaType: LeisureMediaType.game,
        title: 'Zelda: Breath of the Wild',
      );

      controller.toggleRouletteItem(game1);
      expect(controller.rouletteCount, equals(1));

      controller.clearRoulette();
      expect(controller.rouletteCount, equals(0));
    });
  });

  group('LeisureController Environment Lists Tests', () {
    late MockLeisureRepository repo;
    late LeisureController controller;

    setUp(() {
      repo = MockLeisureRepository();
      controller = LeisureController(repository: repo);
    });

    test('Creating lists and adding items works in Personal Environment (Mi espacio)', () async {
      await controller.initialize(
        'user_1',
        environmentId: 'env_personal',
        isPersonal: true,
      );

      // Crear lista en entorno personal
      final list = await controller.createSharedList(
        'Películas para el viernes',
        'Maratón',
      );
      expect(list.title, equals('Películas para el viernes'));
      expect(controller.sharedLists.length, equals(1));
      expect(controller.sharedLists.first.itemsCount, equals(0));

      // Añadir película a la lista
      const movie = LeisureMediaDetails(
        mediaId: 'm100',
        mediaType: LeisureMediaType.movie,
        title: 'Spider-Man',
        posterUrl: 'https://image.tmdb.org/spiderman.jpg',
      );
      await controller.addMediaToSharedList(list.id, movie);

      // Comprobar que itemsCount se incrementó
      expect(controller.sharedLists.first.itemsCount, equals(1));

      final items = await controller.getSharedListItems(list.id);
      expect(items.length, equals(1));
      expect(items.first.title, equals('Spider-Man'));

      // Quitar de la lista
      await controller.removeMediaFromSharedList(items.first.id, list.id);
      expect(controller.sharedLists.first.itemsCount, equals(0));
    });
  });

  group('LeisureMediaTypeSelector Widget Tests', () {
    testWidgets(
      'Renders all 4 media types anchored without horizontal scroll',
      (tester) async {
        LeisureMediaType selected = LeisureMediaType.movie;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeisureMediaTypeSelector(
                selectedType: selected,
                onTypeChanged: (type) => selected = type,
              ),
            ),
          ),
        );

        // Verificar que los 4 tipos están en pantalla
        expect(find.text('Películas'), findsOneWidget);
        expect(find.text('Series'), findsOneWidget);
        expect(find.text('Libros'), findsOneWidget);
        expect(find.text('Videojuegos'), findsOneWidget);

        // Verificar que NO existe SingleChildScrollView (anclado)
        expect(find.byType(SingleChildScrollView), findsNothing);

        // Tocar en 'Series'
        await tester.tap(find.text('Series'));
        await tester.pump();
        expect(selected, equals(LeisureMediaType.tv));
      },
    );
  });

  group('LeisureDiceWinnerDialog Widget Tests', () {
    testWidgets('Displays winner details and auto-clear notice', (
      tester,
    ) async {
      final repo = MockLeisureRepository();
      final controller = LeisureController(repository: repo);

      const winner = LeisureMediaDetails(
        mediaId: 'm99',
        mediaType: LeisureMediaType.movie,
        title: 'El Padrino',
        year: '1972',
        rating: 9.2,
        overview: 'El patriarca de una dinastía del crimen organizado...',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    LeisureDiceWinnerDialog.show(
                      context,
                      winner: winner,
                      controller: controller,
                    );
                  },
                  child: const Text('Abrir Dado'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Dado'));
      await tester.pumpAndSettle();

      // Verificar reveal del ganador
      expect(find.text('¡El dado ha elegido!'), findsOneWidget);
      expect(find.text('El Padrino'), findsOneWidget);
      expect(find.text('PELÍCULA'), findsOneWidget);
      expect(find.text('1972'), findsOneWidget);
      expect(find.text('9.2'), findsOneWidget);
      expect(
        find.text('Selección del dado limpiada automáticamente'),
        findsOneWidget,
      );

      // Cerrar diálogo
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('¡El dado ha elegido!'), findsNothing);
    });
  });

  group('LeisureSharedListsSheet Widget Tests', () {
    testWidgets('Renders lists and expands to show items', (tester) async {
      final repo = MockLeisureRepository();
      final controller = LeisureController(repository: repo);
      await controller.initialize(
        'user_1',
        environmentId: 'env_1',
        isPersonal: true,
      );

      // Crear lista de prueba
      final list = await controller.createSharedList('Lista Finde', 'Comedia');
      await controller.addMediaToSharedList(
        list.id,
        const LeisureMediaDetails(
          mediaId: 'm1',
          mediaType: LeisureMediaType.movie,
          title: 'Deadpool & Wolverine',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LeisureSharedListsSheet(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que la lista aparece
      expect(find.text('Lista Finde'), findsOneWidget);
      expect(find.text('1 elemento(s)'), findsOneWidget);

      // Desplegar la lista
      await tester.tap(find.text('Lista Finde'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que el ítem aparece dentro de la lista
      expect(find.text('Deadpool & Wolverine'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('Renders F2P filter chip and badge for games and filters properly', (tester) async {
      final repo = MockLeisureRepository();
      final controller = LeisureController(repository: repo);
      await controller.initialize(
        'user_1',
        environmentId: 'env_1',
        isPersonal: true,
      );

      // Crear lista con videojuegos
      final list = await controller.createSharedList('Lista Juegos', 'Gaming');
      await controller.addMediaToSharedList(
        list.id,
        const LeisureMediaDetails(
          mediaId: 'g_fortnite',
          mediaType: LeisureMediaType.game,
          title: 'Fortnite',
          isFreeToPlay: true,
          rating: 8.0,
        ),
      );
      await controller.addMediaToSharedList(
        list.id,
        const LeisureMediaDetails(
          mediaId: 'g_elden_ring',
          mediaType: LeisureMediaType.game,
          title: 'Elden Ring',
          isFreeToPlay: false,
          rating: 9.6,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LeisureSharedListsSheet(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Desplegar la lista
      await tester.tap(find.text('Lista Juegos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que aparece el chip Free to Play (F2P)
      expect(find.text('Free to Play (F2P)'), findsOneWidget);
      // Verificar que aparece la insignia F2P
      expect(find.text('F2P'), findsOneWidget);

      // Ambos juegos están visibles inicialmente
      expect(find.text('Fortnite'), findsOneWidget);
      expect(find.text('Elden Ring'), findsOneWidget);

      // Pulsar chip de filtro F2P
      await tester.tap(find.text('Free to Play (F2P)'));
      await tester.pumpAndSettle();

      // Solo Fortnite debe estar visible ahora
      expect(find.text('Fortnite'), findsOneWidget);
      expect(find.text('Elden Ring'), findsNothing);
      expect(find.text('Mostrando 1 de 2 elemento(s)'), findsOneWidget);

      // Limpiar filtros pulsando el botón Limpiar filtros
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      // Ambos juegos vuelven a estar visibles
      expect(find.text('Fortnite'), findsOneWidget);
      expect(find.text('Elden Ring'), findsOneWidget);
    });
  });

  group('Shared Lists Sorting and Filtering Tests', () {
    late MockLeisureRepository repo;
    late LeisureController controller;
    late LeisureSharedListModel testList;

    setUp(() async {
      repo = MockLeisureRepository();
      controller = LeisureController(repository: repo);
      await controller.initialize('user_1', environmentId: 'env_1', isPersonal: true);
      testList = await controller.createSharedList('Lista Cine', 'Películas variadas');

      // Add three items with different years, ratings, and genres
      await controller.addMediaToSharedList(
        testList.id,
        const LeisureMediaDetails(
          mediaId: 'm_interstellar',
          mediaType: LeisureMediaType.movie,
          title: 'Interstellar',
          year: '2014',
          rating: 8.7,
          genres: ['Sci-Fi', 'Drama'],
        ),
      );

      await controller.addMediaToSharedList(
        testList.id,
        const LeisureMediaDetails(
          mediaId: 'm_godfather',
          mediaType: LeisureMediaType.movie,
          title: 'El Padrino',
          year: '1972',
          rating: 9.2,
          genres: ['Crimen', 'Drama'],
        ),
      );

      await controller.addMediaToSharedList(
        testList.id,
        const LeisureMediaDetails(
          mediaId: 'm_dune',
          mediaType: LeisureMediaType.movie,
          title: 'Dune: Parte Dos',
          year: '2024',
          rating: 8.5,
          genres: ['Sci-Fi', 'Aventura'],
        ),
      );
    });

    test('Available genres extraction is deduplicated and sorted', () {
      final genres = controller.getAvailableGenresForList(testList.id);
      expect(genres, containsAll(['Aventura', 'Crimen', 'Drama', 'Sci-Fi']));
      expect(genres.length, equals(4));
    });

    test('Sort by year descending and ascending', () {
      controller.setListSortOption(testList.id, LeisureListSortOption.yearDesc);
      var items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.map((i) => i.title).toList(), equals([
        'Dune: Parte Dos', // 2024
        'Interstellar',    // 2014
        'El Padrino',      // 1972
      ]));

      controller.setListSortOption(testList.id, LeisureListSortOption.yearAsc);
      items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.map((i) => i.title).toList(), equals([
        'El Padrino',      // 1972
        'Interstellar',    // 2014
        'Dune: Parte Dos', // 2024
      ]));
    });

    test('Sort by rating descending and ascending', () {
      controller.setListSortOption(testList.id, LeisureListSortOption.ratingDesc);
      var items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.map((i) => i.title).toList(), equals([
        'El Padrino',      // 9.2
        'Interstellar',    // 8.7
        'Dune: Parte Dos', // 8.5
      ]));

      controller.setListSortOption(testList.id, LeisureListSortOption.ratingAsc);
      items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.map((i) => i.title).toList(), equals([
        'Dune: Parte Dos', // 8.5
        'Interstellar',    // 8.7
        'El Padrino',      // 9.2
      ]));
    });

    test('Filter by genre isolates matching items', () {
      controller.setListGenreFilter(testList.id, 'Sci-Fi');
      var items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.length, equals(2));
      expect(items.map((i) => i.title), containsAll(['Interstellar', 'Dune: Parte Dos']));

      controller.setListGenreFilter(testList.id, 'Crimen');
      items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.length, equals(1));
      expect(items.first.title, equals('El Padrino'));

      controller.clearListFilters(testList.id);
      items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.length, equals(3));
    });

    test('Quick search within list matches substring case-insensitively', () {
      controller.setListSearchQuery(testList.id, 'padrino');
      var items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.length, equals(1));
      expect(items.first.title, equals('El Padrino'));

      controller.setListSearchQuery(testList.id, 'dune');
      items = controller.getFilteredAndSortedItems(testList.id);
      expect(items.length, equals(1));
      expect(items.first.title, equals('Dune: Parte Dos'));
    });

    test('Manual reordering updates order and persists', () async {
      controller.setListSortOption(testList.id, LeisureListSortOption.manual);
      var items = controller.getFilteredAndSortedItems(testList.id);
      expect(items[0].title, equals('Interstellar'));
      expect(items[1].title, equals('El Padrino'));
      expect(items[2].title, equals('Dune: Parte Dos'));

      // Move Dune: Parte Dos (index 2) to top (index 0)
      await controller.reorderSharedListItems(testList.id, 2, 0);

      items = controller.getFilteredAndSortedItems(testList.id);
      expect(items[0].title, equals('Dune: Parte Dos'));
      expect(items[1].title, equals('Interstellar'));
      expect(items[2].title, equals('El Padrino'));
    });

    test('Free to Play filter isolates F2P video games and ignores paid games & other media', () async {
      final gameList = await controller.createSharedList('Lista Gaming', 'Videojuegos y pelis');

      // Cine (no es videojuego)
      await controller.addMediaToSharedList(
        gameList.id,
        const LeisureMediaDetails(
          mediaId: 'm_avatar',
          mediaType: LeisureMediaType.movie,
          title: 'Avatar',
          genres: ['Acción', 'Sci-Fi'],
        ),
      );

      // Videojuego F2P con isFreeToPlay = true
      await controller.addMediaToSharedList(
        gameList.id,
        const LeisureMediaDetails(
          mediaId: 'g_fortnite',
          mediaType: LeisureMediaType.game,
          title: 'Fortnite',
          isFreeToPlay: true,
          genres: ['Shooter', 'Battle Royale'],
        ),
      );

      // Videojuego F2P detectado por género 'Free to Play'
      await controller.addMediaToSharedList(
        gameList.id,
        const LeisureMediaDetails(
          mediaId: 'g_genshin',
          mediaType: LeisureMediaType.game,
          title: 'Genshin Impact',
          genres: ['RPG', 'Free to Play'],
        ),
      );

      // Videojuego de pago (isFreeToPlay = false)
      await controller.addMediaToSharedList(
        gameList.id,
        const LeisureMediaDetails(
          mediaId: 'g_cyberpunk',
          mediaType: LeisureMediaType.game,
          title: 'Cyberpunk 2077',
          isFreeToPlay: false,
          genres: ['RPG', 'Sci-Fi'],
        ),
      );

      // hasGamesInList debe ser true
      expect(controller.hasGamesInList(gameList.id), isTrue);
      expect(controller.hasGamesInList(testList.id), isFalse); // testList solo tiene películas

      // Todos los ítems (4)
      var items = controller.getFilteredAndSortedItems(gameList.id);
      expect(items.length, equals(4));

      // Activar filtro F2P
      controller.setListF2pFilter(gameList.id, true);
      expect(controller.getListF2pFilter(gameList.id), isTrue);

      items = controller.getFilteredAndSortedItems(gameList.id);
      expect(items.length, equals(2));
      expect(items.map((i) => i.title), containsAll(['Fortnite', 'Genshin Impact']));
      expect(items.map((i) => i.title), isNot(contains('Cyberpunk 2077')));
      expect(items.map((i) => i.title), isNot(contains('Avatar')));

      // Desactivar filtro F2P
      controller.setListF2pFilter(gameList.id, false);
      items = controller.getFilteredAndSortedItems(gameList.id);
      expect(items.length, equals(4));

      // Comprobar que clearListFilters también limpia el filtro F2P
      controller.setListF2pFilter(gameList.id, true);
      expect(controller.getListF2pFilter(gameList.id), isTrue);
      controller.clearListFilters(gameList.id);
      expect(controller.getListF2pFilter(gameList.id), isFalse);
      expect(controller.getFilteredAndSortedItems(gameList.id).length, equals(4));
    });

    test('Fortnite and known F2P games appear in F2P filter even if isFreeToPlay is null or false and genres lack F2P tags', () async {
      final gameList = await controller.createSharedList('Lista F2P Especial', 'Test de resiliencia F2P');

      // Fortnite guardado con isFreeToPlay: null y géneros normales
      await controller.addMediaToSharedList(
        gameList.id,
        const LeisureMediaDetails(
          mediaId: '1905',
          mediaType: LeisureMediaType.game,
          title: 'Fortnite',
          isFreeToPlay: null,
          genres: ['Shooter', 'Battle Royale'],
        ),
      );

      // League of Legends con isFreeToPlay: false erróneo y sin tag F2P
      await controller.addMediaToSharedList(
        gameList.id,
        const LeisureMediaDetails(
          mediaId: '115',
          mediaType: LeisureMediaType.game,
          title: 'League of Legends',
          isFreeToPlay: false,
          genres: ['MOBA', 'Estrategia'],
        ),
      );

      // Juego de pago real
      await controller.addMediaToSharedList(
        gameList.id,
        const LeisureMediaDetails(
          mediaId: '119388',
          mediaType: LeisureMediaType.game,
          title: 'The Legend of Zelda: Tears of the Kingdom',
          isFreeToPlay: false,
          genres: ['Aventura'],
        ),
      );

      controller.setListF2pFilter(gameList.id, true);
      final items = controller.getFilteredAndSortedItems(gameList.id);

      expect(items.length, equals(2));
      expect(items.map((i) => i.title), containsAll(['Fortnite', 'League of Legends']));
      expect(items.map((i) => i.title), isNot(contains('The Legend of Zelda: Tears of the Kingdom')));
    });
  });
}
