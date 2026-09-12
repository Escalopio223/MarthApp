/// Tipos de contenido multimedia admitidos en el módulo de Ocio
enum LeisureMediaType {
  movie,
  tv,
  book,
  game;

  /// Serialización a cadena coincidente con el enum PostgreSQL en Supabase
  String toValue() {
    switch (this) {
      case LeisureMediaType.movie:
        return 'movie';
      case LeisureMediaType.tv:
        return 'tv';
      case LeisureMediaType.book:
        return 'book';
      case LeisureMediaType.game:
        return 'game';
    }
  }

  /// Deserialización segura desde cadena con fallback a 'movie'
  static LeisureMediaType fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'movie':
        return LeisureMediaType.movie;
      case 'tv':
      case 'series':
        return LeisureMediaType.tv;
      case 'book':
        return LeisureMediaType.book;
      case 'game':
        return LeisureMediaType.game;
      default:
        return LeisureMediaType.movie;
    }
  }

  /// Nombre en español legible para la interfaz
  String get label {
    switch (this) {
      case LeisureMediaType.movie:
        return 'Película';
      case LeisureMediaType.tv:
        return 'Serie';
      case LeisureMediaType.book:
        return 'Libro';
      case LeisureMediaType.game:
        return 'Videojuego';
    }
  }

  /// Plural en español
  String get pluralLabel {
    switch (this) {
      case LeisureMediaType.movie:
        return 'Películas';
      case LeisureMediaType.tv:
        return 'Series';
      case LeisureMediaType.book:
        return 'Libros';
      case LeisureMediaType.game:
        return 'Videojuegos';
    }
  }
}
