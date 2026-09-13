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
      expect(providers.last.providerName, equals('Disney Plus'));
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
      expect(books.first.rating, equals(4.35));
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
      expect(gta.creatorOrDirector, equals('Rockstar North'));
      expect(gta.genres, contains('Shooter'));
      expect(gta.castOrPlatforms, contains('PC (Microsoft Windows)'));
      expect(gta.rating, equals(9.7));
    });
  });
}
