import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Frecuencia base de la regla de recurrencia.
enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  custom;

  String get label {
    switch (this) {
      case RecurrenceFrequency.daily:
        return 'Diaria';
      case RecurrenceFrequency.weekly:
        return 'Semanal';
      case RecurrenceFrequency.monthly:
        return 'Mensual';
      case RecurrenceFrequency.custom:
        return 'Personalizada';
    }
  }
}

/// Unidad de intervalo para recurrencia personalizada.
enum CustomIntervalUnit {
  days,
  weeks,
  months;

  String get label {
    switch (this) {
      case CustomIntervalUnit.days:
        return 'Días';
      case CustomIntervalUnit.weeks:
        return 'Semanas';
      case CustomIntervalUnit.months:
        return 'Meses';
    }
  }
}

/// Condición de fin de la regla de recurrencia.
enum RecurrenceEndType {
  never,
  untilDate,
  afterOccurrences;

  String get label {
    switch (this) {
      case RecurrenceEndType.never:
        return 'Sin fin';
      case RecurrenceEndType.untilDate:
        return 'Hasta fecha';
      case RecurrenceEndType.afterOccurrences:
        return 'Tras repeticiones';
    }
  }
}

/// Modelo inmutable de una regla de recurrencia para tareas y eventos periódicos.
@immutable
class RecurrenceRule {
  /// Frecuencia base (diaria, semanal, mensual, personalizada).
  final RecurrenceFrequency frequency;

  /// Intervalo numérico (cada cuántos días, semanas o meses se repite). Mínimo 1.
  final int interval;

  /// Días de la semana seleccionados para frecuencia semanal (1 = Lunes, ..., 7 = Domingo).
  final List<int> daysOfWeek;

  /// Unidad de tiempo si la frecuencia es personalizada.
  final CustomIntervalUnit customUnit;

  /// Tipo de condición de término (nunca, por fecha, por repeticiones).
  final RecurrenceEndType endType;

  /// Fecha límite de finalización (requerido si [endType] es [RecurrenceEndType.untilDate]).
  final DateTime? endDate;

  /// Número máximo de repeticiones (requerido si [endType] es [RecurrenceEndType.afterOccurrences]).
  final int? maxOccurrences;

  /// Contador de ocurrencias ya ejecutadas.
  final int occurrencesCount;

  const RecurrenceRule({
    this.frequency = RecurrenceFrequency.daily,
    this.interval = 1,
    this.daysOfWeek = const [],
    this.customUnit = CustomIntervalUnit.days,
    this.endType = RecurrenceEndType.never,
    this.endDate,
    this.maxOccurrences,
    this.occurrencesCount = 0,
  }) : assert(interval >= 1, 'El intervalo debe ser al menos 1');

  /// Constructor conveniente para regla diaria.
  const RecurrenceRule.daily({
    int interval = 1,
    RecurrenceEndType endType = RecurrenceEndType.never,
    DateTime? endDate,
    int? maxOccurrences,
    int occurrencesCount = 0,
  }) : this(
          frequency: RecurrenceFrequency.daily,
          interval: interval,
          daysOfWeek: const [],
          customUnit: CustomIntervalUnit.days,
          endType: endType,
          endDate: endDate,
          maxOccurrences: maxOccurrences,
          occurrencesCount: occurrencesCount,
        );

  /// Constructor conveniente para regla semanal.
  const RecurrenceRule.weekly({
    int interval = 1,
    List<int> daysOfWeek = const [],
    RecurrenceEndType endType = RecurrenceEndType.never,
    DateTime? endDate,
    int? maxOccurrences,
    int occurrencesCount = 0,
  }) : this(
          frequency: RecurrenceFrequency.weekly,
          interval: interval,
          daysOfWeek: daysOfWeek,
          customUnit: CustomIntervalUnit.weeks,
          endType: endType,
          endDate: endDate,
          maxOccurrences: maxOccurrences,
          occurrencesCount: occurrencesCount,
        );

  /// Constructor conveniente para regla mensual.
  const RecurrenceRule.monthly({
    int interval = 1,
    RecurrenceEndType endType = RecurrenceEndType.never,
    DateTime? endDate,
    int? maxOccurrences,
    int occurrencesCount = 0,
  }) : this(
          frequency: RecurrenceFrequency.monthly,
          interval: interval,
          daysOfWeek: const [],
          customUnit: CustomIntervalUnit.months,
          endType: endType,
          endDate: endDate,
          maxOccurrences: maxOccurrences,
          occurrencesCount: occurrencesCount,
        );

