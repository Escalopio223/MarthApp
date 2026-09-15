import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/leisure_config.dart';
import '../../domain/models/game_duration_dto.dart';
import '../../domain/models/game_store_dto.dart';
import '../../domain/models/leisure_game_f2p_helper.dart';
import '../../domain/models/leisure_media_details.dart';
import '../../domain/models/leisure_media_type.dart';

/// Servicio de integración unificado para Videojuegos:
/// - Soporta IGDB v4 oficial (via Supabase Edge Function `igdb-proxy` o OAuth2 Twitch).
/// - Integra RAWG Video Games Database (+800.000 títulos) con CORS nativo habilitado en Web.
/// - Ofrece una colección curada y contrastada de títulos destacados con carátulas verificadas.
/// - Integra búsqueda complementaria con la API abierta de FreeToGame para títulos gratuitos.
class IgdbService {
  final FunctionsClient? _functions;
  final http.Client _httpClient;

  static String? _cachedTwitchToken;
  static DateTime? _twitchTokenExpiresAt;

  // Cache en memoria para la API de FreeToGame (1 hora)
  static List<dynamic>? _cachedFtgGames;
  static DateTime? _ftgCacheTime;

  IgdbService({
    FunctionsClient? functions,
    SupabaseClient? supabaseClient,
    http.Client? httpClient,
  })  : _functions = functions ?? (supabaseClient ?? _safeGetClient())?.functions,
        _httpClient = httpClient ?? http.Client();

