import 'package:flutter/material.dart';

/// Opciones de ordenación disponibles para los ítems dentro de una lista de entorno
enum LeisureListSortOption {
  manual,
  ratingDesc,
  ratingAsc,
  yearDesc,
  yearAsc,
  dateAddedDesc,
  titleAsc;

  String get label {
    switch (this) {
      case LeisureListSortOption.manual:
        return 'Personalizado (Drag & Drop)';
      case LeisureListSortOption.ratingDesc:
        return 'Mejor valorados';
      case LeisureListSortOption.ratingAsc:
        return 'Menor valoración';
      case LeisureListSortOption.yearDesc:
        return 'Año: Más recientes';
      case LeisureListSortOption.yearAsc:
        return 'Año: Más antiguos';
      case LeisureListSortOption.dateAddedDesc:
        return 'Añadidos recientemente';
      case LeisureListSortOption.titleAsc:
        return 'Título (A - Z)';
    }
  }

  IconData get icon {
    switch (this) {
      case LeisureListSortOption.manual:
        return Icons.drag_handle_rounded;
      case LeisureListSortOption.ratingDesc:
        return Icons.star_rounded;
      case LeisureListSortOption.ratingAsc:
        return Icons.star_border_rounded;
      case LeisureListSortOption.yearDesc:
        return Icons.calendar_today_rounded;
      case LeisureListSortOption.yearAsc:
        return Icons.history_rounded;
      case LeisureListSortOption.dateAddedDesc:
        return Icons.schedule_rounded;
      case LeisureListSortOption.titleAsc:
        return Icons.sort_by_alpha_rounded;
    }
  }
}
