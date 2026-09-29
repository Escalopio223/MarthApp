import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/profile/domain/services/birthday_notification_formatter.dart';

void main() {
  group('BirthdayNotificationFormatter - Name List Formatting Tests', () {
    test('formatNameList returns empty string for empty or whitespace-only list', () {
      expect(BirthdayNotificationFormatter.formatNameList([]), equals(''));
      expect(BirthdayNotificationFormatter.formatNameList(['', '   ']), equals(''));
    });

    test('formatNameList formats single user correctly', () {
      expect(BirthdayNotificationFormatter.formatNameList(['Laura']), equals('Laura'));
      expect(BirthdayNotificationFormatter.formatNameList(['  Carlos  ']), equals('Carlos'));
    });

    test('formatNameList formats two users with "y" conjunction', () {
      expect(
        BirthdayNotificationFormatter.formatNameList(['Juan', 'María']),
        equals('Juan y María'),
      );
    });

    test('formatNameList formats two users with phonetic "e" conjunction before "i" / "hi"', () {
      expect(
        BirthdayNotificationFormatter.formatNameList(['Laura', 'Ignacio']),
        equals('Laura e Ignacio'),
      );
      expect(
        BirthdayNotificationFormatter.formatNameList(['Carlos', 'Irene']),
        equals('Carlos e Irene'),
      );
      expect(
        BirthdayNotificationFormatter.formatNameList(['Pedro', 'Hilario']),
        equals('Pedro e Hilario'),
      );
    });

    test('formatNameList preserves "y" conjunction before diphthongs (hie, hia)', () {
      expect(
        BirthdayNotificationFormatter.formatNameList(['Manuel', 'Hierro']),
        equals('Manuel y Hierro'),
      );
    });

    test('formatNameList formats three or more users with Oxford/Spanish serial commas and conjunction', () {
      expect(
        BirthdayNotificationFormatter.formatNameList(['Juan', 'María', 'Pedro']),
        equals('Juan, María y Pedro'),
      );
      expect(
        BirthdayNotificationFormatter.formatNameList(['Juan', 'María', 'Pedro', 'Ignacio']),
        equals('Juan, María, Pedro e Ignacio'),
      );
    });

    test('formatNameList deduplicates identical names while preserving order', () {
      expect(
        BirthdayNotificationFormatter.formatNameList(['Juan', 'María', 'Juan']),
        equals('Juan y María'),
      );
    });
  });

  group('BirthdayNotificationFormatter - Dynamic Notification Message Tests', () {
    test('formats single birthday today correctly injecting name in title and body', () {
      final msg = BirthdayNotificationFormatter.format(
        names: ['Laura'],
        diasRestantes: 0,
      );

      expect(msg.title, equals('¡Hoy es el cumpleaños de Laura! 🎂'));
      expect(msg.body, equals('Felicita a Laura en su día especial.'));
      expect(msg.names, equals(['Laura']));
      expect(msg.diasRestantes, equals(0));
    });

    test('formats multiple birthdays today joining names with "y"', () {
      final msg = BirthdayNotificationFormatter.format(
        names: ['Juan', 'María'],
        diasRestantes: 0,
      );

      expect(msg.title, equals('Juan y María cumplen años hoy 🎂'));
      expect(
        msg.body,
        equals('¡Hoy es el cumpleaños de Juan y María! Deséales un feliz día especial.'),
      );
      expect(msg.names, equals(['Juan', 'María']));
    });

    test('formats three birthdays today with commas and conjunction', () {
      final msg = BirthdayNotificationFormatter.format(
        names: ['Juan', 'María', 'Pedro'],
        diasRestantes: 0,
      );

      expect(msg.title, equals('Juan, María y Pedro cumplen años hoy 🎂'));
      expect(
        msg.body,
        equals('¡Hoy es el cumpleaños de Juan, María y Pedro! Deséales un feliz día especial.'),
      );
      expect(msg.names, equals(['Juan', 'María', 'Pedro']));
    });

    test('formats 1-day reminder (tomorrow) for single and multiple users', () {
      final single = BirthdayNotificationFormatter.format(
        names: ['Roberto'],
        diasRestantes: 1,
      );
      expect(single.title, equals('🎂 ¡Mañana es el cumpleaños de Roberto!'));
      expect(single.body, contains('Felicítale en su día'));

      final multiple = BirthdayNotificationFormatter.format(
        names: ['Roberto', 'Lucía'],
        diasRestantes: 1,
      );
      expect(multiple.title, equals('🎂 ¡Mañana es el cumpleaños de Roberto y Lucía!'));
      expect(multiple.body, contains('Deséales un gran día'));
    });

    test('formats 3-day reminder with gift ideas if present', () {
      final withGifts = BirthdayNotificationFormatter.format(
        names: ['Sofía'],
        diasRestantes: 3,
        ideasRegalo: 'Auriculares, Libro de ciencia ficción',
      );
      expect(withGifts.title, equals('🎂 Próximo cumpleaños: Sofía'));
      expect(withGifts.body, contains('¡Solo quedan 3 días para el cumpleaños de Sofía!'));
      expect(withGifts.body, contains('Ideas de regalo: Auriculares, Libro de ciencia ficción'));

      final multiple = BirthdayNotificationFormatter.format(
        names: ['Sofía', 'Daniel'],
        diasRestantes: 3,
      );
      expect(multiple.title, equals('🎂 Próximos cumpleaños: Sofía y Daniel'));
      expect(multiple.body, contains('¡Solo quedan 3 días para el cumpleaños de Sofía y Daniel!'));
    });

    test('formats 7-day and 14-day upcoming reminders correctly', () {
      final in7Days = BirthdayNotificationFormatter.format(
        names: ['Andrés'],
        diasRestantes: 7,
      );
      expect(in7Days.title, equals('🎂 Próximo cumpleaños: Andrés'));
      expect(in7Days.body, contains('Falta exactamente 1 semana'));

      final in14Days = BirthdayNotificationFormatter.format(
        names: ['Andrés', 'Elena'],
        diasRestantes: 14,
      );
      expect(in14Days.title, equals('🎂 Próximos cumpleaños: Andrés y Elena'));
      expect(in14Days.body, contains('Faltan 2 semanas'));
    });

    test('handles empty list gracefully without throwing exceptions', () {
      final emptyMsg = BirthdayNotificationFormatter.format(
        names: [],
        diasRestantes: 0,
      );
      expect(emptyMsg.title, equals('🎂 Recordatorio de Cumpleaños'));
      expect(emptyMsg.body, isNotEmpty);
    });

    test('formats self-greeting correctly for birthday user', () {
      final selfMsg = BirthdayNotificationFormatter.formatSelfGreeting(
        userName: 'Alejandro',
        diasRestantes: 0,
      );
      expect(selfMsg.title, equals('🎉 ¡Feliz cumpleaños, Alejandro! 🎂'));
      expect(selfMsg.body, contains('te desean un día maravilloso'));
    });
  });

  group('BirthdayNotificationFormatter - FCM Contract & Background Delivery Tests', () {
    test('toFCMDataPayload respects contracts and produces string-only map', () {
      final msg = BirthdayNotificationFormatter.format(
        names: ['Juan', 'María'],
        diasRestantes: 0,
        entornoId: 'env-uuid-1234',
        eventoId: 'ev-uuid-5678',
      );

      final payload = msg.toFCMDataPayload();

      expect(payload['click_action'], equals('FLUTTER_NOTIFICATION_CLICK'));
      expect(payload['type'], equals('cumpleanos'));
      expect(payload['title'], equals('Juan y María cumplen años hoy 🎂'));
      expect(payload['body'], equals('¡Hoy es el cumpleaños de Juan y María! Deséales un feliz día especial.'));
      expect(payload['dias_restantes'], equals('0'));
      expect(payload['names_count'], equals('2'));
      expect(payload['names'], equals('Juan, María'));
      expect(payload['entorno_id'], equals('env-uuid-1234'));
      expect(payload['evento_id'], equals('ev-uuid-5678'));

      // Verifica que cada valor en el mapa de datos sea estrictamente un String
      for (final entry in payload.entries) {
        expect(entry.key, isA<String>());
        expect(entry.value, isA<String>());
      }
    });
  });
}
