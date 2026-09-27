import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/planificador/domain/models/recurrence_rule.dart';

void main() {
  group('RecurrenceRule - getNextOccurrence', () {
    test('Diaria: Calcula correctamente el siguiente día con intervalo = 1', () {
      const rule = RecurrenceRule.daily(interval: 1);
      final fromDate = DateTime(2026, 9, 27, 10, 0);

      final next = getNextOccurrence(rule, fromDate);

      expect(next, isNotNull);
      expect(next, DateTime(2026, 9, 28, 10, 0));
    });

    test('Diaria: Calcula correctamente con intervalo = 3', () {
      const rule = RecurrenceRule.daily(interval: 3);
      final fromDate = DateTime(2026, 9, 27, 15, 30);

      final next = getNextOccurrence(rule, fromDate);

      expect(next, isNotNull);
      expect(next, DateTime(2026, 9, 30, 15, 30));
    });

    test('Semanal con días específicos: Avanza al siguiente día configurado en la misma semana', () {
      // 2026-09-28 es Lunes (weekday = 1)
      final monday = DateTime(2026, 9, 28, 9, 0);
      expect(monday.weekday, DateTime.monday);

      // Regla: Lunes (1) y Jueves (4)
      const rule = RecurrenceRule.weekly(
        interval: 1,
        daysOfWeek: [DateTime.monday, DateTime.thursday],
      );

      final next = getNextOccurrence(rule, monday);

      // Debe caer en el Jueves 2026-10-01
      expect(next, isNotNull);
      expect(next, DateTime(2026, 10, 1, 9, 0));
      expect(next!.weekday, DateTime.thursday);
    });

    test('Semanal con días específicos: Salta a la siguiente semana si no quedan días disponibles', () {
      // 2026-10-01 es Jueves (weekday = 4)
      final thursday = DateTime(2026, 10, 1, 9, 0);
      expect(thursday.weekday, DateTime.thursday);

      // Regla: Lunes (1) y Jueves (4) con intervalo 1 semana
      const rule = RecurrenceRule.weekly(
        interval: 1,
        daysOfWeek: [DateTime.monday, DateTime.thursday],
      );

      final next = getNextOccurrence(rule, thursday);

      // Debe caer en el siguiente Lunes: 2026-10-05
      expect(next, isNotNull);
      expect(next, DateTime(2026, 10, 5, 9, 0));
      expect(next!.weekday, DateTime.monday);
    });

    test('Semanal con intervalo > 1: Salta el número correcto de semanas al reiniciar ciclo', () {
      // 2026-10-01 es Jueves (weekday = 4)
      final thursday = DateTime(2026, 10, 1, 9, 0);

      // Regla cada 2 semanas los Lunes y Jueves
      const rule = RecurrenceRule.weekly(
        interval: 2,
        daysOfWeek: [DateTime.monday, DateTime.thursday],
      );

      final next = getNextOccurrence(rule, thursday);

      // Debe saltar 1 semana y caer en el Lunes 2026-10-12
      expect(next, isNotNull);
      expect(next, DateTime(2026, 10, 12, 9, 0));
      expect(next!.weekday, DateTime.monday);
    });

    test('Semanal sin días configurados: Avanza 7 * intervalo días', () {
      final date = DateTime(2026, 9, 27, 12, 0);
      const rule = RecurrenceRule.weekly(interval: 2);

      final next = getNextOccurrence(rule, date);

      expect(next, isNotNull);
      expect(next, DateTime(2026, 10, 11, 12, 0));
    });

    test('Mensual: Avanza 1 mes manteniendo el mismo día', () {
      final date = DateTime(2026, 4, 15, 18, 0);
      const rule = RecurrenceRule.monthly(interval: 1);

      final next = getNextOccurrence(rule, date);

      expect(next, isNotNull);
      expect(next, DateTime(2026, 5, 15, 18, 0));
    });

    test('Mensual: Respeta el último día del mes en desbordamientos (ej. 31 de Enero)', () {
      // 2025 no es bisiesto, Febrero tiene 28 días
      final date = DateTime(2025, 1, 31, 14, 0);
      const rule = RecurrenceRule.monthly(interval: 1);

      final next = getNextOccurrence(rule, date);

      expect(next, isNotNull);
      expect(next, DateTime(2025, 2, 28, 14, 0));
    });

    test('Mensual: Maneja correctamente el cambio de año', () {
      final date = DateTime(2026, 11, 20, 10, 0);
      const rule = RecurrenceRule.monthly(interval: 2);

      final next = getNextOccurrence(rule, date);

      expect(next, isNotNull);
      expect(next, DateTime(2027, 1, 20, 10, 0));
    });

    test('Personalizada: Soporta unidades en días, semanas y meses', () {
      final date = DateTime(2026, 9, 27, 8, 0);

      // Cada 10 días
      const ruleDays = RecurrenceRule.custom(
        interval: 10,
        customUnit: CustomIntervalUnit.days,
      );
      expect(getNextOccurrence(ruleDays, date), DateTime(2026, 10, 7, 8, 0));

      // Cada 3 meses
      const ruleMonths = RecurrenceRule.custom(
        interval: 3,
        customUnit: CustomIntervalUnit.months,
      );
      expect(getNextOccurrence(ruleMonths, date), DateTime(2026, 12, 27, 8, 0));
    });

    test('Condición de fin: Retorna null cuando se alcanza maxOccurrences', () {
      final date = DateTime(2026, 9, 27, 10, 0);

      // Aún no ha terminado (4 de 5)
      const ruleInProgress = RecurrenceRule.daily(
        interval: 1,
        endType: RecurrenceEndType.afterOccurrences,
        maxOccurrences: 5,
        occurrencesCount: 4,
      );
      expect(getNextOccurrence(ruleInProgress, date), isNotNull);

      // Ya completó las repeticiones (5 de 5)
      const ruleFinished = RecurrenceRule.daily(
        interval: 1,
        endType: RecurrenceEndType.afterOccurrences,
        maxOccurrences: 5,
        occurrencesCount: 5,
      );
      expect(getNextOccurrence(ruleFinished, date), isNull);
    });

    test('Condición de fin: Retorna null si la siguiente fecha supera endDate', () {
      final date = DateTime(2026, 9, 27, 10, 0);
      final endDate = DateTime(2026, 9, 29, 23, 59);

      // Intervalo 1: caerá el 28 (antes de endDate) -> válido
      final ruleValid = RecurrenceRule.daily(
        interval: 1,
        endType: RecurrenceEndType.untilDate,
        endDate: endDate,
      );
      expect(getNextOccurrence(ruleValid, date), DateTime(2026, 9, 28, 10, 0));

      // Intervalo 5: caería el 2 de Octubre (después de endDate) -> null
      final ruleExceeded = RecurrenceRule.daily(
        interval: 5,
        endType: RecurrenceEndType.untilDate,
        endDate: endDate,
      );
      expect(getNextOccurrence(ruleExceeded, date), isNull);
    });
  });

  group('RecurrenceRule - Validación y formato legible', () {
    test('toHumanReadable describe correctamente distintas configuraciones', () {
      const dailyRule = RecurrenceRule.daily(interval: 1);
      expect(dailyRule.toHumanReadable(), contains('Cada día (sin fin)'));

      const weeklyRule = RecurrenceRule.weekly(
        interval: 2,
        daysOfWeek: [DateTime.monday, DateTime.friday],
      );
      expect(weeklyRule.toHumanReadable(), contains('Cada 2 semanas los Lunes, Viernes'));

      final untilDate = DateTime(2026, 12, 31);
      final untilRule = RecurrenceRule.daily(
        interval: 1,
        endType: RecurrenceEndType.untilDate,
        endDate: untilDate,
      );
      expect(untilRule.toHumanReadable(), contains('hasta el 31/12/2026'));
    });

    test('validate detecta reglas inválidas', () {
      const validRule = RecurrenceRule.daily();
      expect(validRule.validate(), isNull);

      const invalidDateRule = RecurrenceRule.daily(
        endType: RecurrenceEndType.untilDate,
        endDate: null,
      );
      expect(invalidDateRule.validate(), isNotNull);

      const invalidCountRule = RecurrenceRule.daily(
        endType: RecurrenceEndType.afterOccurrences,
        maxOccurrences: 0,
      );
      expect(invalidCountRule.validate(), isNotNull);
    });
  });
}
