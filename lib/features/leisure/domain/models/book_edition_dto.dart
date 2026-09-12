import 'package:flutter/foundation.dart';
import '../../../../core/config/leisure_config.dart';

/// DTO representativo de una edición física/digital específica de un libro
@immutable
class BookEditionDto {
  final String key;
  final String title;
  final List<String> publishers;
  final String? publishDate;
  final String? isbn10;
  final String? isbn13;
  final List<String> languages;
  final int? coverId;

  const BookEditionDto({
    required this.key,
    required this.title,
    this.publishers = const [],
    this.publishDate,
    this.isbn10,
    this.isbn13,
    this.languages = const [],
    this.coverId,
  });

  /// URL canónica de la portada de la edición
  String? get coverUrl => coverId != null && coverId! > 0
      ? '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/$coverId-L.jpg'
      : null;

  factory BookEditionDto.fromJson(Map<String, dynamic> json) {
    final rawPublishers = json['publishers'];
    final publishers = rawPublishers is List
        ? rawPublishers.map((e) => e.toString()).toList()
        : <String>[];

    final rawIsbn10 = json['isbn_10'];
    final isbn10 = rawIsbn10 is List && rawIsbn10.isNotEmpty
        ? rawIsbn10.first.toString()
        : (json['isbn_10'] as String?);

    final rawIsbn13 = json['isbn_13'];
    final isbn13 = rawIsbn13 is List && rawIsbn13.isNotEmpty
        ? rawIsbn13.first.toString()
        : (json['isbn_13'] as String?);

    final rawLanguages = json['languages'];
    final languages = rawLanguages is List
        ? rawLanguages.map((e) {
            if (e is Map && e['key'] != null) {
              return e['key'].toString().replaceFirst('/languages/', '');
            }
            return e.toString();
          }).toList()
        : <String>[];

    final rawCovers = json['covers'];
    final int? coverId = rawCovers is List && rawCovers.isNotEmpty
        ? (rawCovers.first as num?)?.toInt()
        : (json['cover_id'] as num?)?.toInt();

    return BookEditionDto(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? 'Edición',
      publishers: publishers,
      publishDate: json['publish_date'] as String?,
      isbn10: isbn10,
      isbn13: isbn13,
      languages: languages,
      coverId: coverId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'publishers': publishers,
      'publish_date': publishDate,
      'isbn_10': isbn10,
      'isbn_13': isbn13,
      'languages': languages,
      'cover_id': coverId,
    };
  }
}