  /// Constructor conveniente para regla personalizada.
  const RecurrenceRule.custom({
    int interval = 1,
    CustomIntervalUnit customUnit = CustomIntervalUnit.days,
    List<int> daysOfWeek = const [],
    RecurrenceEndType endType = RecurrenceEndType.never,
    DateTime? endDate,
    int? maxOccurrences,
    int occurrencesCount = 0,
  }) : this(
          frequency: RecurrenceFrequency.custom,
          interval: interval,
          daysOfWeek: daysOfWeek,
          customUnit: customUnit,
          endType: endType,
          endDate: endDate,
          maxOccurrences: maxOccurrences,
          occurrencesCount: occurrencesCount,
        );

  /// Indica si la regla ya ha completado todas sus repeticiones permitidas.
  bool get hasEnded {
    if (endType == RecurrenceEndType.afterOccurrences && maxOccurrences != null) {
      return occurrencesCount >= maxOccurrences!;
    }
    return false;
  }

  /// Valida que la configuración de la regla sea internamente consistente.
  String? validate() {
    if (interval < 1) {
      return 'El intervalo debe ser como mínimo 1.';
    }
    if (endType == RecurrenceEndType.untilDate && endDate == null) {
      return 'Debes seleccionar una fecha límite de finalización.';
    }
    if (endType == RecurrenceEndType.afterOccurrences && (maxOccurrences == null || maxOccurrences! < 1)) {
      return 'Debes especificar al menos 1 repetición.';
    }
    return null;
  }

  /// Genera una descripción amigable y en lenguaje natural de la regla de recurrencia.
  String toHumanReadable() {
    final StringBuffer sb = StringBuffer();

    switch (frequency) {
      case RecurrenceFrequency.daily:
        sb.write(interval == 1 ? 'Cada día' : 'Cada $interval días');
        break;
      case RecurrenceFrequency.weekly:
        if (interval == 1) {
          sb.write('Cada semana');
        } else {
          sb.write('Cada $interval semanas');
        }
        if (daysOfWeek.isNotEmpty) {
          final sorted = List<int>.from(daysOfWeek)..sort();
          final daysStr = sorted.map(_weekdayToShortName).join(', ');
          sb.write(' los $daysStr');
        }
        break;
      case RecurrenceFrequency.monthly:
        sb.write(interval == 1 ? 'Cada mes' : 'Cada $interval meses');
        break;
      case RecurrenceFrequency.custom:
        sb.write('Cada $interval ${customUnit.label.toLowerCase()}');
        if (customUnit == CustomIntervalUnit.weeks && daysOfWeek.isNotEmpty) {
          final sorted = List<int>.from(daysOfWeek)..sort();
          final daysStr = sorted.map(_weekdayToShortName).join(', ');
          sb.write(' los $daysStr');
        }
        break;
    }

    switch (endType) {
      case RecurrenceEndType.never:
        sb.write(' (sin fin)');
        break;
      case RecurrenceEndType.untilDate:
        if (endDate != null) {
          sb.write(' hasta el ${endDate!.day}/${endDate!.month}/${endDate!.year}');
        }
        break;
      case RecurrenceEndType.afterOccurrences:
        if (maxOccurrences != null) {
          sb.write(' ($maxOccurrences repeticiones)');
        }
        break;
    }

    return sb.toString();
  }

