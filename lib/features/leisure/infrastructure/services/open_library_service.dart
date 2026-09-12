import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/config/leisure_config.dart';
import '../../domain/models/book_edition_dto.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';

/// Servicio de integración con la API pública de Open Library.
/// Implementa deduplicación de obras mediante Work IDs (`/works/OL...W`),
/// parser polimórfico para descripciones y resolución canónica de portadas.
class OpenLibraryService {
  final http.Client _client;
  final String _baseUrl;

  OpenLibraryService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? LeisureConfig.openLibraryBaseUrl;

  void dispose() {
    _client.close();
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
      'limit': limit.toString(),
      'page': page.toString(),
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException('Error Open Library search (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (data['docs'] as List?) ?? [];

    return docs.map((doc) => _parseSearchDoc(doc as Map<String, dynamic>)).toList();
  }

  /// Obtiene los libros populares o destacados (búsqueda temática estándar)
  Future<List<LeisureMediaDetails>> getPopularBooks({int page = 1, int limit = 20}) async {
    // Consulta los libros más valorados/leídos usando trending o materias populares
    final uri = Uri.parse('$_baseUrl/search.json').replace(queryParameters: {
      'q': 'bestsellers OR classic OR fiction',
      'sort': 'rating desc',
      'limit': limit.toString(),
      'page': page.toString(),
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException('Error Open Library popular (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (data['docs'] as List?) ?? [];

    return docs.map((doc) => _parseSearchDoc(doc as Map<String, dynamic>)).toList();
  }

  /// Obtiene los metadatos completos de una obra (`/works/{work_id}.json`)
  Future<LeisureMediaDetails> getWorkDetails(String workId) async {
    final cleanId = workId.startsWith('/works/') ? workId.replaceFirst('/works/', '') : workId;
    final uri = Uri.parse('$_baseUrl/works/$cleanId.json');

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

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

    // Extraer autor principal si viene referenciado
    String? authorName;
    final authorsRaw = json['authors'] as List? ?? [];
    if (authorsRaw.isNotEmpty) {
      final authorEntry = authorsRaw.first;
      if (authorEntry is Map && authorEntry['author'] != null && authorEntry['author']['key'] != null) {
        authorName = await _fetchAuthorName(authorEntry['author']['key'].toString());
      }
    }

    return LeisureMediaDetails(
      mediaId: cleanId,
      mediaType: LeisureMediaType.book,
      title: title,
      overview: description,
      posterUrl: coverUrl,
      creatorOrDirector: authorName,
      genres: subjects,
      releaseDate: json['first_publish_date'] as String?,
      year: json['first_publish_date']?.toString(),
    );
  }

  /// Consulta las ediciones de una obra (`/works/{work_id}/editions.json`)
  Future<List<BookEditionDto>> getWorkEditions(String workId, {int limit = 25}) async {
    final cleanId = workId.startsWith('/works/') ? workId.replaceFirst('/works/', '') : workId;
    final uri = Uri.parse('$_baseUrl/works/$cleanId/editions.json').replace(queryParameters: {
      'limit': limit.toString(),
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

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
    final authorNames = (doc['author_name'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final primaryAuthor = authorNames.isNotEmpty ? authorNames.first : null;

    final coverI = (doc['cover_i'] as num?)?.toInt();
    final coverUrl = (coverI != null && coverI > 0)
        ? '${LeisureConfig.openLibraryCoversBaseUrl}/b/id/$coverI-L.jpg'
        : null;

    final firstPublishYear = doc['first_publish_year']?.toString();
    final rating = (doc['ratings_average'] as num?)?.toDouble();
    final voteCount = (doc['ratings_count'] as num?)?.toInt();

    final subjects = (doc['subject'] as List?)?.take(5).map((e) => e.toString()).toList() ?? [];

    return LeisureMediaDetails(
      mediaId: mediaId,
      mediaType: LeisureMediaType.book,
      title: title,
      overview: doc['subtitle'] as String?,
      posterUrl: coverUrl,
      creatorOrDirector: primaryAuthor,
      genres: subjects,
      releaseDate: firstPublishYear,
      year: firstPublishYear,
      rating: rating,
      voteCount: voteCount,
      castOrPlatforms: authorNames,
    );
  }

  Future<String?> _fetchAuthorName(String authorKey) async {
    try {
      final cleanKey = authorKey.startsWith('/authors/') ? authorKey.replaceFirst('/authors/', '') : authorKey;
      final uri = Uri.parse('$_baseUrl/authors/$cleanKey.json');
      final res = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['name'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
