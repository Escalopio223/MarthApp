/// Configuracion centralizada para el modulo de Ocio (Leisure) en MarthApp.
///
/// Contiene URLs base de proveedores multimedia (TMDB, Open Library, IGDB)
/// y variables de entorno compiladas con `--dart-define`.
class LeisureConfig {
  LeisureConfig._();

  /// API Key de The Movie Database (TMDB) v3.
  /// Puede pasarse en tiempo de compilacion con:
  /// `--dart-define=TMDB_API_KEY=tu_clave`
  static const String tmdbApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: 'ab51ce2f08248819ccbe5b3e4e521c90',
  );

  /// Twitch Client ID para IGDB API v4.
  /// Puede pasarse en tiempo de compilacion con:
  /// `--dart-define=TWITCH_CLIENT_ID=tu_client_id`
  static const String twitchClientId = String.fromEnvironment(
    'TWITCH_CLIENT_ID',
    defaultValue: '06vxc2a4ma48l5tx2ljffv90ubpph4',
  );

  /// Twitch Client Secret para IGDB API v4.
  /// Puede pasarse en tiempo de compilacion con:
  /// `--dart-define=TWITCH_CLIENT_SECRET=tu_client_secret`
  static const String twitchClientSecret = String.fromEnvironment(
    'TWITCH_CLIENT_SECRET',
    defaultValue: 'je5fksyagsq4tm9kdi2hiwsyjo7rl8',
  );

  /// URL base oficial de la API de TMDB v3
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  /// URL base de las imagenes de TMDB (posters, backdrops, logos)
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';

  /// URL base de la API de Open Library
  static const String openLibraryBaseUrl = 'https://openlibrary.org';

  /// URL base del servicio de portadas de Open Library
  static const String openLibraryCoversBaseUrl = 'https://covers.openlibrary.org';

  /// URL base del CDN de imagenes oficiales de IGDB
  static const String igdbImageBaseUrl = 'https://images.igdb.com/igdb/image/upload';

  /// API Key de RAWG Video Games Database (con soporte CORS nativo en navegadores)
  static const String rawgApiKey = String.fromEnvironment(
    'RAWG_API_KEY',
    defaultValue: 'c542e67aec3a4340908f9de9e86038af',
  );

  /// URL base oficial de la API de RAWG
  static const String rawgBaseUrl = 'https://api.rawg.io/api';

  /// Validador para determinar si la clave de TMDB esta configurada
  static bool get isTmdbConfigured =>
      tmdbApiKey.isNotEmpty && tmdbApiKey != 'YOUR_TMDB_API_KEY';

  /// Validador para determinar si las credenciales de IGDB estan configuradas
  static bool get isIgdbConfigured =>
      twitchClientId.isNotEmpty && twitchClientSecret.isNotEmpty;

  /// Tiempo de vida estandar del cache de metadatos en Supabase (7 dias)
  static const Duration cacheMaxAge = Duration(days: 7);
}
