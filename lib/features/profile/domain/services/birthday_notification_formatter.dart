import 'package:flutter/foundation.dart';

/// Representación estructurada del mensaje y payload de una notificación de cumpleaños
@immutable
class BirthdayNotificationMessage {
  final String title;
  final String body;
  final List<String> names;
  final int diasRestantes;
  final String? entornoId;
  final String? eventoId;

  const BirthdayNotificationMessage({
    required this.title,
    required this.body,
    this.names = const [],
    this.diasRestantes = 0,
    this.entornoId,
    this.eventoId,
  });

  /// Genera el data payload estructurado en formato Map<String, String>
  /// respetando los contratos de notificación en segundo plano y estado terminado (killed state).
  Map<String, String> toFCMDataPayload() {
    return {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'type': 'cumpleanos',
      'title': title,
      'body': body,
      'dias_restantes': diasRestantes.toString(),
      'names_count': names.length.toString(),
      if (names.isNotEmpty) 'names': names.join(', '),
      if (entornoId != null && entornoId!.isNotEmpty) 'entorno_id': entornoId!,
      if (eventoId != null && eventoId!.isNotEmpty) 'evento_id': eventoId!,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthdayNotificationMessage &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          body == other.body &&
          listEquals(names, other.names) &&
          diasRestantes == other.diasRestantes &&
          entornoId == other.entornoId &&
          eventoId == other.eventoId;

  @override
  int get hashCode => Object.hash(
        title,
        body,
        Object.hashAll(names),
        diasRestantes,
        entornoId,
        eventoId,
      );

  @override
  String toString() =>
      'BirthdayNotificationMessage(title: "$title", body: "$body", dias: $diasRestantes)';
}

/// Servicio de dominio para la composición y formateo dinámico de notificaciones
/// de cumpleaños basándose en entidades canónicas de usuario/perfil.
class BirthdayNotificationFormatter {
  const BirthdayNotificationFormatter._();

  /// Formatea una lista de nombres con gramática española correcta:
  /// - 0 elementos -> ""
  /// - 1 elemento -> "Juan"
  /// - 2 elementos -> "Juan y María"
  /// - 3 elementos -> "Juan, María y Pedro"
  /// Aplica el conector 'e' cuando el siguiente nombre inicia fonéticamente con /i/ (ej. Ignacio, Irene).
  static String formatNameList(List<String> rawNames) {
    final cleanNames = <String>[];
    for (final raw in rawNames) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty && !cleanNames.contains(trimmed)) {
        cleanNames.add(trimmed);
      }
    }

    if (cleanNames.isEmpty) return '';
    if (cleanNames.length == 1) return cleanNames.first;
    if (cleanNames.length == 2) {
      final connector = _resolveConjunction(cleanNames[1]);
      return '${cleanNames[0]} $connector ${cleanNames[1]}';
    }

    final allExceptLast = cleanNames.sublist(0, cleanNames.length - 1);
    final last = cleanNames.last;
    final connector = _resolveConjunction(last);
    return '${allExceptLast.join(', ')} $connector $last';
  }

  /// Resuelve la conjunción copulativa adecuada ('y' o 'e') en español
  static String _resolveConjunction(String nextWord) {
    final lower = nextWord.toLowerCase().trim();
    // Excepciones donde 'y' se mantiene ante diptongos: 'ia', 'ie', 'io', 'iu' (ej. 'Hierro', 'Iata')
    if (lower.startsWith('hie') ||
        lower.startsWith('hia') ||
        lower.startsWith('hio') ||
        lower.startsWith('hiu')) {
      return 'y';
    }
    if (lower.startsWith('i') || lower.startsWith('hi')) {
      return 'e';
    }
    return 'y';
  }

