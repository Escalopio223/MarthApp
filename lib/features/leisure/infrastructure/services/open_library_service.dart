import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/leisure_config.dart';
import '../../domain/models/book_edition_dto.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';

/// Servicio de integración con la API pública de Open Library.
/// Implementa deduplicación de obras mediante Work IDs (`/works/OL...W`),
/// parser polimórfico para descripciones, resolución canónica de portadas
/// y estrategia de resiliencia con fallback contra timeouts.
class OpenLibraryService {
  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  OpenLibraryService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? LeisureConfig.openLibraryBaseUrl;

  void dispose() {
    _client.close();
  }

  Map<String, String> get _headers {
    if (kIsWeb) return const {};
    return const {
      'User-Agent': 'MarthApp/1.0 (contact@marthapp.app)',
    };
  }

  /// Lista predeterminada y canónica de obras maestras y libros populares
  /// para garantizar resiliencia en caso de indisponibilidad o caída de los servidores de Open Library.
  static final List<LeisureMediaDetails> fallbackPopularBooks = [
    LeisureMediaDetails(
      mediaId: 'OL81626W',
      mediaType: LeisureMediaType.book,
      title: 'Carrie',
      creatorOrDirector: 'Stephen King',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/9256043-L.jpg',
      year: '1974',
      releaseDate: '1974',
      genres: const ['Terror', 'Ficción'],
      rating: 8.0,
      voteCount: 169,
    ),
    LeisureMediaDetails(
      mediaId: 'OL17930368W',
      mediaType: LeisureMediaType.book,
      title: 'Atomic Habits',
      creatorOrDirector: 'James Clear',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/12539702-L.jpg',
      year: '2016',
      releaseDate: '2016',
      genres: const ['Autoayuda', 'Psicología'],
      rating: 8.0,
      voteCount: 140,
    ),
    LeisureMediaDetails(
      mediaId: 'OL27479W',
      mediaType: LeisureMediaType.book,
      title: 'Cien años de soledad',
      creatorOrDirector: 'Gabriel García Márquez',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/8234567-L.jpg',
      year: '1967',
      releaseDate: '1967',
      genres: const ['Realismo mágico', 'Novela'],
      rating: 8.7,
      voteCount: 233,
    ),
    LeisureMediaDetails(
      mediaId: 'OL1168007W',
      mediaType: LeisureMediaType.book,
      title: '1984',
      creatorOrDirector: 'George Orwell',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/12648784-L.jpg',
      year: '1949',
      releaseDate: '1949',
      genres: const ['Distopía', 'Ciencia Ficción'],
      rating: 8.3,
      voteCount: 465,
    ),
    LeisureMediaDetails(
      mediaId: 'OL27448W',
      mediaType: LeisureMediaType.book,
      title: 'Don Quijote de la Mancha',
      creatorOrDirector: 'Miguel de Cervantes',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/12004245-L.jpg',
      year: '1605',
      releaseDate: '1605',
      genres: const ['Clásico', 'Aventura'],
      rating: 8.6,
      voteCount: 180,
    ),
    LeisureMediaDetails(
      mediaId: 'OL1188339W',
      mediaType: LeisureMediaType.book,
      title: 'El Principito',
      creatorOrDirector: 'Antoine de Saint-Exupéry',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/10521270-L.jpg',
      year: '1943',
      releaseDate: '1943',
      genres: const ['Fábula', 'Literatura infantil'],
      rating: 8.9,
      voteCount: 310,
    ),
    LeisureMediaDetails(
      mediaId: 'OL82563W',
      mediaType: LeisureMediaType.book,
      title: 'Harry Potter y la piedra filosofal',
      creatorOrDirector: 'J.K. Rowling',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/10522270-L.jpg',
      year: '1997',
      releaseDate: '1997',
      genres: const ['Fantasía', 'Aventura'],
      rating: 8.4,
      voteCount: 1028,
    ),
    LeisureMediaDetails(
      mediaId: 'OL893415W',
      mediaType: LeisureMediaType.book,
      title: 'Dune',
      creatorOrDirector: 'Frank Herbert',
      posterUrl: '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/11153218-L.jpg',
      year: '1965',
      releaseDate: '1965',
      genres: const ['Ciencia Ficción', 'Aventura'],
      rating: 8.6,
      voteCount: 290,
    ),
  ];

  /// Extrae un año limpio de 4 dígitos (1000-2099) de cualquier formato de fecha textual
  /// (p. ej. "October 14, 1999" -> "1999", "1974" -> "1974", "June 26, 1997" -> "1997").
  static String? extractYear(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return null;
    final match = RegExp(r'\b(1[0-9]{3}|20[0-2][0-9])\b').firstMatch(rawDate);
    return match?.group(0);
  }

  /// Parser polimórfico seguro para el campo `description` de Open Library.
  /// Open Library puede devolver la descripción como `String` directo
  /// o como objeto `{"type": "/type/text", "value": "..."}`.
  static String? parseDescription(dynamic rawDescription) {
    if (rawDescription == null) return null;
    if (rawDescription is String) return rawDescription.trim();
    if (rawDescription is Map && rawDescription['value'] != null) {
      return rawDescription['value'].toString().trim();
    }
    return rawDescription.toString().trim();
  }