  static String _weekdayToShortName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return '';
    }
  }

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    List<int>? daysOfWeek,
    CustomIntervalUnit? customUnit,
    RecurrenceEndType? endType,
    DateTime? endDate,
    bool clearEndDate = false,
    int? maxOccurrences,
    bool clearMaxOccurrences = false,
    int? occurrencesCount,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      customUnit: customUnit ?? this.customUnit,
      endType: endType ?? this.endType,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxOccurrences: clearMaxOccurrences ? null : (maxOccurrences ?? this.maxOccurrences),
      occurrencesCount: occurrencesCount ?? this.occurrencesCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency.name,
      'interval': interval,
      'days_of_week': daysOfWeek,
      'custom_unit': customUnit.name,
      'end_type': endType.name,
      'end_date': endDate?.toIso8601String(),
      'max_occurrences': maxOccurrences,
      'occurrences_count': occurrencesCount,
    };
  }

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values.firstWhere(
        (f) => f.name == json['frequency'],
        orElse: () => RecurrenceFrequency.daily,
      ),
      interval: json['interval'] as int? ?? 1,
      daysOfWeek: (json['days_of_week'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      customUnit: CustomIntervalUnit.values.firstWhere(
        (u) => u.name == json['custom_unit'],
        orElse: () => CustomIntervalUnit.days,
      ),
      endType: RecurrenceEndType.values.firstWhere(
        (e) => e.name == json['end_type'],
        orElse: () => RecurrenceEndType.never,
      ),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      maxOccurrences: json['max_occurrences'] as int?,
      occurrencesCount: json['occurrences_count'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecurrenceRule &&
        other.frequency == frequency &&
        other.interval == interval &&
        listEquals(other.daysOfWeek, daysOfWeek) &&
        other.customUnit == customUnit &&
        other.endType == endType &&
        other.endDate == endDate &&
        other.maxOccurrences == maxOccurrences &&
        other.occurrencesCount == occurrencesCount;
  }

  @override
  int get hashCode => Object.hash(
        frequency,
        interval,
        Object.hashAll(daysOfWeek),
        customUnit,
        endType,
        endDate,
        maxOccurrences,
        occurrencesCount,
      );

  @override
  String toString() => toHumanReadable();
}

/// Función pura de utilidad de dominio para calcular la siguiente fecha de ejecución
/// dada una [rule] de recurrencia y una [fromDate] base.
/// Retorna `null` si se ha alcanzado la condición de fin (fecha límite o máx repeticiones).
DateTime? getNextOccurrence(RecurrenceRule rule, DateTime fromDate) {
  // 1. Verificar si ya se alcanzó el límite por número de repeticiones
  if (rule.endType == RecurrenceEndType.afterOccurrences &&
      rule.maxOccurrences != null &&
      rule.occurrencesCount >= rule.maxOccurrences!) {
    return null;
  }

  // 2. Verificar si la fecha base ya superó la fecha límite
  if (rule.endType == RecurrenceEndType.untilDate && rule.endDate != null) {
    if (fromDate.isAfter(rule.endDate!)) {
      return null;
    }
  }

  DateTime next;

  // 3. Cálculo según frecuencia
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      next = fromDate.add(Duration(days: rule.interval));
      break;

    case RecurrenceFrequency.weekly:
      next = _calculateNextWeeklyOccurrence(rule, fromDate, rule.interval);
      break;

    case RecurrenceFrequency.monthly:
      next = _calculateNextMonthlyOccurrence(fromDate, rule.interval);
      break;

    case RecurrenceFrequency.custom:
      switch (rule.customUnit) {
        case CustomIntervalUnit.days:
          next = fromDate.add(Duration(days: rule.interval));
          break;
        case CustomIntervalUnit.weeks:
          next = _calculateNextWeeklyOccurrence(rule, fromDate, rule.interval);
          break;
        case CustomIntervalUnit.months:
          next = _calculateNextMonthlyOccurrence(fromDate, rule.interval);
          break;
      }
      break;
  }

  // 4. Verificar si la próxima fecha calculada sobrepasa la fecha límite configurada
  if (rule.endType == RecurrenceEndType.untilDate && rule.endDate != null) {
    if (next.isAfter(rule.endDate!)) {
      return null;
    }
  }

  return next;
}

DateTime _calculateNextWeeklyOccurrence(
  RecurrenceRule rule,
  DateTime fromDate,
  int weekInterval,
) {
  if (rule.daysOfWeek.isEmpty) {
    return fromDate.add(Duration(days: weekInterval * 7));
  }

  final sortedDays = List<int>.from(rule.daysOfWeek)..sort();

  // Buscar el siguiente día configurado dentro de la misma semana
  for (final day in sortedDays) {
    if (day > fromDate.weekday) {
      final daysToAdd = day - fromDate.weekday;
      return fromDate.add(Duration(days: daysToAdd));
    }
  }

  // Si no hay más días seleccionados en esta semana, saltar a la próxima semana según weekInterval
  final firstDayNextCycle = sortedDays.first;
  final daysUntilSunday = 7 - fromDate.weekday;
  final daysToAdd = daysUntilSunday + ((weekInterval - 1) * 7) + firstDayNextCycle;
  return fromDate.add(Duration(days: daysToAdd));
}

DateTime _calculateNextMonthlyOccurrence(DateTime fromDate, int monthInterval) {
  int targetYear = fromDate.year;
  int targetMonth = fromDate.month + monthInterval;

  while (targetMonth > 12) {
    targetYear++;
    targetMonth -= 12;
  }

  // Calcular el último día del mes destino para no desbordar (ej. 31 de enero -> 28/29 feb)
  final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
  final targetDay = math.min(fromDate.day, lastDayOfTargetMonth);

  return DateTime(
    targetYear,
    targetMonth,
    targetDay,
    fromDate.hour,
    fromDate.minute,
    fromDate.second,
    fromDate.millisecond,
    fromDate.microsecond,
  );
}
