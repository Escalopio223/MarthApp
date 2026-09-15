import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marth_app/features/leisure/domain/models/leisure_media_type.dart';
import 'package:marth_app/features/leisure/infrastructure/services/open_library_service.dart';
import 'package:marth_app/features/leisure/infrastructure/services/tmdb_service.dart';
import 'package:marth_app/core/config/leisure_config.dart';
import 'package:marth_app/features/leisure/infrastructure/services/igdb_service.dart';

/// Cliente HTTP Mock sin dependencias externas adicionales
class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) _handler;

  MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request as http.Request);
    final bytes = utf8.encode(response.body);
    final headers = {
      'content-type': 'application/json; charset=utf-8',
      ...response.headers,
    };
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: headers,
    );
  }
}

void main() {
  group('TmdbService Tests with Mock HTTP Client', () {
    test('getNowPlayingMovies returns parsed movies in Spain', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/movie/now_playing'));
        expect(request.url.queryParameters['region'], equals('ES'));

        return http.Response(
          jsonEncode({
            'page': 1,
            'results': [
              {
                'id': 550,
                'title': 'El Club de la Lucha',
                'overview': 'Un oficinista insomne...',
                'poster_path': '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
                'backdrop_path': '/hZkgoQYus5vegHoetLkCJzb17zJ.jpg',
                'release_date': '1999-10-15',
                'vote_average': 8.4,
                'vote_count': 26000,
              }
            ],
          }),
          200,
        );
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_key');
      final movies = await service.getNowPlayingMovies();

      expect(movies.length, equals(1));
      expect(movies.first.mediaId, equals('550'));
      expect(movies.first.title, equals('El Club de la Lucha'));
      expect(movies.first.year, equals('1999'));
      expect(movies.first.mediaType, equals(LeisureMediaType.movie));
      expect(movies.first.posterUrl, contains('pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg'));
    });

    test('getMediaDetails extracts director, cast and genres', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/movie/550'));
        expect(request.url.queryParameters['append_to_response'], equals('credits'));

        return http.Response(
          jsonEncode({
            'id': 550,
            'title': 'Fight Club',
            'overview': 'A ticking-time-bomb insomniac...',
            'release_date': '1999-10-15',
            'vote_average': 8.43,
            'vote_count': 26000,
            'genres': [
              {'id': 18, 'name': 'Drama'},
              {'id': 53, 'name': 'Thriller'},
            ],
            'credits': {
              'cast': [
                {'name': 'Edward Norton'},
                {'name': 'Brad Pitt'},
                {'name': 'Helena Bonham Carter'},
              ],
              'crew': [
                {'name': 'David Fincher', 'job': 'Director'},
                {'name': 'Art Linson', 'job': 'Producer'},
              ],
            },
          }),
          200,
        );
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_key');
      final details = await service.getMediaDetails(
        mediaId: '550',
        type: LeisureMediaType.movie,
      );

      expect(details.title, equals('Fight Club'));
      expect(details.creatorOrDirector, equals('David Fincher'));
      expect(details.genres, contains('Drama'));
      expect(details.genres, contains('Thriller'));
      expect(details.castOrPlatforms, contains('Brad Pitt'));
      expect(details.castOrPlatforms, contains('Edward Norton'));
    });

    test('getWatchProviders filters results.ES.flatrate correctly', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/movie/550/watch/providers'));

        return http.Response(
          jsonEncode({
            'id': 550,
            'results': {
              'US': {
                'flatrate': [
                  {
                    'provider_id': 9,
                    'provider_name': 'Amazon Prime Video',
                    'logo_path': '/emthp39XA2zhcoYL323Vio0DYGW.jpg',
                    'display_priority': 1,
                  }
                ]
              },
              'ES': {
                'flatrate': [
                  {
                    'provider_id': 8,
                    'provider_name': 'Netflix',
                    'logo_path': '/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg',
                    'display_priority': 0,
                  },
                  {
                    'provider_id': 337,
                    'provider_name': 'Disney Plus',
                    'logo_path': '/7rwgEs55tOXyYDu8WuNX1Y9qJAc.jpg',
                    'display_priority': 2,
                  }
                ]
              }
            }
          }),
          200,
        );
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_key');
      final providers = await service.getWatchProviders(
        mediaId: '550',
        type: LeisureMediaType.movie,
      );

      expect(providers.length, equals(2));
      expect(providers.first.providerName, equals('Netflix'));
      expect(providers.first.logoUrl, contains('t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg'));
      expect(providers.first.type, equals('flatrate'));
      expect(providers.last.providerName, equals('Disney Plus'));
    });

    test('getWatchProviders handles US region, Hulu and direct watchLink', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/tv/1234/watch/providers'));

        return http.Response(
          jsonEncode({
            'id': 1234,
            'results': {
              'US': {
                'link': 'https://www.themoviedb.org/tv/1234/watch?locale=en-US',
                'flatrate': [
                  {
                    'provider_id': 15,
                    'provider_name': 'Hulu',
                    'logo_path': '/zxrVdFjIjLqkfnwyghn2WZhGD3d.jpg',
                    'display_priority': 1,
                  }
                ],
                'free': [
                  {
                    'provider_id': 300,
                    'provider_name': 'Pluto TV',
                    'logo_path': '/pluto.jpg',
                    'display_priority': 5,
                  }
                ]
              }
            }
          }),
          200,
        );
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_key');
      final providers = await service.getWatchProviders(
        mediaId: '1234',
        type: LeisureMediaType.tv,
        region: 'US',
      );

      expect(providers.length, equals(2));
      expect(providers.first.providerName, equals('Hulu'));
      expect(providers.first.type, equals('flatrate'));
      expect(providers.first.watchLink, contains('themoviedb.org'));
      expect(providers.last.providerName, equals('Pluto TV'));
      expect(providers.last.type, equals('free'));
      expect(providers.last.typeLabel, equals('Gratuito'));
    });

    test('getMediaByProvider queries discover endpoint with watch providers', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/discover/movie'));
        expect(request.url.queryParameters['with_watch_providers'], equals('8')); // Netflix
        expect(request.url.queryParameters['watch_region'], equals('ES'));

        return http.Response(
          jsonEncode({
            'page': 1,
            'results': [
              {
                'id': 999,
                'title': 'Película de Netflix',
                'overview': 'Exclusiva en Netflix',
                'poster_path': '/netflix_movie.jpg',
                'release_date': '2024-01-01',
                'vote_average': 8.0,
                'vote_count': 500,
              }
            ]
          }),
          200,
        );
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_key');
      final items = await service.getMediaByProvider(
        type: LeisureMediaType.movie,
        providerId: 8,
        region: 'ES',
      );

      expect(items.length, equals(1));
      expect(items.first.title, equals('Película de Netflix'));
      expect(items.first.watchProviders.length, equals(1));
      expect(items.first.watchProviders.first.providerName, equals('Netflix'));
      expect(items.first.watchProviders.first.providerId, equals(8));
    });

    test('getTvSeasonsAndEpisodes parses season breakdown', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/tv/1399/season/1'));

        return http.Response(
          jsonEncode({
            'id': 3624,
            'season_number': 1,
            'name': 'Temporada 1',
            'overview': 'Comienza el juego de tronos...',
            'episodes': [
              {
                'id': 63056,
                'episode_number': 1,
                'season_number': 1,
                'name': 'Se acerca el invierno',
                'overview': 'Ned Stark es contactado...',
                'vote_average': 8.9,
              },
              {
                'id': 63057,
                'episode_number': 2,
                'season_number': 1,
                'name': 'El camino real',
                'overview': 'Bran sobrevive a la caída...',
                'vote_average': 8.8,
              },
            ]
          }),
          200,
        );
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_key');
      final season = await service.getTvSeasonsAndEpisodes(
        seriesId: '1399',
        seasonNumber: 1,
      );

      expect(season.seasonNumber, equals(1));
      expect(season.episodes.length, equals(2));
      expect(season.episodes.first.name, equals('Se acerca el invierno'));
      expect(season.episodes.first.voteAverage, equals(8.9));
    });

    test('HTTP error throws HttpException', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_key');

      expect(
        () => service.getNowPlayingMovies(),
        throwsA(isA<HttpException>()),
      );
    });
  });

  group('OpenLibraryService Tests', () {
    test('parseDescription handles plain String and Map polymorphic formats', () {
      expect(OpenLibraryService.parseDescription('Descripción plana'), equals('Descripción plana'));
      expect(
        OpenLibraryService.parseDescription({
          'type': '/type/text',
          'value': '  Descripción dentro de objeto  ',
        }),
        equals('Descripción dentro de objeto'),
      );
      expect(OpenLibraryService.parseDescription(null), isNull);
    });

    test('extractYear parses 4-digit years from various unstructured date strings', () {
      expect(OpenLibraryService.extractYear('1974'), equals('1974'));
      expect(OpenLibraryService.extractYear('October 14, 1999'), equals('1999'));
      expect(OpenLibraryService.extractYear('June 26, 1997'), equals('1997'));
      expect(OpenLibraryService.extractYear('May 1967'), equals('1967'));
      expect(OpenLibraryService.extractYear('1605'), equals('1605'));
      expect(OpenLibraryService.extractYear('c. 1943'), equals('1943'));
      expect(OpenLibraryService.extractYear(null), isNull);
      expect(OpenLibraryService.extractYear(''), isNull);
      expect(OpenLibraryService.extractYear('Sin fecha'), isNull);
    });

    test('searchBooks parses works, author and canonical cover ID', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/search.json'));
        expect(request.url.queryParameters['q'], equals('Cien años de soledad'));

        return http.Response(
          jsonEncode({
            'numFound': 1,
            'docs': [
              {
                'key': '/works/OL27479W',
                'title': 'Cien años de soledad',
                'author_name': ['Gabriel García Márquez'],
                'first_publish_year': 1967,
                'cover_i': 8234567,
                'ratings_average': 4.35,
                'ratings_count': 1250,
                'subject': ['Realismo mágico', 'Literatura latinoamericana'],
              }
            ]
          }),
          200,
        );
      });

      final service = OpenLibraryService(client: mockClient);
      final books = await service.searchBooks('Cien años de soledad');

      expect(books.length, equals(1));
      expect(books.first.mediaId, equals('OL27479W'));
      expect(books.first.title, equals('Cien años de soledad'));
      expect(books.first.creatorOrDirector, equals('Gabriel García Márquez'));
      expect(books.first.posterUrl, equals('https://covers.openlibrary.org/b/id/8234567-L.jpg'));
      expect(books.first.rating, equals(8.7));
    });

    test('getWorkDetails handles description map and subject tags', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.path.contains('/works/OL27479W.json')) {
          return http.Response(
            jsonEncode({
              'key': '/works/OL27479W',
              'title': 'Cien años de soledad',
              'description': {
                'type': '/type/text',
                'value': 'Historia de la familia Buendía en Macondo.',
              },
              'covers': [8234567],
              'subjects': ['Novela', 'Ficción histórica'],
              'first_publish_date': '1967',
              'authors': [
                {
                  'author': {'key': '/authors/OL21594A'}
                }
              ]
            }),
            200,
          );
        } else if (request.url.path.contains('/authors/OL21594A.json')) {
          return http.Response(
            jsonEncode({
              'name': 'Gabriel García Márquez',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = OpenLibraryService(client: mockClient);
      final details = await service.getWorkDetails('OL27479W');

      expect(details.title, equals('Cien años de soledad'));
      expect(details.overview, equals('Historia de la familia Buendía en Macondo.'));
      expect(details.creatorOrDirector, equals('Gabriel García Márquez'));
      expect(details.posterUrl, contains('8234567-L.jpg'));
      expect(details.genres, contains('Novela'));
    });

    test('getWorkEditions parses editions array with publishers and ISBN', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.path, contains('/works/OL27479W/editions.json'));

        return http.Response(
          jsonEncode({
            'entries': [
              {
                'key': '/books/OL1000M',
                'title': 'Cien años de soledad (Edición 50 Aniversario)',
                'publishers': ['Penguin Random House'],
                'publish_date': '2017',
                'isbn_13': ['9780307474728'],
                'covers': [99999],
              }
            ]
          }),
          200,
        );
      });

      final service = OpenLibraryService(client: mockClient);
      final editions = await service.getWorkEditions('OL27479W');

      expect(editions.length, equals(1));
      expect(editions.first.title, contains('50 Aniversario'));
      expect(editions.first.publishers, contains('Penguin Random House'));
      expect(editions.first.isbn13, equals('9780307474728'));
      expect(editions.first.coverUrl, contains('99999-L.jpg'));
    });

    test('getPopularBooks returns trending works when endpoint succeeds', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.path.contains('/trending/daily.json')) {
          return http.Response(
            jsonEncode({
              'works': [
                {
                  'key': '/works/OL17930368W',
                  'title': 'Atomic Habits',
                  'author_name': ['James Clear'],
                  'cover_i': 12539702,
                  'first_publish_year': 2016,
                  'ratings_average': 4.7,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = OpenLibraryService(client: mockClient);
      final books = await service.getPopularBooks();

      expect(books.length, equals(1));
      expect(books.first.title, equals('Atomic Habits'));
      expect(books.first.creatorOrDirector, equals('James Clear'));
      expect(books.first.posterUrl, contains('12539702-L.jpg'));
    });

    test('getPopularBooks falls back to subjects/bestseller when trending fails', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.path.contains('/trending/daily.json')) {
          return http.Response('Internal Server Error', 500);
        }
        if (request.url.path.contains('/subjects/bestseller.json')) {
          return http.Response(
            jsonEncode({
              'works': [
                {
                  'key': '/works/OL15719630W',
                  'title': 'Divergent',
                  'authors': [
                    {'name': 'Veronica Roth', 'key': '/authors/OL6895646A'}
                  ],
                  'cover_id': 13274634,
                  'first_publish_year': 2010,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = OpenLibraryService(client: mockClient);
      final books = await service.getPopularBooks();

      expect(books.length, equals(1));
      expect(books.first.title, equals('Divergent'));
      expect(books.first.creatorOrDirector, equals('Veronica Roth'));
      expect(books.first.posterUrl, contains('13274634-L.jpg'));
    });

    test('getPopularBooks falls back to canonical fallbackPopularBooks when all endpoints fail', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response('Network Error', 500);
      });

      final service = OpenLibraryService(client: mockClient);
      final books = await service.getPopularBooks();

      expect(books.isNotEmpty, isTrue);
      expect(books.length, equals(OpenLibraryService.fallbackPopularBooks.length));
      expect(books.first.title, equals('Carrie'));
    });
  });

  group('LeisureConfig Credentials Tests', () {
    test('Credentials for TMDB and Twitch are configured', () {
      expect(LeisureConfig.isTmdbConfigured, isTrue);
      expect(LeisureConfig.isIgdbConfigured, isTrue);
      expect(LeisureConfig.tmdbApiKey, equals('ab51ce2f08248819ccbe5b3e4e521c90'));
      expect(LeisureConfig.twitchClientId, equals('06vxc2a4ma48l5tx2ljffv90ubpph4'));
      expect(LeisureConfig.twitchClientSecret, equals('je5fksyagsq4tm9kdi2hiwsyjo7rl8'));
    });
  });

  group('IgdbService Tests with Mock HTTP Client', () {
    test('buildImageUrl formats proper CDN URL', () {
      final url = IgdbService.buildImageUrl('co1r0c', size: 't_cover_big');
      expect(url, equals('https://images.igdb.com/igdb/image/upload/t_cover_big/co1r0c.jpg'));
    });

    test('getPopularGames parses game list using OAuth2 and IGDB API', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.host == 'id.twitch.tv') {
          return http.Response(
            jsonEncode({
              'access_token': 'mock_token_abc',
              'expires_in': 3600,
              'token_type': 'bearer',
            }),
            200,
          );
        }

        if (request.url.host == 'api.igdb.com') {
          expect(request.headers['Client-ID'], equals(LeisureConfig.twitchClientId));
          expect(request.headers['Authorization'], equals('Bearer mock_token_abc'));

          return http.Response(
            jsonEncode([
              {
                'id': 1020,
                'name': 'Grand Theft Auto V',
                'summary': 'When a young street hustler...',
                'cover': {'id': 1, 'image_id': 'co1r0c'},
                'first_release_date': 1379376000,
                'total_rating': 96.5,
                'genres': [
                  {'id': 1, 'name': 'Shooter'},
                  {'id': 2, 'name': 'Adventure'}
                ],
                'platforms': [
                  {'id': 6, 'name': 'PC (Microsoft Windows)'}
                ],
                'involved_companies': [
                  {
                    'developer': true,
                    'company': {'id': 1, 'name': 'Rockstar North'}
                  }
                ],
                'screenshots': [
                  {'id': 10, 'image_id': 'sc123'}
                ]
              }
            ]),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = IgdbService(httpClient: mockClient);
      final games = await service.getPopularGames(limit: 10);

      expect(games.length, equals(1));
      final gta = games.first;
      expect(gta.mediaId, equals('1020'));
      expect(gta.mediaType, equals(LeisureMediaType.game));
      expect(gta.title, equals('Grand Theft Auto V'));
      expect(gta.overview, contains('young street hustler'));
      expect(gta.posterUrl, contains('co1r0c.jpg'));
      expect(gta.backdropUrl, contains('sc123.jpg'));
      expect(gta.rating, equals(9.7));
    });

    test('getPopularGames and searchGames fall back to canonical fallbackPopularGames when network/CORS fails', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response('CORS Error', 500);
      });

      final service = IgdbService(httpClient: mockClient);
      final games = await service.getPopularGames();

      expect(games.isNotEmpty, isTrue);
      expect(games.length, equals(IgdbService.fallbackPopularGames.length));
      expect(games.first.title, equals('The Witcher 3: Wild Hunt'));

      // Búsqueda en el fallback
      final searchResults = await service.searchGames('Zelda');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.title, contains('Zelda'));
    });

    test('IgdbService parses Free to Play game and extracts official stores', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.host == 'id.twitch.tv') {
          return http.Response(jsonEncode({'access_token': 'tok_1', 'expires_in': 3600}), 200);
        }
        return http.Response(
          jsonEncode([
            {
              'id': 1905,
              'name': 'Fortnite',
              'summary': 'Battle royale game...',
              'keywords': [
                {'id': 2385, 'name': 'free-to-play', 'slug': 'free-to-play'},
                {'id': 100, 'name': 'shooter', 'slug': 'shooter'},
              ],
              'websites': [
                {'url': 'https://store.epicgames.com/p/fortnite'},
                {'url': 'https://store.playstation.com/concept/228748'},
                {'url': 'https://www.youtube.com/@fortnite'},
                {'url': 'https://discord.gg/fortnite'},
              ],
            }
          ]),
          200,
        );
      });

      final service = IgdbService(httpClient: mockClient);
      final details = await service.getGameDetails('1905');

      expect(details.title, equals('Fortnite'));
      expect(details.isFreeToPlay, isTrue);
      // Youtube and Discord are filtered out, only official stores remain
      expect(details.gameStores.length, equals(2));
      expect(details.gameStores.map((s) => s.storeName), containsAll(['Epic Games Store', 'PlayStation Store']));
    });

    test('IgdbService parses Paid game with commercial store links as isFreeToPlay == false', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.host == 'id.twitch.tv') {
          return http.Response(jsonEncode({'access_token': 'tok_1', 'expires_in': 3600}), 200);
        }
        return http.Response(
          jsonEncode([
            {
              'id': 119177,
              'name': 'The Legend of Zelda: Tears of the Kingdom',
              'keywords': [
                {'id': 1, 'name': 'action-adventure'},
              ],
              'websites': [
                {'url': 'https://www.nintendo.com/store/products/the-legend-of-zelda-tears-of-the-kingdom-switch/'},
              ],
            }
          ]),
          200,
        );
      });

      final service = IgdbService(httpClient: mockClient);
      final details = await service.getGameDetails('119177');

      expect(details.isFreeToPlay, isFalse);
      expect(details.gameStores.length, equals(1));
      expect(details.gameStores.first.storeName, equals('Nintendo eShop'));
    });

    test('IgdbService returns isFreeToPlay == null when neither F2P keywords nor stores exist', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.host == 'id.twitch.tv') {
          return http.Response(jsonEncode({'access_token': 'tok_1', 'expires_in': 3600}), 200);
        }
        return http.Response(
          jsonEncode([
            {
              'id': 99999,
              'name': 'Indie Game Without Store Info',
              'keywords': [],
              'websites': [
                {'url': 'https://twitter.com/indiedev'},
              ],
            }
          ]),
          200,
        );
      });

      final service = IgdbService(httpClient: mockClient);
      final details = await service.getGameDetails('99999');

      expect(details.isFreeToPlay, isNull);
      expect(details.gameStores, isEmpty);
    });

    test('fallbackPopularGames contains verified official covers for GTA V, Fortnite, Zelda TotK and LoL', () {
      final games = IgdbService.fallbackPopularGames;

      final gta = games.firstWhere((g) => g.title == 'Grand Theft Auto V');
      expect(gta.posterUrl, contains('co2lbd.jpg')); // Official GTA V cover (not Star Renegades)
      expect(gta.isFreeToPlay, isFalse);

      final fortnite = games.firstWhere((g) => g.title == 'Fortnite');
      expect(fortnite.posterUrl, contains('cocqrm.jpg')); // Official Fortnite Battle Royale cover (not Car Rental Simulator)
      expect(fortnite.isFreeToPlay, isTrue);

      final zelda = games.firstWhere((g) => g.title == 'The Legend of Zelda: Tears of the Kingdom');
      expect(zelda.posterUrl, contains('co5vmg.jpg')); // Official Tears of the Kingdom cover
      expect(zelda.isFreeToPlay, isFalse);

      final lol = games.firstWhere((g) => g.title == 'League of Legends');
      expect(lol.posterUrl, contains('coc99o.jpg')); // Official League of Legends cover
      expect(lol.isFreeToPlay, isTrue);
    });

    test('searchGames finds League of Legends and returns correct metadata when network fails', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response('Network Error', 500);
      });

      final service = IgdbService(httpClient: mockClient);
      final results = await service.searchGames('League of Legends');

      expect(results.isNotEmpty, isTrue);
      final match = results.firstWhere((g) => g.title == 'League of Legends');
      expect(match.isFreeToPlay, isTrue);
      expect(match.posterUrl, contains('coc99o.jpg'));
    });

    test('searchGames integrates FreeToGame API when local match is not found', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.host == 'www.freetogame.com') {
          return http.Response(
            jsonEncode([
              {
                'id': 999,
                'title': 'Test Free Space MMO',
                'short_description': 'A space combat MMO',
                'thumbnail': 'https://freetogame.com/thumb.jpg',
                'game_url': 'https://store.steampowered.com/app/999999',
                'genre': 'MMO',
                'platform': 'PC',
                'release_date': '2024-01-01',
              }
            ]),
            200,
          );
        }
        return http.Response('CORS Error', 500);
      });

      final service = IgdbService(httpClient: mockClient);
      final results = await service.searchGames('Test Free Space MMO');

      expect(results.isNotEmpty, isTrue);
      expect(results.first.title, equals('Test Free Space MMO'));
      expect(results.first.isFreeToPlay, isTrue);
      expect(results.first.gameStores.first.storeName, equals('Steam'));
    });

    test('searchGames and getGameDetails find Moonlighter and return stores via RAWG fallback', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.host == 'api.rawg.io') {
          if (request.url.path.contains('/games/22162')) {
            return http.Response(
              jsonEncode({
                'id': 22162,
                'name': 'Moonlighter',
                'description_raw': 'During an archeological excavation – a set of Gates were discovered.',
                'released': '2018-05-28',
                'background_image': 'https://media.rawg.io/moonlighter.jpg',
                'metacritic': 74,
                'playtime': 14,
                'developers': [{'name': 'Digital Sun'}],
                'genres': [{'name': 'Indie'}, {'name': 'Action'}],
                'platforms': [{'platform': {'name': 'Nintendo Switch'}}, {'platform': {'name': 'PC'}}],
                'stores': [
                  {'store': {'name': 'Steam'}, 'url': 'https://store.steampowered.com/app/606150/'},
                  {'store': {'name': 'Nintendo Store'}, 'url': 'https://www.nintendo.com/games/detail/moonlighter-switch'},
                ],
                'tags': [{'name': 'Singleplayer'}],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (request.url.path.contains('/games')) {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 22162,
                    'name': 'Moonlighter',
                    'released': '2018-05-28',
                    'background_image': 'https://media.rawg.io/moonlighter.jpg',
                    'metacritic': 74,
                    'playtime': 14,
                    'genres': [{'name': 'Indie'}, {'name': 'Action'}],
                    'platforms': [{'platform': {'name': 'Nintendo Switch'}}, {'platform': {'name': 'PC'}}],
                    'stores': [
                      {'store': {'name': 'Steam'}, 'url': 'https://store.steampowered.com/app/606150/'},
                      {'store': {'name': 'Nintendo Store'}, 'url': 'https://www.nintendo.com/games/detail/moonlighter-switch'},
                    ],
                    'tags': [{'name': 'Singleplayer'}],
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
        }
        return http.Response('CORS Error', 500);
      });

      final service = IgdbService(httpClient: mockClient);
      final searchResults = await service.searchGames('Moonlighter');

      expect(searchResults.isNotEmpty, isTrue);
      final moonlighter = searchResults.first;
      expect(moonlighter.title, equals('Moonlighter'));
      expect(moonlighter.mediaId, equals('rawg_22162'));
      expect(moonlighter.isFreeToPlay, isFalse);
      expect(moonlighter.posterUrl, equals('https://media.rawg.io/moonlighter.jpg'));
      expect(moonlighter.gameStores.map((s) => s.storeName), containsAll(['Steam', 'Nintendo eShop']));
      expect(moonlighter.gameDuration?.mainStoryHours, equals(14));

      // Test full details
      final details = await service.getGameDetails('rawg_22162');
      expect(details.title, equals('Moonlighter'));
      expect(details.creatorOrDirector, equals('Digital Sun'));
      expect(details.overview, contains('archeological excavation'));
      expect(details.isFreeToPlay, isFalse);
      expect(details.gameDuration?.mainStoryHours, equals(14));
      expect(details.gameDuration?.mainExtraHours, equals(22)); // (14 * 1.6).round()
      expect(details.gameDuration?.completionistHours, equals(35)); // (14 * 2.5).round()

      // Test fallbackPopularGames duration (The Witcher 3)
      final witcher = IgdbService.fallbackPopularGames.first;
      expect(witcher.gameDuration, isNotNull);
      expect(witcher.gameDuration?.mainStoryHours, equals(52));
      expect(witcher.gameDuration?.mainExtraHours, equals(103));
      expect(witcher.gameDuration?.completionistHours, equals(173));
    });
  });
}
