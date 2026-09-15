import 'package:flutter/foundation.dart';

/// DTO que representa el desglose de tiempo necesario para completar un videojuego:
/// - [mainStoryHours]: Tiempo estimado para completar la historia principal / modo estándar.
/// - [mainExtraHours]: Tiempo para completar la historia principal y misiones secundarias (Extras).
/// - [completionistHours]: Tiempo para obtener el 100% (todos los logros, coleccionables y extras).
@immutable
class GameDurationDto {
  final int? mainStoryHours;
  final int? mainExtraHours;
  final int? completionistHours;

  const GameDurationDto({
    this.mainStoryHours,
    this.mainExtraHours,
    this.completionistHours,
  });

  /// Indica si al menos uno de los tres valores de tiempo está disponible
  bool get hasAny =>
      (mainStoryHours != null && mainStoryHours! > 0) ||
      (mainExtraHours != null && mainExtraHours! > 0) ||
      (completionistHours != null && completionistHours! > 0);

  Map<String, dynamic> toJson() {
    return {
      if (mainStoryHours != null) 'main_story_hours': mainStoryHours,
      if (mainExtraHours != null) 'main_extra_hours': mainExtraHours,
      if (completionistHours != null) 'completionist_hours': completionistHours,
    };
  }

  factory GameDurationDto.fromJson(Map<String, dynamic> json) {
    return GameDurationDto(
      mainStoryHours: (json['main_story_hours'] ?? json['mainStoryHours']) as int?,
      mainExtraHours: (json['main_extra_hours'] ?? json['mainExtraHours']) as int?,
      completionistHours: (json['completionist_hours'] ?? json['completionistHours']) as int?,
    );
  }

  GameDurationDto copyWith({
    int? mainStoryHours,
    int? mainExtraHours,
    int? completionistHours,
  }) {
    return GameDurationDto(
      mainStoryHours: mainStoryHours ?? this.mainStoryHours,
      mainExtraHours: mainExtraHours ?? this.mainExtraHours,
      completionistHours: completionistHours ?? this.completionistHours,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameDurationDto &&
          runtimeType == other.runtimeType &&
          mainStoryHours == other.mainStoryHours &&
          mainExtraHours == other.mainExtraHours &&
          completionistHours == other.completionistHours;

  @override
  int get hashCode => Object.hash(mainStoryHours, mainExtraHours, completionistHours);

  @override
  String toString() =>
      'GameDurationDto(story: ${mainStoryHours}h, extras: ${mainExtraHours}h, 100%: ${completionistHours}h)';
}