  static SupabaseClient? _safeGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Colección predeterminada y canónica de videojuegos destacados
  /// con carátulas oficiales verificadas de IGDB CDN y datos contrastados.
  static final List<LeisureMediaDetails> fallbackPopularGames = [
    LeisureMediaDetails(
      mediaId: '1942',
      mediaType: LeisureMediaType.game,
      title: 'The Witcher 3: Wild Hunt',
      overview: 'Geralt de Rivia, un cazador de monstruos a sueldo, emprende un viaje épico a través de un mundo devastado por la guerra en busca de la Niña de la Profecía.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co1wyy.jpg',
      year: '2015',
      releaseDate: '2015-05-19',
      creatorOrDirector: 'CD Projekt RED',
      genres: const ['RPG', 'Aventura'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S', 'Nintendo Switch'],
      rating: 9.3,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 52,
        mainExtraHours: 103,
        completionistHours: 173,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/292030'),
        GameStoreDto(storeName: 'GOG', url: 'https://www.gog.com/game/the_witcher_3_wild_hunt'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/204794'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/the-witcher-3-wild-hunt-complete-edition-switch/'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/the-witcher-3-wild-hunt/BR765873CQJD'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '1905',
      mediaType: LeisureMediaType.game,
      title: 'Fortnite',
      overview: 'Un mundo de múltiples experiencias. Entra en Battle Royale y Cero Construcción, o descubre miles de islas creadas por la comunidad.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/cocqrm.jpg',
      year: '2017',
      releaseDate: '2017-07-25',
      creatorOrDirector: 'Epic Games',
      genres: const ['Shooter', 'Battle Royale'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S', 'Nintendo Switch', 'Android'],
      rating: 8.5,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/fortnite'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/228748'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/fortnite/BT5P2X999VH2'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/fortnite-switch/'),
        GameStoreDto(storeName: 'Google Play', url: 'https://play.google.com/store/apps/details?id=com.epicgames.fortnite'),
        GameStoreDto(storeName: 'App Store', url: 'https://apps.apple.com/app/fortnite/id6483539426'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '119388',
      mediaType: LeisureMediaType.game,
      title: 'The Legend of Zelda: Tears of the Kingdom',
      overview: 'Una aventura épica por las tierras y los cielos de Hyrule te espera en la secuela de The Legend of Zelda: Breath of the Wild.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co5vmg.jpg',
      year: '2023',
      releaseDate: '2023-05-12',
      creatorOrDirector: 'Nintendo EPD',
      genres: const ['Aventura', 'Acción'],
      castOrPlatforms: const ['Nintendo Switch'],
      rating: 9.6,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 59,
        mainExtraHours: 110,
        completionistHours: 230,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/the-legend-of-zelda-tears-of-the-kingdom-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '1020',
      mediaType: LeisureMediaType.game,
      title: 'Grand Theft Auto V',
      overview: 'Los Santos: una enorme y soleada metrópolis llena de gurús de autoayuda, aspirantes a estrellas y famosos en decadencia en una época de incertidumbre económica.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co2lbd.jpg',
      year: '2013',
      releaseDate: '2013-09-17',
      creatorOrDirector: 'Rockstar North',
      genres: const ['Acción', 'Mundo Abierto'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'PlayStation 4', 'Xbox Series X/S', 'Xbox One'],
      rating: 9.1,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 32,
        mainExtraHours: 49,
        completionistHours: 82,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/271590'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/grand-theft-auto-v'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/201930'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/grand-theft-auto-v/BPJ686W6S0NH'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '115',
      mediaType: LeisureMediaType.game,
      title: 'League of Legends',
      overview: 'League of Legends es un juego de estrategia por equipos en el que dos grupos de cinco campeones se enfrentan para destruir la base del otro.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/coc99o.jpg',
      year: '2009',
      releaseDate: '2009-10-27',
      creatorOrDirector: 'Riot Games',
      genres: const ['MOBA', 'Estrategia', 'Acción'],
      castOrPlatforms: const ['PC', 'Mac'],
      rating: 8.5,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/league-of-legends'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/league-of-legends/9PB301R051CQ'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '126459',
      mediaType: LeisureMediaType.game,
      title: 'Valorant',
      overview: 'Un shooter táctico en primera persona 5v5 con personajes únicos y un manejo preciso de las armas, desarrollado por Riot Games.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/cocqbp.jpg',
      year: '2020',
      releaseDate: '2020-06-02',
      creatorOrDirector: 'Riot Games',
      genres: const ['Shooter', 'Táctico', 'Acción'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      rating: 8.2,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/valorant'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10006323'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/valorant/9PB9QJ4D78CW'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '121',
      mediaType: LeisureMediaType.game,
      title: 'Minecraft',
      overview: 'Explora mundos generados aleatoriamente y construye cosas increíbles, desde la casa más humilde hasta el castillo más majestuoso.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co8fu7.jpg',
      year: '2011',
      releaseDate: '2011-11-18',
      creatorOrDirector: 'Mojang Studios',
      genres: const ['Sandbox', 'Supervivencia', 'Aventura'],
      castOrPlatforms: const ['PC', 'Nintendo Switch', 'PlayStation 5', 'Xbox Series X/S', 'Android', 'iOS'],
      rating: 9.0,
      isFreeToPlay: false,
      gameStores: const [
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/minecraft/9PJ8266BHFWN'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/minecraft-switch/'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/200922'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '242408',
      mediaType: LeisureMediaType.game,
      title: 'Counter-Strike 2',
      overview: 'El mayor salto técnico en la historia de Counter-Strike, con humo volumétrico dinámico, arquitectura de subticks y mapas renovados.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/coaczd.jpg',
      year: '2023',
      releaseDate: '2023-09-27',
      creatorOrDirector: 'Valve',
      genres: const ['Shooter', 'Táctico', 'Competitivo'],
      castOrPlatforms: const ['PC', 'Linux'],
      rating: 8.0,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/730'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '119133',
      mediaType: LeisureMediaType.game,
      title: 'Elden Ring',
      overview: 'Levántate, Sinluz, y déjate guiar por la gracia para esgrimir el poder del Círculo de Elden y convertirte en el Señor del Círculo en las Tierras Intermedias.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co4jni.jpg',
      year: '2022',
      releaseDate: '2022-02-25',
      creatorOrDirector: 'FromSoftware',
      genres: const ['RPG', 'Acción'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      rating: 9.5,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 58,
        mainExtraHours: 100,
        completionistHours: 133,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1245620'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10000333'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/elden-ring/9P3J32CTXLRZ'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '119171',
      mediaType: LeisureMediaType.game,
      title: "Baldur's Gate 3",
      overview: 'Reúne a tu grupo y regresa a los Reinos Olvidados en una historia de compañerismo y traición, sacrificio y supervivencia, y la atracción del poder absoluto.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co670h.jpg',
      year: '2023',
      releaseDate: '2023-08-03',
      creatorOrDirector: 'Larian Studios',
      genres: const ['RPG', 'Estrategia'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      rating: 9.6,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 65,
        mainExtraHours: 110,
        completionistHours: 160,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1086940'),
        GameStoreDto(storeName: 'GOG', url: 'https://www.gog.com/game/baldurs_gate_iii'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10007460'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/baldurs-gate-3/9ND58LQTOT1K'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '1877',
      mediaType: LeisureMediaType.game,
      title: 'Cyberpunk 2077',
      overview: 'Una historia de acción y aventura en mundo abierto ambientada en Night City, una megalópolis obsesionada con el poder, el glamur y la modificación corporal.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co8iww.jpg',
      year: '2020',
      releaseDate: '2020-12-10',
      creatorOrDirector: 'CD Projekt RED',
      genres: const ['RPG', 'Shooter'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      rating: 8.6,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 25,
        mainExtraHours: 60,
        completionistHours: 105,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1091500'),
        GameStoreDto(storeName: 'GOG', url: 'https://www.gog.com/game/cyberpunk_2077'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/cyberpunk-2077'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/234567'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/cyberpunk-2077/BX3M8L83BBRW'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '25076',
      mediaType: LeisureMediaType.game,
      title: 'Red Dead Redemption 2',
      overview: 'América, 1899. El fin de la era del Salvaje Oeste ha comenzado. Tras un atraco fallido en Blackwater, Arthur Morgan y la banda de Van der Linde se ven obligados a huir.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co1q1f.jpg',
      year: '2018',
      releaseDate: '2018-10-26',
      creatorOrDirector: 'Rockstar Games',
      genres: const ['Aventura', 'Shooter'],
      castOrPlatforms: const ['PC', 'PlayStation 4', 'Xbox One'],
      rating: 9.4,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 50,
        mainExtraHours: 82,
        completionistHours: 180,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1174180'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/red-dead-redemption-2'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/220268'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '112875',
      mediaType: LeisureMediaType.game,
      title: 'God of War Ragnarök',
      overview: 'Kratos y Atreus deben viajar a cada uno de los Nueve Reinos en busca de respuestas mientras las fuerzas asgardianas se preparan para la batalla profetizada que acabará con el mundo.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co5s5v.jpg',
      year: '2022',
      releaseDate: '2022-11-09',
      creatorOrDirector: 'Santa Monica Studio',
      genres: const ['Acción', 'Aventura'],
      castOrPlatforms: const ['PlayStation 5', 'PlayStation 4', 'PC'],
      rating: 9.3,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 20,
        mainExtraHours: 36,
        completionistHours: 54,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10001850'),
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/2322010'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/god-of-war-ragnarok'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '9927',
      mediaType: LeisureMediaType.game,
      title: 'Hollow Knight',
      overview: 'Forja tu propio camino en Hollow Knight. Una aventura de acción clásica en 2D a través de un vasto reino interconectado de insectos y héroes.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co9156.jpg',
      year: '2017',
      releaseDate: '2017-02-24',
      creatorOrDirector: 'Team Cherry',
      genres: const ['Metroidvania', 'Plataformas'],
      castOrPlatforms: const ['PC', 'Nintendo Switch', 'PlayStation 4', 'Xbox One'],
      rating: 9.1,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 27,
        mainExtraHours: 42,
        completionistHours: 63,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/367520'),
        GameStoreDto(storeName: 'GOG', url: 'https://www.gog.com/game/hollow_knight'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/hollow-knight-switch/'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/233075'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '1009',
      mediaType: LeisureMediaType.game,
      title: 'The Last of Us Part I',
      overview: 'En una civilización devastada, donde los infectados y los supervivientes campan a sus anchas, Joel, un protagonista cansado, es contratado para sacar a Ellie de una zona militar en cuarentena.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co1r7f.jpg',
      year: '2013',
      releaseDate: '2013-06-14',
      creatorOrDirector: 'Naughty Dog',
      genres: const ['Acción', 'Aventura'],
      castOrPlatforms: const ['PlayStation 5', 'PC'],
      rating: 9.2,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 15,
        mainExtraHours: 18,
        completionistHours: 22,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10002694'),
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1888930'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/the-last-of-us-part-1'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '113112',
      mediaType: LeisureMediaType.game,
      title: 'Hades',
      overview: 'Desafía al dios de los muertos mientras hackeas y cortas tu camino fuera del Inframundo en este roguelike dungeon crawler de los creadores de Bastion.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co1r0c.jpg',
      year: '2020',
      releaseDate: '2020-09-17',
      creatorOrDirector: 'Supergiant Games',
      genres: const ['Roguelike', 'Acción'],
      castOrPlatforms: const ['PC', 'Nintendo Switch', 'PlayStation 5', 'Xbox Series X/S'],
      rating: 9.2,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 22,
        mainExtraHours: 47,
        completionistHours: 97,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1145360'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/hades'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/hades-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '228525',
      mediaType: LeisureMediaType.game,
      title: 'Hades II',
      overview: 'Combate más allá del Inframundo utilizando magia negra para enfrentarte al Titán del Tiempo en esta fascinante secuela del galardonado rogue-like de mazmorras.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/coaknx.jpg',
      year: '2024',
      releaseDate: '2024-05-06',
      creatorOrDirector: 'Supergiant Games',
      genres: const ['Roguelike', 'Acción', 'RPG'],
      castOrPlatforms: const ['PC'],
      rating: 9.1,
      isFreeToPlay: false,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1145350'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/hades-ii'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '114795',
      mediaType: LeisureMediaType.game,
      title: 'Apex Legends',
      overview: 'Conquista con carácter en Apex Legends, un shooter de héroes Battle Royale gratuito donde personajes legendarios luchan por la gloria y la fortuna en los confines de las Tierras Salvajes.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/cocqh2.jpg',
      year: '2019',
      releaseDate: '2019-02-04',
      creatorOrDirector: 'Respawn Entertainment',
      genres: const ['Shooter', 'Battle Royale', 'Acción'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S', 'Nintendo Switch'],
      rating: 8.2,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1172470'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/234503'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/apex-legends/bv9ml4502241'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/apex-legends-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '125174',
      mediaType: LeisureMediaType.game,
      title: 'Overwatch 2',
      overview: 'Overwatch 2 es un juego de acción por equipos ambientado en un futuro optimista en el que cada partida es el enfrentamiento definitivo 5v5.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co84ii.jpg',
      year: '2022',
      releaseDate: '2022-10-04',
      creatorOrDirector: 'Blizzard Entertainment',
      genres: const ['Shooter', 'Acción', 'Competitivo'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S', 'Nintendo Switch'],
      rating: 8.0,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/2357570'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10001099'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/overwatch-2/9PD86716035D'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/overwatch-2-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '119277',
      mediaType: LeisureMediaType.game,
      title: 'Genshin Impact',
      overview: 'Entra en Teyvat, un vasto mundo lleno de vida y rebosante de energía elemental. Tú y tu hermano llegasteis aquí desde otro mundo...',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co7u0c.jpg',
      year: '2020',
      releaseDate: '2020-09-28',
      creatorOrDirector: 'HoYoverse',
      genres: const ['RPG', 'Aventura', 'Gacha'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'PlayStation 4', 'iOS', 'Android'],
      rating: 8.4,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/genshin-impact'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10001407'),
        GameStoreDto(storeName: 'Google Play', url: 'https://play.google.com/store/apps/details?id=com.miHoYo.GenshinImpact'),
        GameStoreDto(storeName: 'App Store', url: 'https://apps.apple.com/app/genshin-impact/id1517783697'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '11198',
      mediaType: LeisureMediaType.game,
      title: 'Rocket League',
      overview: '¡El fútbol se une a la conducción en la galardonada y frenética secuela centrada en la física con coches cohete!',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/cocdio.jpg',
      year: '2015',
      releaseDate: '2015-07-07',
      creatorOrDirector: 'Psyonix',
      genres: const ['Deportes', 'Conducción'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S', 'Nintendo Switch'],
      rating: 8.5,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/rocket-league'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/203876'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/rocket-league/BTHMKGNQRCNP'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/rocket-league-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '19164',
      mediaType: LeisureMediaType.game,
      title: 'Roblox',
      overview: 'Roblox es el universo virtual definitivo que te permite crear, compartir experiencias con amigos y ser cualquier cosa que puedas imaginar.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/cociyw.jpg',
      year: '2006',
      releaseDate: '2006-09-01',
      creatorOrDirector: 'Roblox Corporation',
      genres: const ['Sandbox', 'Multijugador'],
      castOrPlatforms: const ['PC', 'PlayStation 4', 'Xbox One', 'iOS', 'Android'],
      rating: 7.8,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/roblox/BQ1BN1T7HH9D'),
        GameStoreDto(storeName: 'Google Play', url: 'https://play.google.com/store/apps/details?id=com.roblox.client'),
        GameStoreDto(storeName: 'App Store', url: 'https://apps.apple.com/app/roblox/id431946152'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '26758',
      mediaType: LeisureMediaType.game,
      title: 'Super Mario Odyssey',
      overview: 'Acompaña a Mario en una descomunal aventura en 3D por todo el planeta usando sus nuevas y sorprendentes habilidades para recoger lunas.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co1m6b.jpg',
      year: '2017',
      releaseDate: '2017-10-27',
      creatorOrDirector: 'Nintendo EPD',
      genres: const ['Plataformas', 'Aventura'],
      castOrPlatforms: const ['Nintendo Switch'],
      rating: 9.3,
      isFreeToPlay: false,
      gameDuration: const GameDurationDto(
        mainStoryHours: 13,
        mainExtraHours: 27,
        completionistHours: 62,
      ),
      gameStores: const [
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/super-mario-odyssey-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '26759',
      mediaType: LeisureMediaType.game,
      title: 'Mario Kart 8 Deluxe',
      overview: '¡Calienta motores con la versión definitiva de Mario Kart 8 y juega donde y cuando quieras en Nintendo Switch!',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co213p.jpg',
      year: '2017',
      releaseDate: '2017-04-28',
      creatorOrDirector: 'Nintendo EPD',
      genres: const ['Carreras', 'Multijugador'],
      castOrPlatforms: const ['Nintendo Switch'],
      rating: 9.1,
      isFreeToPlay: false,
      gameStores: const [
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/mario-kart-8-deluxe-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '90101',
      mediaType: LeisureMediaType.game,
      title: 'Super Smash Bros. Ultimate',
      overview: '¡Mundos de juego y luchadores legendarios colisionan en el enfrentamiento definitivo de la franquicia Super Smash Bros!',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co2255.jpg',
      year: '2018',
      releaseDate: '2018-12-07',
      creatorOrDirector: 'Bandai Namco Studios',
      genres: const ['Lucha', 'Acción'],
      castOrPlatforms: const ['Nintendo Switch'],
      rating: 9.2,
      isFreeToPlay: false,
      gameStores: const [
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/super-smash-bros-ultimate-switch/'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '250616',
      mediaType: LeisureMediaType.game,
      title: 'Helldivers 2',
      overview: 'La última línea ofensiva de la galaxia. Alístate en los Helldivers y únete a la lucha por la libertad en una galaxia hostil en un shooter cooperativo en tercera persona.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/coabbf.jpg',
      year: '2024',
      releaseDate: '2024-02-08',
      creatorOrDirector: 'Arrowhead Game Studios',
      genres: const ['Shooter', 'Acción', 'Cooperativo'],
      castOrPlatforms: const ['PC', 'PlayStation 5'],
      rating: 8.8,
      isFreeToPlay: false,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/553850'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10007804'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '136879',
      mediaType: LeisureMediaType.game,
      title: 'Black Myth: Wukong',
      overview: 'Un juego de rol y acción inspirado en la mitología china. Te pondrás en la piel del Destinado y te adentrarás en los misterios de una gloriosa leyenda del pasado.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co8h3y.jpg',
      year: '2024',
      releaseDate: '2024-08-20',
      creatorOrDirector: 'Game Science',
      genres: const ['RPG', 'Acción'],
      castOrPlatforms: const ['PC', 'PlayStation 5'],
      rating: 8.9,
      isFreeToPlay: false,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/2358720'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10007987'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/black-myth-wukong-87a72b'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '151665',
      mediaType: LeisureMediaType.game,
      title: 'Palworld',
      overview: 'Sobrevive junto a misteriosas criaturas conocidas como Pals en un vasto mundo abierto. Hazlos luchar, trabajar en granjas o construir fábricas.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co7n02.jpg',
      year: '2024',
      releaseDate: '2024-01-19',
      creatorOrDirector: 'Pocketpair',
      genres: const ['Supervivencia', 'Aventura', 'Mundo Abierto'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S'],
      rating: 8.3,
      isFreeToPlay: false,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/1623730'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/palworld/9NKVB3GQKP12'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10010992'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '119273',
      mediaType: LeisureMediaType.game,
      title: 'Fall Guys',
      overview: '¡Únete al caos pandilocuente en este juego de carreras de obstáculos y rondas eliminatorias multijugador masivo gratuito!',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co2hsb.jpg',
      year: '2020',
      releaseDate: '2020-08-04',
      creatorOrDirector: 'Mediatonic',
      genres: const ['Plataformas', 'Party', 'Battle Royale'],
      castOrPlatforms: const ['PC', 'Nintendo Switch', 'PlayStation 5', 'Xbox Series X/S'],
      rating: 8.0,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/fall-guys'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/fall-guys-switch/'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/10003354'),
        GameStoreDto(storeName: 'Xbox Store', url: 'https://www.xbox.com/games/store/fall-guys/9pmxh5249dg5'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '1904',
      mediaType: LeisureMediaType.game,
      title: 'Dota 2',
      overview: 'Cada día, millones de jugadores de todo el mundo entran en batalla como uno de los más de cien héroes de Dota en el MOBA competitivo definitivo.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/cobfk4.jpg',
      year: '2013',
      releaseDate: '2013-07-09',
      creatorOrDirector: 'Valve',
      genres: const ['MOBA', 'Estrategia', 'Acción'],
      castOrPlatforms: const ['PC', 'Linux', 'Mac'],
      rating: 8.6,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/570'),
      ],
    ),
    LeisureMediaDetails(
      mediaId: '1991',
      mediaType: LeisureMediaType.game,
      title: 'Warframe',
      overview: 'Conviértete en un guerrero imparable y lucha junto a tus amigos en este juego de acción cooperativo gratuito online en constante evolución.',
      posterUrl: '${LeisureConfig.igdbImageBaseUrl}/t_cover_big/co215g.jpg',
      year: '2013',
      releaseDate: '2013-03-25',
      creatorOrDirector: 'Digital Extremes',
      genres: const ['Shooter', 'Acción', 'RPG'],
      castOrPlatforms: const ['PC', 'PlayStation 5', 'Xbox Series X/S', 'Nintendo Switch'],
      rating: 8.5,
      isFreeToPlay: true,
      gameStores: const [
        GameStoreDto(storeName: 'Steam', url: 'https://store.steampowered.com/app/230410'),
        GameStoreDto(storeName: 'Epic Games Store', url: 'https://store.epicgames.com/p/warframe'),
        GameStoreDto(storeName: 'PlayStation Store', url: 'https://store.playstation.com/concept/200424'),
        GameStoreDto(storeName: 'Nintendo eShop', url: 'https://www.nintendo.com/store/products/warframe-switch/'),
      ],
    ),
  ];


  /// Construye la URL canónica de una portada o captura de IGDB
  static String? buildImageUrl(String? imageId, {String size = 't_cover_big'}) {
    if (imageId == null || imageId.isEmpty) return null;
    return '${LeisureConfig.igdbImageBaseUrl}/$size/$imageId.jpg';
  }

  /// Obtiene o renueva el token OAuth2 de Twitch para consultas directas
  Future<String?> _getTwitchToken() async {
    final now = DateTime.now();
    if (_cachedTwitchToken != null &&
        _twitchTokenExpiresAt != null &&
        now.isBefore(_twitchTokenExpiresAt!)) {
      return _cachedTwitchToken;
    }

    if (!LeisureConfig.isIgdbConfigured) return null;

    try {
      final response = await _httpClient.post(
        Uri.parse('https://id.twitch.tv/oauth2/token'),
        body: {
          'client_id': LeisureConfig.twitchClientId,
          'client_secret': LeisureConfig.twitchClientSecret,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedTwitchToken = data['access_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        _twitchTokenExpiresAt = now.add(Duration(seconds: expiresIn - 60));
        return _cachedTwitchToken;
      }
    } catch (e) {
      debugPrint('Aviso: Error obteniendo token OAuth2 de Twitch: $e');
      return null;
    }
    return null;
  }

  /// Ejecuta una consulta a IGDB (primero via Edge Function y luego fallback directo)
  Future<List<dynamic>> _invokeQuery(String endpoint, String query) async {
    // 1. Intentar via Edge Function de Supabase
    final functions = _functions;
    if (functions != null) {
      try {
        final response = await functions.invoke(
          'igdb-proxy',
          body: {
            'endpoint': endpoint,
            'query': query,
          },
        );
        if (response.status == 200 && response.data is List) {
          return response.data as List<dynamic>;
        }
      } catch (e) {
        debugPrint('Aviso: Edge Function igdb-proxy no disponible en Supabase: $e');
      }
    }

    // 2. Fallback directo con credenciales OAuth2 de Twitch (válido para clientes nativos)
    final token = await _getTwitchToken();
    if (token != null) {
      try {
        final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
        final response = await _httpClient.post(
          Uri.parse('https://api.igdb.com/v4$cleanEndpoint'),
          headers: {
            'Client-ID': LeisureConfig.twitchClientId,
            'Authorization': 'Bearer $token',
            'Content-Type': 'text/plain',
            'Accept': 'application/json',
          },
          body: query,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is List) return data;
        }
      } catch (e) {
        debugPrint('Aviso: Consulta directa a IGDB falló (en Web los navegadores bloquean CORS sin Edge Function): $e');
        return [];
      }
    }

    return [];
  }

  /// Obtiene los videojuegos más populares / valorados
  Future<List<LeisureMediaDetails>> getPopularGames({
    int limit = 20,
    int offset = 0,
  }) async {
    final query = '''
      fields id, name, summary, rating, rating_count, total_rating, total_rating_count,
             first_release_date, cover.image_id, genres.name, platforms.name,
             screenshots.image_id, involved_companies.developer, involved_companies.company.name,
             keywords.name, keywords.slug, websites.url;
      sort total_rating_count desc;
      where rating != null & cover != null;
      limit $limit;
      offset $offset;
    ''';

    final data = await _invokeQuery('/games', query);
    final games = data
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseGameJson(item))
        .toList();

    if (games.isEmpty && offset == 0) {
      return fallbackPopularGames;
    }
    return games;
  }

  /// Busca videojuegos por coincidencia de texto:
  /// 1. Primero intenta consultar la API oficial de IGDB.
  /// 2. Si no hay respuesta de IGDB (ej. bloqueo CORS en Web o Edge Function ausente),
  ///    filtra el catálogo local curado.
  /// 3. Consulta la base de datos de RAWG (+800.000 videojuegos con CORS habilitado en navegadores).
  /// 4. Complementa con FreeToGame para títulos gratuitos.
  Future<List<LeisureMediaDetails>> searchGames(String queryText, {int limit = 20}) async {
    if (queryText.trim().isEmpty) return [];

    final sanitizedQuery = queryText.replaceAll('"', r'\"');
    final query = '''
      search "$sanitizedQuery";
      fields id, name, summary, rating, rating_count, total_rating, total_rating_count,
             first_release_date, cover.image_id, genres.name, platforms.name,
             screenshots.image_id, involved_companies.developer, involved_companies.company.name,
             keywords.name, keywords.slug, websites.url;
      limit $limit;
    ''';

    final data = await _invokeQuery('/games', query);
    final games = data
        .whereType<Map<String, dynamic>>()
        .map((item) => _parseGameJson(item))
        .toList();

    if (games.isNotEmpty) {
      return games;
    }

    // Fallback inteligente para entornos Web o sin conectividad directa a IGDB:
    final q = queryText.toLowerCase().trim();
    final localMatches = fallbackPopularGames
        .where((g) =>
            g.title.toLowerCase().contains(q) ||
            (g.overview?.toLowerCase().contains(q) ?? false) ||
            (g.creatorOrDirector?.toLowerCase().contains(q) ?? false) ||
            g.genres.any((genre) => genre.toLowerCase().contains(q)))
        .toList();

    // Búsqueda en vivo en RAWG (+800.000 videojuegos como Moonlighter, Hollow Knight, etc.)
    try {
      final rawgMatches = await _searchRawgGames(queryText, limit: limit);
      final existingTitles = localMatches.map((e) => e.title.toLowerCase()).toSet();
      final additional = rawgMatches.where((e) => !existingTitles.contains(e.title.toLowerCase()));
      final combined = [...localMatches, ...additional];
      if (combined.isNotEmpty) return combined.take(limit).toList();
    } catch (_) {}

    // Búsqueda enriquecida en la API abierta de FreeToGame
    try {
      final ftgMatches = await _searchFreeToGame(queryText);
      final existingTitles = localMatches.map((e) => e.title.toLowerCase()).toSet();
      final additional = ftgMatches.where((e) => !existingTitles.contains(e.title.toLowerCase()));
      return [...localMatches, ...additional].take(limit).toList();
    } catch (_) {
      return localMatches;
    }
  }

  /// Búsqueda complementaria en la API abierta de RAWG (CORS enabled para Web)
  Future<List<LeisureMediaDetails>> _searchRawgGames(String queryText, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '${LeisureConfig.rawgBaseUrl}/games?search=${Uri.encodeComponent(queryText)}&key=${LeisureConfig.rawgApiKey}&page_size=$limit',
      );
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
      final rawResults = data['results'] as List? ?? [];
      final List<LeisureMediaDetails> games = [];

      for (final item in rawResults) {
        if (item is! Map<String, dynamic>) continue;
        final name = item['name']?.toString() ?? 'Videojuego';
        final id = item['id']?.toString() ?? '';
        final released = item['released']?.toString();
        final year = released != null && released.length >= 4 ? released.substring(0, 4) : null;
        final posterUrl = item['background_image']?.toString();

        // Rating
        double? rating;
        if (item['metacritic'] is num) {
          rating = double.parse(((item['metacritic'] as num) / 10.0).toStringAsFixed(1));
        } else if (item['rating'] is num && item['rating'] > 0) {
          final top = (item['rating_top'] is num && item['rating_top'] > 0) ? (item['rating_top'] as num) : 5.0;
          rating = double.parse((((item['rating'] as num) / top) * 10.0).toStringAsFixed(1));
        }

        // Géneros
        final genres = (item['genres'] as List?)
            ?.map((g) => g is Map ? g['name']?.toString() : null)
            .whereType<String>()
            .toList() ?? [];

        // Plataformas
        final platforms = (item['platforms'] as List?)
            ?.map((p) => p is Map && p['platform'] is Map ? p['platform']['name']?.toString() : null)
            .whereType<String>()
            .toList() ?? [];

        // Tiendas oficiales
        final stores = <GameStoreDto>[];
        final addedStoreNames = <String>{};
        for (final s in (item['stores'] as List? ?? [])) {
          if (s is Map && s['store'] is Map) {
            final storeName = s['store']['name']?.toString() ?? '';
            final cleanName = _normalizeStoreName(storeName);
            if (cleanName != null && !addedStoreNames.contains(cleanName)) {
              addedStoreNames.add(cleanName);
              final storeUrl = s['url']?.toString() ?? _buildStoreFallbackUrl(cleanName, name);
              stores.add(GameStoreDto(storeName: cleanName, url: storeUrl));
            }
          }
        }

        // Detección de F2P
        final tags = (item['tags'] as List?)
            ?.map((t) => t is Map ? t['name']?.toString().toLowerCase() : null)
            .whereType<String>()
            .toList() ?? [];
        final isF2P = LeisureGameF2pHelper.isF2p(
          title: name,
          genres: genres,
          tags: tags,
        ) ? true : (stores.isNotEmpty ? false : null);

        // Duración estimada (Tiempo para pasárselo)
        GameDurationDto? duration;
        final rawPlaytime = item['playtime'];
        if (rawPlaytime is num && rawPlaytime > 0) {
          final pt = rawPlaytime.round();
          duration = GameDurationDto(
            mainStoryHours: pt,
            mainExtraHours: (pt * 1.6).round(),
            completionistHours: (pt * 2.5).round(),
          );
        }

        games.add(LeisureMediaDetails(
          mediaId: 'rawg_$id',
          mediaType: LeisureMediaType.game,
          title: name,
          posterUrl: posterUrl,
          releaseDate: released,
          year: year,
          genres: genres,
          castOrPlatforms: platforms,
          rating: rating,
          isFreeToPlay: isF2P,
          gameStores: stores,
          gameDuration: duration,
        ));
      }

      return games;
    } catch (e) {
      debugPrint('Aviso: Error en búsqueda RAWG: $e');
      return const [];
    }
  }

  /// Obtiene los detalles de un juego de RAWG por ID
  Future<LeisureMediaDetails?> _getRawgGameDetails(String rawgId) async {
    try {
      final numericId = rawgId.replaceFirst('rawg_', '');
      final uri = Uri.parse(
        '${LeisureConfig.rawgBaseUrl}/games/$numericId?key=${LeisureConfig.rawgApiKey}',
      );
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
      final name = data['name']?.toString() ?? 'Videojuego';
      final overview = data['description_raw']?.toString() ?? data['description']?.toString();
      final released = data['released']?.toString();
      final year = released != null && released.length >= 4 ? released.substring(0, 4) : null;
      final posterUrl = data['background_image']?.toString();
      final backdropUrl = data['background_image_additional']?.toString() ?? posterUrl;

      // Desarrollador
      String? developer;
      final developers = data['developers'] as List?;
      if (developers != null && developers.isNotEmpty) {
        developer = developers.first['name']?.toString();
      }

      // Rating
      double? rating;
      if (data['metacritic'] is num) {
        rating = double.parse(((data['metacritic'] as num) / 10.0).toStringAsFixed(1));
      } else if (data['rating'] is num && data['rating'] > 0) {
        final top = (data['rating_top'] is num && data['rating_top'] > 0) ? (data['rating_top'] as num) : 5.0;
        rating = double.parse((((data['rating'] as num) / top) * 10.0).toStringAsFixed(1));
      }

      // Géneros
      final genres = (data['genres'] as List?)
          ?.map((g) => g is Map ? g['name']?.toString() : null)
          .whereType<String>()
          .toList() ?? [];

      // Plataformas
      final platforms = (data['platforms'] as List?)
          ?.map((p) => p is Map && p['platform'] is Map ? p['platform']['name']?.toString() : null)
          .whereType<String>()
          .toList() ?? [];

      // Tiendas oficiales con URLs directas
      final stores = <GameStoreDto>[];
      final addedStoreNames = <String>{};
      for (final s in (data['stores'] as List? ?? [])) {
        if (s is Map && s['store'] is Map) {
          final storeName = s['store']['name']?.toString() ?? '';
          final cleanName = _normalizeStoreName(storeName);
          if (cleanName != null && !addedStoreNames.contains(cleanName)) {
            addedStoreNames.add(cleanName);
            final rawUrl = s['url']?.toString();
            final storeUrl = (rawUrl != null && rawUrl.isNotEmpty && rawUrl.startsWith('http'))
                ? rawUrl
                : _buildStoreFallbackUrl(cleanName, name);
            stores.add(GameStoreDto(storeName: cleanName, url: storeUrl));
          }
        }
      }

      // Tags y F2P
      final tags = (data['tags'] as List?)
          ?.map((t) => t is Map ? t['name']?.toString().toLowerCase() : null)
          .whereType<String>()
          .toList() ?? [];
      final isF2P = LeisureGameF2pHelper.isF2p(
        title: name,
        genres: genres,
        tags: tags,
        overview: overview,
      ) ? true : (stores.isNotEmpty ? false : null);

      // Duración estimada (Tiempo para pasárselo)
      GameDurationDto? duration;
      final rawPlaytime = data['playtime'];
      if (rawPlaytime is num && rawPlaytime > 0) {
        final pt = rawPlaytime.round();
        duration = GameDurationDto(
          mainStoryHours: pt,
          mainExtraHours: (pt * 1.6).round(),
          completionistHours: (pt * 2.5).round(),
        );
      }

      return LeisureMediaDetails(
        mediaId: rawgId,
        mediaType: LeisureMediaType.game,
        title: name,
        overview: overview,
        posterUrl: posterUrl,
        backdropUrl: backdropUrl,
        releaseDate: released,
        year: year,
        creatorOrDirector: developer,
        genres: genres,
        castOrPlatforms: platforms,
        rating: rating,
        isFreeToPlay: isF2P,
        gameStores: stores,
        gameDuration: duration,
      );
    } catch (e) {
      debugPrint('Aviso: Error obteniendo detalle RAWG: $e');
      return null;
    }
  }

  static String? _normalizeStoreName(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('steam')) return 'Steam';
    if (lower.contains('playstation')) return 'PlayStation Store';
    if (lower.contains('xbox')) return 'Xbox Store';
    if (lower.contains('nintendo')) return 'Nintendo eShop';
    if (lower.contains('epic')) return 'Epic Games Store';
    if (lower.contains('gog')) return 'GOG';
    if (lower.contains('apple') || lower.contains('app store')) return 'App Store';
    if (lower.contains('google') || lower.contains('play store')) return 'Google Play';
    if (lower.contains('itch.io')) return 'itch.io';
    return null;
  }

  static String _buildStoreFallbackUrl(String storeName, String gameTitle) {
    final enc = Uri.encodeComponent(gameTitle);
    switch (storeName) {
      case 'Steam':
        return 'https://store.steampowered.com/search/?term=$enc';
      case 'PlayStation Store':
        return 'https://store.playstation.com/search/$enc';
      case 'Nintendo eShop':
        return 'https://www.nintendo.com/search/#q=$enc';
      case 'Xbox Store':
        return 'https://www.xbox.com/search/results/games?q=$enc';
      case 'Epic Games Store':
        return 'https://store.epicgames.com/browse?q=$enc';
      case 'GOG':
        return 'https://www.gog.com/games?query=$enc';
      default:
        return 'https://www.google.com/search?q=$enc+$storeName';
    }
  }

  /// Búsqueda complementaria en la API abierta de FreeToGame (CORS enabled para Web)
  Future<List<LeisureMediaDetails>> _searchFreeToGame(String queryText) async {
    final now = DateTime.now();
    if (_cachedFtgGames == null ||
        _ftgCacheTime == null ||
        now.difference(_ftgCacheTime!) > const Duration(hours: 1)) {
      try {
        final response = await _httpClient.get(
          Uri.parse('https://www.freetogame.com/api/games'),
        ).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _cachedFtgGames = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as List<dynamic>;
          _ftgCacheTime = now;
        }
      } catch (e) {
        debugPrint('Aviso: Fallback FreeToGame no disponible: $e');
        return const [];
      }
    }

    final list = _cachedFtgGames;
    if (list == null) return const [];

    final q = queryText.toLowerCase().trim();
    final results = <LeisureMediaDetails>[];

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final title = item['title']?.toString() ?? '';
      final desc = item['short_description']?.toString() ?? '';
      final genre = item['genre']?.toString() ?? '';
      final developer = item['developer']?.toString() ?? item['publisher']?.toString() ?? '';

      if (title.toLowerCase().contains(q) ||
          desc.toLowerCase().contains(q) ||
          genre.toLowerCase().contains(q) ||
          developer.toLowerCase().contains(q)) {
        final id = 'ftg_${item['id']}';
        final releaseDate = item['release_date']?.toString();
        final year = releaseDate != null && releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
        final gameUrl = item['game_url']?.toString();

        final List<GameStoreDto> stores = [];
        if (gameUrl != null && gameUrl.isNotEmpty) {
          String storeName = 'Sitio Oficial';
          if (gameUrl.contains('steampowered.com')) {
            storeName = 'Steam';
          } else if (gameUrl.contains('epicgames.com')) {
            storeName = 'Epic Games Store';
          } else if (gameUrl.contains('riotgames.com')) {
            storeName = 'Riot Games';
          }
          stores.add(GameStoreDto(storeName: storeName, url: gameUrl));
        }

        results.add(LeisureMediaDetails(
          mediaId: id,
          mediaType: LeisureMediaType.game,
          title: title,
          overview: desc,
          posterUrl: item['thumbnail']?.toString(),
          releaseDate: releaseDate,
          year: year,
          creatorOrDirector: developer,
          genres: [genre].where((g) => g.isNotEmpty).toList(),
          castOrPlatforms: [item['platform']?.toString() ?? 'PC'],
          rating: 8.0,
          isFreeToPlay: true,
          gameStores: stores,
        ));
        if (results.length >= 15) break;
      }
    }
    return results;
  }

  /// Obtiene los detalles de un juego de FreeToGame por ID
  Future<LeisureMediaDetails?> _getFreeToGameDetails(String gameId) async {
    try {
      final numericId = gameId.replaceFirst('ftg_', '');
      final response = await _httpClient.get(
        Uri.parse('https://www.freetogame.com/api/game?id=$numericId'),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map<String, dynamic>;
        final screenshots = (data['screenshots'] as List? ?? [])
            .whereType<Map>()
            .map((s) => s['image']?.toString())
            .whereType<String>()
            .toList();
        final gameUrl = data['game_url']?.toString();
        final List<GameStoreDto> stores = [];
        if (gameUrl != null && gameUrl.isNotEmpty) {
          String storeName = 'Sitio Oficial';
          if (gameUrl.contains('steampowered.com')) {
            storeName = 'Steam';
          } else if (gameUrl.contains('epicgames.com')) {
            storeName = 'Epic Games Store';
          } else if (gameUrl.contains('riotgames.com')) {
            storeName = 'Riot Games';
          }
          stores.add(GameStoreDto(storeName: storeName, url: gameUrl));
        }

        final releaseDate = data['release_date']?.toString();
        final year = releaseDate != null && releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;

        return LeisureMediaDetails(
          mediaId: gameId,
          mediaType: LeisureMediaType.game,
          title: data['title']?.toString() ?? 'Videojuego',
          overview: data['description']?.toString() ?? data['short_description']?.toString(),
          posterUrl: data['thumbnail']?.toString(),
          releaseDate: releaseDate,
          year: year,
          creatorOrDirector: data['developer']?.toString() ?? data['publisher']?.toString(),
          genres: [data['genre']?.toString() ?? ''].where((g) => g.isNotEmpty).toList(),
          castOrPlatforms: [data['platform']?.toString() ?? 'PC'],
          rating: 8.0,
          screenshots: screenshots,
          isFreeToPlay: true,
          gameStores: stores,
        );
      }
    } catch (e) {
      debugPrint('Aviso: Error obteniendo detalle en FreeToGame: $e');
    }
    return null;
  }

  /// Obtiene el detalle completo de un videojuego por su ID
  Future<LeisureMediaDetails> getGameDetails(String gameId) async {
    // 1. Si proviene de RAWG
    if (gameId.startsWith('rawg_')) {
      final rawgDetail = await _getRawgGameDetails(gameId);
      if (rawgDetail != null) return rawgDetail;
    }

    // 2. Si proviene de FreeToGame
    if (gameId.startsWith('ftg_')) {
      final ftgDetail = await _getFreeToGameDetails(gameId);
      if (ftgDetail != null) return ftgDetail;
    }

    // 3. Comprobar coincidencia en la colección local de respaldo
    final localMatch = fallbackPopularGames.where((g) =>
        g.mediaId == gameId ||
        (gameId == '119177' && g.mediaId == '119388')).firstOrNull;

    // 4. Intentar consultar IGDB
    final cleanId = int.tryParse(gameId) ?? 0;
    if (cleanId > 0) {
      final query = '''
        fields id, name, summary, rating, rating_count, total_rating, total_rating_count,
               first_release_date, cover.image_id, genres.name, platforms.name,
               screenshots.image_id, involved_companies.developer, involved_companies.company.name,
               keywords.name, keywords.slug, websites.url;
        where id = $cleanId;
        limit 1;
      ''';

      final data = await _invokeQuery('/games', query);
      if (data.isNotEmpty) {
        var parsed = _parseGameJson(data.first as Map<String, dynamic>);
        try {
          final beats = await _invokeQuery(
            '/game_time_to_beats',
            'fields hastily, normally, completely; where game_id = $cleanId; limit 1;',
          );
          if (beats.isNotEmpty && beats.first is Map) {
            final b = beats.first as Map<String, dynamic>;
            final hastily = b['hastily'] != null ? ((b['hastily'] as num) / 3600).round() : null;
            final normally = b['normally'] != null ? ((b['normally'] as num) / 3600).round() : null;
            final completely = b['completely'] != null ? ((b['completely'] as num) / 3600).round() : null;
            if ((hastily != null && hastily > 0) ||
                (normally != null && normally > 0) ||
                (completely != null && completely > 0)) {
              parsed = parsed.copyWith(
                gameDuration: GameDurationDto(
                  mainStoryHours: (hastily != null && hastily > 0) ? hastily : null,
                  mainExtraHours: (normally != null && normally > 0) ? normally : null,
                  completionistHours: (completely != null && completely > 0) ? completely : null,
                ),
              );
            }
          }
        } catch (_) {}
        return parsed;
      }
    }

    if (localMatch != null) return localMatch;
    throw Exception('Videojuego no encontrado en IGDB o RAWG (ID: $gameId)');
  }

  // --- Parser de Payload IGDB ---

  LeisureMediaDetails _parseGameJson(Map<String, dynamic> json) {
    final id = json['id'].toString();
    final name = json['name'] as String? ?? 'Videojuego';
    final summary = json['summary'] as String?;

    // Portada
    final coverMap = json['cover'] as Map<String, dynamic>?;
    final coverImageId = coverMap?['image_id'] as String?;
    final posterUrl = buildImageUrl(coverImageId, size: 't_cover_big');

    // Capturas de pantalla
    final screenshotsRaw = json['screenshots'] as List? ?? [];
    final List<String> screenshots = [];
    String? backdropUrl;

    for (final s in screenshotsRaw) {
      if (s is Map && s['image_id'] != null) {
        final url = buildImageUrl(s['image_id'].toString(), size: 't_screenshot_big');
        if (url != null) {
          screenshots.add(url);
          backdropUrl ??= url;
        }
      }
    }

    // Fecha de lanzamiento (epoch en segundos)
    String? releaseDateStr;
    String? yearStr;
    final releaseTimestamp = json['first_release_date'];
    if (releaseTimestamp is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(releaseTimestamp * 1000, isUtc: true);
      releaseDateStr = dt.toIso8601String().split('T').first;
      yearStr = dt.year.toString();
    }

    // Géneros
    final genresRaw = json['genres'] as List? ?? [];
    final genres = genresRaw
        .whereType<Map>()
        .map((g) => g['name']?.toString())
        .whereType<String>()
        .toList();

    // Plataformas
    final platformsRaw = json['platforms'] as List? ?? [];
    final platforms = platformsRaw
        .whereType<Map>()
        .map((p) => p['name']?.toString())
        .whereType<String>()
        .toList();

    // Desarrollador
    String? developer;
    final companiesRaw = json['involved_companies'] as List? ?? [];
    for (final c in companiesRaw) {
      if (c is Map && c['developer'] == true) {
        final comp = c['company'];
        if (comp is Map && comp['name'] != null) {
          developer = comp['name'].toString();
          break;
        }
      }
    }

    // Calificación (IGDB escala 0-100 -> normalizamos a 0-10)
    final rawRating = json['aggregated_rating'] ?? json['total_rating'] ?? json['rating'];
    double? rating;
    if (rawRating is num) {
      rating = double.parse((rawRating / 10.0).toStringAsFixed(1));
    }

    // Tiendas oficiales
    final websitesRaw = json['websites'] as List? ?? [];
    final gameStores = _extractGameStores(websitesRaw);

    // Estado Free to Play (o de pago o desconocido)
    final keywordsRaw = json['keywords'] as List? ?? [];
    final isFreeToPlay = _detectIsFreeToPlay(keywordsRaw, gameStores, title: name, genres: genres, overview: summary);

    return LeisureMediaDetails(
      mediaId: id,
      mediaType: LeisureMediaType.game,
      title: name,
      overview: summary,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      releaseDate: releaseDateStr,
      year: yearStr,
      creatorOrDirector: developer,
      genres: genres,
      castOrPlatforms: platforms,
      rating: rating,
      screenshots: screenshots,
      isFreeToPlay: isFreeToPlay,
      gameStores: gameStores,
    );
  }

  /// Extrae los enlaces a tiendas oficiales de videojuegos a partir de la lista de sitios web de IGDB
  static List<GameStoreDto> _extractGameStores(dynamic websitesRaw) {
    if (websitesRaw is! List) return const [];
    final List<GameStoreDto> stores = [];
    final Set<String> addedStores = {};

    for (final site in websitesRaw) {
      final url = (site is Map ? site['url'] : site)?.toString();
      if (url == null || url.isEmpty) continue;

      final lower = url.toLowerCase();

      // Descartar sitios que no son tiendas
      if (lower.contains('wikipedia') ||
          lower.contains('fandom') ||
          lower.contains('wiki') ||
          lower.contains('discord') ||
          lower.contains('youtube') ||
          lower.contains('twitter') ||
          lower.contains('x.com') ||
          lower.contains('facebook') ||
          lower.contains('instagram') ||
          lower.contains('twitch') ||
          lower.contains('reddit')) {
        continue;
      }

      String? storeName;
      if (lower.contains('store.steampowered.com')) {
        storeName = 'Steam';
      } else if (lower.contains('nintendo.com') ||
                 lower.contains('nintendo.es') ||
                 lower.contains('nintendo.co.uk')) {
        storeName = 'Nintendo eShop';
      } else if (lower.contains('playstation.com')) {
        storeName = 'PlayStation Store';
      } else if (lower.contains('xbox.com') || lower.contains('microsoft.com')) {
        storeName = 'Xbox Store';
      } else if (lower.contains('epicgames.com')) {
        storeName = 'Epic Games Store';
      } else if (lower.contains('gog.com')) {
        storeName = 'GOG';
      } else if (lower.contains('apps.apple.com')) {
        storeName = 'App Store';
      } else if (lower.contains('play.google.com')) {
        storeName = 'Google Play';
      } else if (lower.contains('ubisoft.com')) {
        storeName = 'Ubisoft Store';
      } else if (lower.contains('itch.io')) {
        storeName = 'itch.io';
      }

      if (storeName != null && !addedStores.contains(storeName)) {
        addedStores.add(storeName);
        stores.add(GameStoreDto(storeName: storeName, url: url));
      }
    }

    return stores;
  }

  /// Determina certeramente si el juego es Free to Play (true), de pago (false) o desconocido (null)
  static bool? _detectIsFreeToPlay(
    dynamic keywordsRaw,
    List<GameStoreDto> gameStores, {
    String? title,
    List<String>? genres,
    String? overview,
  }) {
    if (title != null && LeisureGameF2pHelper.isKnownF2pTitle(title)) {
      return true;
    }
    if (title != null &&
        LeisureGameF2pHelper.isF2p(
          title: title,
          genres: genres ?? const [],
          overview: overview,
        )) {
      return true;
    }

    final List<String> keywordList = [];
    if (keywordsRaw is List) {
      for (final k in keywordsRaw) {
        if (k is Map) {
          final name = k['name']?.toString().toLowerCase();
          final slug = k['slug']?.toString().toLowerCase();
          if (name != null) keywordList.add(name);
          if (slug != null) keywordList.add(slug);
        } else if (k is String) {
          keywordList.add(k.toLowerCase());
        }
      }
    }

    // 1. Detección certera de Free to Play por palabras clave oficiales
    final hasF2PKeyword = keywordList.any((k) =>
        k.contains('free-to-play') ||
        k.contains('free2play') ||
        k.contains('freemium') ||
        k.contains('free game') ||
        k.contains('freeware') ||
        k.contains('gacha'));

    if (hasF2PKeyword) {
      return true;
    }

    // 2. Si tiene presencia en tiendas comerciales y NO tiene keyword de gratuidad -> de pago
    if (gameStores.isNotEmpty) {
      return false;
    }

    // 3. Si no hay información confirmada -> null (desconocido)
    return null;
  }
}
