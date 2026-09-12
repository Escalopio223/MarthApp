import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/leisure/domain/models/book_edition_dto.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_environment_match_model.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_item_status.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_media_type.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_shared_list_item_model.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_shared_list_model.dart';
import 'package:marth_app/features/leisure/domain/models/leisure_user_item_model.dart';
import 'package:marth_app/features/leisure/domain/models/streaming_provider_dto.dart';
import 'package:marth_app/features/leisure/domain/models/tv_season_details_dto.dart';

void main() {
  group('LeisureMediaType Enum Tests', () {
    test('toValue and fromValue serialize and deserialize correctly', () {
      expect(LeisureMediaType.movie.toValue(), equals('movie'));
      expect(LeisureMediaType.tv.toValue(), equals('tv'));
      expect(LeisureMediaType.book.toValue(), equals('book'));
      expect(LeisureMediaType.game.toValue(), equals('game'));

      expect(LeisureMediaType.fromValue('movie'), equals(LeisureMediaType.movie));
      expect(LeisureMediaType.fromValue('tv'), equals(LeisureMediaType.tv));
      expect(LeisureMediaType.fromValue('series'), equals(LeisureMediaType.tv));
      expect(LeisureMediaType.fromValue('book'), equals(LeisureMediaType.book));
      expect(LeisureMediaType.fromValue('game'), equals(LeisureMediaType.game));
      expect(LeisureMediaType.fromValue('unknown'), equals(LeisureMediaType.movie));
    });

    test('UI labels are in Spanish', () {
      expect(LeisureMediaType.movie.label, equals('Película'));
      expect(LeisureMediaType.tv.label, equals('Serie'));
      expect(LeisureMediaType.book.label, equals('Libro'));
      expect(LeisureMediaType.game.label, equals('Videojuego'));
    });
  });

  group('LeisureItemStatus Enum Tests', () {
    test('toValue and fromValue work for all 4 states', () {
      expect(LeisureItemStatus.watched.toValue(), equals('watched'));
      expect(LeisureItemStatus.toWatch.toValue(), equals('to_watch'));
      expect(LeisureItemStatus.favorite.toValue(), equals('favorite'));
      expect(LeisureItemStatus.watching.toValue(), equals('watching'));

      expect(LeisureItemStatus.fromValue('watched'), equals(LeisureItemStatus.watched));
      expect(LeisureItemStatus.fromValue('to_watch'), equals(LeisureItemStatus.toWatch));
      expect(LeisureItemStatus.fromValue('favorite'), equals(LeisureItemStatus.favorite));
      expect(LeisureItemStatus.fromValue('watching'), equals(LeisureItemStatus.watching));
      expect(LeisureItemStatus.fromValue(null), isNull);
    });

    test('favorite computes internally as isWatched == true', () {
      expect(LeisureItemStatus.watched.isWatched, isTrue);
      expect(LeisureItemStatus.favorite.isWatched, isTrue);
      expect(LeisureItemStatus.toWatch.isWatched, isFalse);
      expect(LeisureItemStatus.watching.isWatched, isFalse);
    });
  });

  group('LeisureUserItemModel Tests', () {
    test('JSON deserialization converts int rating to double (tolerant parser)', () {
      final json = {
        'id': 'item-1',
        'user_id': 'user-123',
        'media_id': '101',
        'media_type': 'movie',
        'status': 'favorite',
        'rating': 9, // Entero procedente de JSON
        'notes': 'Película excelente',
        'disliked_until': null,
        'created_at': '2026-09-12T10:00:00Z',
        'updated_at': '2026-09-12T10:00:00Z',
      };

      final model = LeisureUserItemModel.fromJson(json);

      expect(model.id, equals('item-1'));
      expect(model.rating, equals(9.0));
      expect(model.isFavorite, isTrue);
      expect(model.isWatched, isTrue);
      expect(model.isDisliked, isFalse);
    });

    test('disliked_until future date sets isDisliked to true', () {
      final futureDate = DateTime.now().add(const Duration(days: 7));
      final model = LeisureUserItemModel(
        id: '1',
        userId: 'u1',
        mediaId: 'm1',
        mediaType: LeisureMediaType.game,
        dislikedUntil: futureDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(model.isDisliked, isTrue);

      final pastModel = model.copyWith(
        dislikedUntil: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(pastModel.isDisliked, isFalse);
    });

    test('JSON roundtrip serialization maintains integrity', () {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);
      final original = LeisureUserItemModel(
        id: 'uuid-1',
        userId: 'user-a',
        mediaId: 'media-55',
        mediaType: LeisureMediaType.tv,
        status: LeisureItemStatus.watching,
        rating: 8.5,
        notes: 'Voy por temporada 2',
        dislikedUntil: null,
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = LeisureUserItemModel.fromJson(json);

      expect(restored, equals(original));
      expect(restored.rating, equals(8.5));
      expect(restored.status, equals(LeisureItemStatus.watching));
    });
  });

  group('LeisureSharedListModel & Item Tests', () {
    test('LeisureSharedListModel deserializes and serializes with items count', () {
      final json = {
        'id': 'list-1',
        'environment_id': 'env-123',
        'created_by': 'user-1',
        'title': 'Cine de Verano',
        'description': 'Películas para ver en julio',
        'created_at': '2026-09-12T12:00:00Z',
        'items_count': 5,
      };

      final model = LeisureSharedListModel.fromJson(json);
      expect(model.title, equals('Cine de Verano'));
      expect(model.itemsCount, equals(5));

      final outputJson = model.toJson();
      expect(outputJson['environment_id'], equals('env-123'));
    });

    test('LeisureSharedListItemModel roundtrip and copyWith', () {
      final item = LeisureSharedListItemModel(
        id: 'item-99',
        listId: 'list-1',
        mediaId: 'movie-500',
        mediaType: LeisureMediaType.movie,
        title: 'El Viaje de Chihiro',
        posterUrl: 'https://image.tmdb.org/t/p/w500/chihiro.jpg',
        addedBy: 'user-1',
        createdAt: DateTime.now(),
      );

      final json = item.toJson();
      final fromJson = LeisureSharedListItemModel.fromJson(json);

      expect(fromJson.title, equals('El Viaje de Chihiro'));
      expect(fromJson.mediaType, equals(LeisureMediaType.movie));
      expect(fromJson.posterUrl, isNotNull);
    });
  });

  group('LeisureEnvironmentMatchModel Tests', () {
    test('JSON parser handles matched_user_ids list cleanly', () {
      final json = {
        'id': 'match-1',
        'environment_id': 'env-abc',
        'media_id': 'game-999',
        'media_type': 'game',
        'title': 'Elden Ring',
        'matched_user_ids': ['user-1', 'user-2', 'user-3'],
        'created_at': '2026-09-12T12:00:00Z',
      };

      final match = LeisureEnvironmentMatchModel.fromJson(json);
      expect(match.matchedUserIds.length, equals(3));
      expect(match.matchedUserIds, contains('user-2'));
      expect(match.title, equals('Elden Ring'));
    });
  });

  group('DTOs Tests', () {
    test('StreamingProviderDto constructs canonical logoUrl', () {
      final dto = StreamingProviderDto(
        providerId: 8,
        providerName: 'Netflix',
        logoPath: '/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg',
      );

      expect(dto.logoUrl, startsWith('https://image.tmdb.org/t/p/original/'));
      expect(dto.logoUrl, endsWith('.jpg'));
    });

    test('TvSeasonDetailsDto and TvEpisodeDto parse nested JSON', () {
      final json = {
        'id': 1234,
        'season_number': 1,
        'name': 'Temporada 1',
        'episodes': [
          {
            'id': 101,
            'episode_number': 1,
            'season_number': 1,
            'name': 'Piloto',
            'vote_average': 8.7,
            'still_path': '/still1.jpg',
          },
        ],
      };

      final season = TvSeasonDetailsDto.fromJson(json, seriesId: 'breaking-bad');
      expect(season.seriesId, equals('breaking-bad'));
      expect(season.episodes.length, equals(1));
      expect(season.episodes.first.name, equals('Piloto'));
      expect(season.episodes.first.stillUrl, startsWith('https://image.tmdb.org/t/p/w500/'));
    });

    test('BookEditionDto parses Open Library formats', () {
      final json = {
        'key': '/books/OL123M',
        'title': 'Cien Años de Soledad',
        'publishers': ['Sudamericana'],
        'publish_date': '1967',
        'isbn_10': ['0307474720'],
        'languages': [
          {'key': '/languages/spa'}
        ],
        'covers': [8234567],
      };

      final edition = BookEditionDto.fromJson(json);
      expect(edition.title, equals('Cien Años de Soledad'));
      expect(edition.publishers, contains('Sudamericana'));
      expect(edition.languages, contains('spa'));
      expect(edition.coverUrl, equals('https://covers.openlibrary.org/b/id/8234567-L.jpg'));
    });
  });
}
