/// Configuración centralizada para el módulo de Ocio (Leisure) en MarthApp.
///
/// Contiene URLs base de proveedores multimedia (TMDB, Open Library, IGDB)
/// y variables de entorno compiladas con `--dart-define`.
class LeisureConfig {
  LeisureConfig._();

  /// API Key de The Movie Database (TMDB) v3.
  /// Puede pasarse en tiempo de compilación con:
  /// `--dart-define=TMDB_API_KEY=tu_clave`
  static const String tmdbApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: 'f93d39c5bb4f107f918e950839e995a9',
  );

  /// URL base oficial de la API de TMDB v3
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  /// URL base de las imágenes de TMDB (posters, backdrops, logos)
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';

  /// URL base de la API de Open Library
  static const String openLibraryBaseUrl = 'https://openlibrary.org';

  /// URL base del servicio de portadas de Open Library
  static const String openLibraryCoversBaseUrl = 'https://covers.openlibrary.org';

  /// URL base del CDN de imágenes oficiales de IGDB
  static const String igdbImageBaseUrl = 'https://images.igdb.com/igdb/image/upload';

  /// Validador para determinar si la clave de TMDB está configurada
  static bool get isTmdbConfigured =>
      tmdbApiKey.isNotEmpty && tmdbApiKey != 'YOUR_TMDB_API_KEY';

  /// Tiempo de vida estándar del cache de metadatos en Supabase (7 días)
  static const Duration cacheMaxAge = Duration(days: 7);
}
