import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/services/local_notification_service.dart';
import 'package:marth_app/features/planificador/domain/models/recordatorio_tarea_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalNotificationService Tests', () {
    test('calcularFechaProgramada correctly sets future hour and minute', () {
      final service = LocalNotificationService.instance;
      final futureDate = DateTime.now().add(const Duration(days: 2));

      final scheduled = service.calcularFechaProgramada(
        futureDate,
        '15:45',
      );

      expect(scheduled, isNotNull);
      expect(scheduled!.year, equals(futureDate.year));
      expect(scheduled.month, equals(futureDate.month));
      expect(scheduled.day, equals(futureDate.day));
      expect(scheduled.hour, equals(15));
      expect(scheduled.minute, equals(45));
    });

    test('calcularFechaProgramada defaults to 09:00 when horaNotificacion is null', () {
      final service = LocalNotificationService.instance;
      final futureDate = DateTime.now().add(const Duration(days: 3));

      final scheduled = service.calcularFechaProgramada(
        futureDate,
        null,
      );

      expect(scheduled, isNotNull);
      expect(scheduled!.hour, equals(9));
      expect(scheduled.minute, equals(0));
    });

    test('calcularFechaProgramada returns null for dates in the past', () {
      final service = LocalNotificationService.instance;
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      final scheduled = service.calcularFechaProgramada(
        pastDate,
        '10:00',
      );

      expect(scheduled, isNull);
    });

    test('RecordatorioTareaModel calculates antelation text accurately', () {
      final targetDate = DateTime(2026, 10, 15);
      final sameDayReminder = RecordatorioTareaModel(
        id: 'r-1',
        tareaId: 't-1',
        fechaNotificacion: DateTime(2026, 10, 15),
        horaNotificacion: '09:00',
      );
      expect(sameDayReminder.calcularAntelacionTexto(targetDate),
          equals('El mismo día (09:00)'));

      final oneDayBeforeReminder = RecordatorioTareaModel(
        id: 'r-2',
        tareaId: 't-1',
        fechaNotificacion: DateTime(2026, 10, 14),
        horaNotificacion: '18:00',
      );
      expect(oneDayBeforeReminder.calcularAntelacionTexto(targetDate),
          equals('El día antes (18:00)'));
    });
  });
}
