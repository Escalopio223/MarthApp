/// Estados de seguimiento personal para un elemento de ocio
enum LeisureItemStatus {
  watched,
  toWatch,
  favorite,
  watching;

  /// Serialización a cadena coincidente con el enum PostgreSQL en Supabase
  String toValue() {
    switch (this) {
      case LeisureItemStatus.watched:
        return 'watched';
      case LeisureItemStatus.toWatch:
        return 'to_watch';
      case LeisureItemStatus.favorite:
        return 'favorite';
      case LeisureItemStatus.watching:
        return 'watching';
    }
  }

  /// Deserialización segura desde cadena
  static LeisureItemStatus? fromValue(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'watched':
        return LeisureItemStatus.watched;
      case 'to_watch':
      case 'towatch':
        return LeisureItemStatus.toWatch;
      case 'favorite':
        return LeisureItemStatus.favorite;
      case 'watching':
        return LeisureItemStatus.watching;
      default:
        return null;
    }
  }

  /// Regla de negocio: 'favorite' computa internamente como 'watched'
  bool get isWatched =>
      this == LeisureItemStatus.watched || this == LeisureItemStatus.favorite;

  /// Etiqueta legible en español para la interfaz
  String get label {
    switch (this) {
      case LeisureItemStatus.watched:
        return 'Visto / Completado';
      case LeisureItemStatus.toWatch:
        return 'Pendiente';
      case LeisureItemStatus.favorite:
        return 'Favorito';
      case LeisureItemStatus.watching:
        return 'En progreso';
    }
  }
}
