/// Helper canónico para detección certera de videojuegos Free to Play (F2P)
class LeisureGameF2pHelper {
  /// Lista exhaustiva de títulos y sagas mundialmente conocidas que son 100% Free to Play
  static const Set<String> _canonicalF2pTitles = {
    'fortnite',
    'league of legends',
    'lol',
    'valorant',
    'genshin impact',
    'apex legends',
    'counter-strike',
    'counter-strike 2',
    'cs:go',
    'cs 2',
    'cs2',
    'counter strike',
    'dota 2',
    'overwatch 2',
    'warframe',
    'rocket league',
    'pubg',
    'pubg: battlegrounds',
    'destiny 2',
    'fall guys',
    'brawlhalla',
    'roblox',
    'warzone',
    'call of duty: warzone',
    'the sims 4',
    'path of exile',
    'path of exile 2',
    'team fortress 2',
    'honkai: star rail',
    'honkai impact 3rd',
    'zenless zone zero',
    'marvel snap',
    'lost ark',
    'smite',
    'smite 2',
    'paladins',
    'world of tanks',
    'world of warships',
    'albion online',
    'brawl stars',
    'clash royale',
    'clash of clans',
    'free fire',
    'pokemon unite',
    'yu-gi-oh! master duel',
    'halo infinite',
    'the finals',
    'multiversus',
    'war thunder',
    'crossout',
    'enlisted',
    'hearthstone',
    'magic: the gathering arena',
    'mtg arena',
    'fallout shelter',
    'delta force',
    'runescape',
    'old school runescape',
    'star wars: the old republic',
    'guild wars 2',
    'crusader kings ii',
    'trackmania',
    'asphalt 9',
    'asphalt legends unite',
    'diablo immortal',
    'efootball',
    'efootball 2024',
    'efootball 2025',
    'splitgate',
    'first descendant',
    'the first descendant',
    'wuthering waves',
    'once human',
    'marvel rivals',
    'star wars: hunters',
    'xdefiant',
    'stumble guys',
    'arena breakout',
    'arena breakout: infinite',
    'naraka: bladepoint',
    'marvel contest of champions',
    'gwent',
    'super animal royale',
    'bloodhunt',
    'vampire: the masquerade - bloodhunt',
    'realm royale',
  };

  /// Comprueba si el título coincide con alguno de los juegos Free to Play canónicos
  static bool isKnownF2pTitle(String title) {
    final clean = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return false;

    for (final canon in _canonicalF2pTitles) {
      final cleanCanon = canon
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (clean == cleanCanon ||
          clean.startsWith('$cleanCanon ') ||
          clean.endsWith(' $cleanCanon') ||
          clean.contains(' $cleanCanon ') ||
          clean.contains(cleanCanon)) {
        return true;
      }
    }
    return false;
  }

  /// Determina si un videojuego es Free to Play evaluando:
  /// 1. Título canónico F2P (ej. Fortnite, Apex, Genshin...)
  /// 2. Booleano explícito `isFreeToPlay`
  /// 3. Géneros o categorías
  /// 4. Etiquetas / tags
  /// 5. Descripción o sinopsis
  static bool isF2p({
    bool? isFreeToPlay,
    required String title,
    List<String> genres = const [],
    String? overview,
    List<String> tags = const [],
  }) {
    // 1. Título canónico indiscutible (ej. Fortnite siempre es F2P)
    if (isKnownF2pTitle(title)) {
      return true;
    }

    // 2. Si el booleano explícito es true
    if (isFreeToPlay == true) {
      return true;
    }

    // 3. Géneros que indiquen gratuidad
    for (final g in genres) {
      final lower = g.toLowerCase();
      if (lower.contains('free to play') ||
          lower.contains('free-to-play') ||
          lower == 'f2p' ||
          lower.contains('gratuito') ||
          lower.contains('gratis')) {
        return true;
      }
    }

    // 4. Tags / Etiquetas
    for (final t in tags) {
      final lower = t.toLowerCase();
      if (lower.contains('free to play') ||
          lower.contains('free-to-play') ||
          lower == 'f2p' ||
          lower.contains('free game') ||
          lower.contains('freemium') ||
          lower.contains('gacha') ||
          lower.contains('gratuito')) {
        return true;
      }
    }

    // 5. Sinopsis / Descripción
    if (overview != null && overview.isNotEmpty) {
      final lowerOverview = overview.toLowerCase();
      if (lowerOverview.contains('free to play') ||
          lowerOverview.contains('free-to-play') ||
          lowerOverview.contains('juego gratuito') ||
          lowerOverview.contains('juega gratis') ||
          lowerOverview.contains('gratis para jugar') ||
          lowerOverview.contains('free-to-download') ||
          lowerOverview.contains('free to download')) {
        return true;
      }
    }

    return false;
  }
}