  /// Busca libros agrupados canónicamente por obra
  Future<List<LeisureMediaDetails>> searchBooks(String query, {int limit = 20, int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/search.json').replace(queryParameters: {
      'q': query,
      'fields': 'key,title,author_name,cover_i,first_publish_year,ratings_average,ratings_count,subject,subtitle',
      'limit': limit.toString(),
      'page': page.toString(),
    });

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw HttpException('Error Open Library search (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (data['docs'] as List?) ?? [];

    return docs.map((doc) => _parseSearchDoc(doc as Map<String, dynamic>)).toList();
  }

  /// Obtiene los libros populares o destacados.
  /// Prioriza la búsqueda indexada de superventas (`search.json?q=bestseller`) que incluye
  /// calificaciones y años normalizados en menos de 1 segundo.
  /// Dispone de fallbacks a trending diario, materias y colección de contingencia.
  Future<List<LeisureMediaDetails>> getPopularBooks({int page = 1, int limit = 20}) async {
    // 1. Endpoint principal: Búsqueda de superventas y libros populares con ratings indexados
    try {
      final uri = Uri.parse('$_baseUrl/search.json').replace(queryParameters: {
        'q': 'bestseller',
        'limit': limit.toString(),
        'page': page.toString(),
        'fields': 'key,title,author_name,cover_i,first_publish_year,ratings_average,ratings_count,subject,subtitle',
      });
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (data['docs'] as List?) ?? [];
        if (docs.isNotEmpty) {
          return docs.map((doc) => _parseSearchDoc(doc as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {
      // Si falla o hay timeout en search, pasar a trending diario
    }

    // 2. Fallback: Trending diario de Open Library
    try {
      final uri = Uri.parse('$_baseUrl/trending/daily.json');
      final response = await _client.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final works = (data['works'] as List?) ?? [];
        if (works.isNotEmpty) {
          final startIndex = (page - 1) * limit;
          if (startIndex < works.length) {
            final pageItems = works.skip(startIndex).take(limit).toList();
            return pageItems.map((w) => _parseSearchDoc(w as Map<String, dynamic>)).toList();
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: Materia bestseller
    try {
      final offset = (page - 1) * limit;
      final uri = Uri.parse('$_baseUrl/subjects/bestseller.json').replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });
      final response = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final works = (data['works'] as List?) ?? [];
        if (works.isNotEmpty) {
          return works.map((w) => _parseSearchDoc(w as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    // 4. Fallback: Materia ficción
    try {
      final offset = (page - 1) * limit;
      final uri = Uri.parse('$_baseUrl/subjects/fiction.json').replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });
      final response = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final works = (data['works'] as List?) ?? [];
        if (works.isNotEmpty) {
          return works.map((w) => _parseSearchDoc(w as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    // 5. Contingencia segura: Devolver libros canónicos predeterminados
    return fallbackPopularBooks;
  }

  /// Obtiene los metadatos completos de una obra (`/works/{work_id}.json`)
  Future<LeisureMediaDetails> getWorkDetails(String workId) async {
    final cleanId = workId.startsWith('/works/') ? workId.replaceFirst('/works/', '') : workId;
    final uri = Uri.parse('$_baseUrl/works/$cleanId.json');

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw HttpException('Error Open Library work details ($workId): ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final title = json['title'] as String? ?? 'Sin título';
    final description = parseDescription(json['description']);

    // Extraer materias / géneros
    final subjectsRaw = json['subjects'] as List? ?? [];
    final subjects = subjectsRaw.take(6).map((s) => s.toString()).toList();

    // Extraer portada
    final covers = json['covers'] as List? ?? [];
    String? coverUrl;
    if (covers.isNotEmpty && (covers.first as num?)?.toInt() != null && (covers.first as int) > 0) {
      coverUrl = '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/${covers.first}-L.jpg';
    }

    // Consultar autor y ratings en paralelo para máxima velocidad
    final ratingsFuture = _fetchWorkRatings(cleanId);

    // Extraer autor principal si viene referenciado
    String? authorName;
    final authorsRaw = json['authors'] as List? ?? [];
    if (authorsRaw.isNotEmpty) {
      final authorEntry = authorsRaw.first;
      if (authorEntry is Map && authorEntry['author'] != null && authorEntry['author']['key'] != null) {
        authorName = await _fetchAuthorName(authorEntry['author']['key'].toString());
      }
    }

    // Normalizar año: extraer 4 dígitos o consultar primera edición si la obra carece de first_publish_date
    final rawDate = json['first_publish_date'] as String?;
    String? cleanYear = extractYear(rawDate);
    cleanYear ??= await _fetchFirstEditionYear(cleanId);

    final ratings = await ratingsFuture;

    return LeisureMediaDetails(
      mediaId: cleanId,
      mediaType: LeisureMediaType.book,
      title: title,
      overview: description,
      posterUrl: coverUrl,
      creatorOrDirector: authorName,
      genres: subjects,
      releaseDate: cleanYear ?? rawDate,
      year: cleanYear,
      rating: ratings.rating,
      voteCount: ratings.voteCount,
    );
  }

  /// Consulta las ediciones de una obra (`/works/{work_id}/editions.json`)
  Future<List<BookEditionDto>> getWorkEditions(String workId, {int limit = 25}) async {
    final cleanId = workId.startsWith('/works/') ? workId.replaceFirst('/works/', '') : workId;
    final uri = Uri.parse('$_baseUrl/works/$cleanId/editions.json').replace(queryParameters: {
      'limit': limit.toString(),
    });

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = (data['entries'] as List?) ?? [];

    return entries
        .map((entry) => BookEditionDto.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  // --- Helpers internos ---

  LeisureMediaDetails _parseSearchDoc(Map<String, dynamic> doc) {
    // La clave suele venir como "/works/OL12345W"
    final rawKey = doc['key'] as String? ?? '';
    final mediaId = rawKey.replaceFirst('/works/', '');

    final title = doc['title'] as String? ?? 'Libro';

    // Soporta tanto author_name (List<String>) como authors (List<Map>) de subjects
    final authorNames = <String>[];
    if (doc['author_name'] is List) {
      authorNames.addAll((doc['author_name'] as List).map((e) => e.toString()));
    } else if (doc['authors'] is List) {
      for (final a in doc['authors'] as List) {
        if (a is Map && a['name'] != null) {
          authorNames.add(a['name'].toString());
        }
      }
    }
    final primaryAuthor = authorNames.isNotEmpty ? authorNames.first : null;

    // Soporta cover_i (search/trending) y cover_id (subjects)
    final coverI = (doc['cover_i'] as num?)?.toInt() ?? (doc['cover_id'] as num?)?.toInt();
    final coverUrl = (coverI != null && coverI > 0)
        ? '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/$coverI-L.jpg'
        : null;

    final firstPublishYear = doc['first_publish_year']?.toString();
    final cleanYear = extractYear(firstPublishYear);
    // Escala Open Library 1-5 -> Normalizamos a 0-10 para homogeneidad con TMDB e IGDB
    final rawRating = (doc['ratings_average'] as num?)?.toDouble();
    final rating = rawRating != null
        ? double.parse((rawRating * 2.0).clamp(0.0, 10.0).toStringAsFixed(1))
        : null;
    final voteCount = (doc['ratings_count'] as num?)?.toInt();

    // Extraer subtítulo directo o desde editions si viene anidado
    String? subtitle = doc['subtitle'] as String?;
    if (subtitle == null && doc['editions'] is Map) {
      final editionsDocs = doc['editions']['docs'] as List?;
      if (editionsDocs != null && editionsDocs.isNotEmpty && editionsDocs.first is Map) {
        subtitle = editionsDocs.first['subtitle'] as String?;
      }
    }

    // Extraer materias / géneros
    final subjectsRaw = doc['subject'] ?? doc['subjects'];
    final subjects = (subjectsRaw is List)
        ? subjectsRaw.take(5).map((e) => e.toString()).toList()
        : <String>[];

    return LeisureMediaDetails(
      mediaId: mediaId,
      mediaType: LeisureMediaType.book,
      title: title,
      overview: subtitle,
      posterUrl: coverUrl,
      creatorOrDirector: primaryAuthor,
      genres: subjects,
      releaseDate: cleanYear ?? firstPublishYear,
      year: cleanYear ?? firstPublishYear,
      rating: rating,
      voteCount: voteCount,
      castOrPlatforms: authorNames,
    );
  }

  Future<String?> _fetchAuthorName(String authorKey) async {
    try {
      final cleanKey = authorKey.startsWith('/authors/') ? authorKey.replaceFirst('/authors/', '') : authorKey;
      final uri = Uri.parse('$_baseUrl/authors/$cleanKey.json');
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _fetchFirstEditionYear(String cleanId) async {
    try {
      final uri = Uri.parse('$_baseUrl/works/$cleanId/editions.json').replace(queryParameters: {'limit': '1'});
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final entries = (data['entries'] as List?) ?? [];
        if (entries.isNotEmpty && entries.first is Map) {
          final pubDate = entries.first['publish_date']?.toString();
          return extractYear(pubDate);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<({double? rating, int? voteCount})> _fetchWorkRatings(String cleanId) async {
    try {
      final uri = Uri.parse('$_baseUrl/works/$cleanId/ratings.json');
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final summary = data['summary'] as Map<String, dynamic>?;
        if (summary != null) {
          final avg = (summary['average'] as num?)?.toDouble();
          final count = (summary['count'] as num?)?.toInt();
          final normalized = avg != null
              ? double.parse((avg * 2.0).clamp(0.0, 10.0).toStringAsFixed(1))
              : null;
          return (rating: normalized, voteCount: count);
        }
      }
    } catch (_) {}
    return (rating: null, voteCount: null);
  }
}