  /// Compone el mensaje dinámico (título y cuerpo) a partir de los cumpleañeros coincidentes
  /// e inyecta las variables dinámicamente sustituyendo textos estáticos.
  static BirthdayNotificationMessage format({
    required List<String> names,
    int diasRestantes = 0,
    String? ideasRegalo,
    String? entornoId,
    String? eventoId,
  }) {
    final cleanNames = names
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    if (cleanNames.isEmpty) {
      return BirthdayNotificationMessage(
        title: '🎂 Recordatorio de Cumpleaños',
        body: 'Hay un cumpleaños próximo en tu entorno.',
        diasRestantes: diasRestantes,
        entornoId: entornoId,
        eventoId: eventoId,
      );
    }

    final formattedNames = formatNameList(cleanNames);
    final isMultiple = cleanNames.length > 1;

    String title;
    String body;

    switch (diasRestantes) {
      case 0: // Hoy
        if (!isMultiple) {
          title = '¡Hoy es el cumpleaños de $formattedNames! 🎂';
          body = 'Felicita a $formattedNames en su día especial.';
        } else {
          title = '$formattedNames cumplen años hoy 🎂';
          body =
              '¡Hoy es el cumpleaños de $formattedNames! Deséales un feliz día especial.';
        }
        break;

      case 1: // Mañana
        if (!isMultiple) {
          title = '🎂 ¡Mañana es el cumpleaños de $formattedNames!';
          body = 'Mañana es el cumpleaños de $formattedNames. ¡Felicítale en su día!';
        } else {
          title = '🎂 ¡Mañana es el cumpleaños de $formattedNames!';
          body = 'Mañana cumplen años $formattedNames. ¡Deséales un gran día!';
        }
        break;

      case 3:
        if (!isMultiple) {
          title = '🎂 Próximo cumpleaños: $formattedNames';
          body = '¡Solo quedan 3 días para el cumpleaños de $formattedNames!';
          if (ideasRegalo != null && ideasRegalo.trim().isNotEmpty) {
            body += ' Ideas de regalo: ${ideasRegalo.trim()}';
          }
        } else {
          title = '🎂 Próximos cumpleaños: $formattedNames';
          body = '¡Solo quedan 3 días para el cumpleaños de $formattedNames!';
        }
        break;

      case 7:
        if (!isMultiple) {
          title = '🎂 Próximo cumpleaños: $formattedNames';
          body = 'Falta exactamente 1 semana para el cumpleaños de $formattedNames.';
        } else {
          title = '🎂 Próximos cumpleaños: $formattedNames';
          body = 'Falta exactamente 1 semana para el cumpleaños de $formattedNames.';
        }
        break;

      case 14:
        if (!isMultiple) {
          title = '🎂 Próximo cumpleaños: $formattedNames';
          body =
              'Faltan 2 semanas para el cumpleaños de $formattedNames. ¡Buen momento para planear regalos!';
        } else {
          title = '🎂 Próximos cumpleaños: $formattedNames';
          body =
              'Faltan 2 semanas para el cumpleaños de $formattedNames. ¡Buen momento para organizar sorpresas!';
        }
        break;

      default:
        if (!isMultiple) {
          title = '🎂 Cumpleaños de $formattedNames';
          body = 'Quedan $diasRestantes días para el cumpleaños de $formattedNames.';
        } else {
          title = '🎂 Cumpleaños de $formattedNames';
          body = 'Quedan $diasRestantes días para el cumpleaños de $formattedNames.';
        }
        break;
    }

    return BirthdayNotificationMessage(
      title: title,
      body: body,
      names: cleanNames,
      diasRestantes: diasRestantes,
      entornoId: entornoId,
      eventoId: eventoId,
    );
  }

  /// Formatea la notificación personalizada cuando el destinatario es uno de los cumpleañeros
  static BirthdayNotificationMessage formatSelfGreeting({
    required String userName,
    int diasRestantes = 0,
    String? entornoId,
  }) {
    final cleanName = userName.trim();
    if (diasRestantes == 0) {
      return BirthdayNotificationMessage(
        title: '🎉 ¡Feliz cumpleaños, $cleanName! 🎂',
        body: '¡Todo el equipo y tus compañeros de MarthApp te desean un día maravilloso!',
        names: [cleanName],
        diasRestantes: 0,
        entornoId: entornoId,
      );
    }
    return BirthdayNotificationMessage(
      title: '🎂 Tu cumpleaños se acerca',
      body: '¡Solo faltan $diasRestantes días para tu cumpleaños, $cleanName!',
      names: [cleanName],
      diasRestantes: diasRestantes,
      entornoId: entornoId,
    );
  }
}
