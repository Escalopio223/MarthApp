import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/planificador/domain/models/recordatorio_tarea_model.dart';

void main() {
  group('RecordatorioTareaModel Unit Tests', () {
    test('Serialización y deserialización JSON sin hora fija', () {
      final model = RecordatorioTareaModel(
        id: 'rec_1',
        tareaId: 'tarea_123',
        fechaNotificacion: DateTime(2026, 9, 20),
        horaNotificacion: null,
        enviado: false,
      );

      final json = model.toJson();
      expect(json['tarea_id'], 'tarea_123');
      expect(json['fecha_notificacion'], '2026-09-20');
      expect(json['hora_notificacion'], isNull);
      expect(json['enviado'], false);

      final deserialized = RecordatorioTareaModel.fromJson(json);
      expect(deserialized.id, 'rec_1');
      expect(deserialized.tareaId, 'tarea_123');
      expect(deserialized.fechaNotificacion.year, 2026);
      expect(deserialized.fechaNotificacion.month, 9);
      expect(deserialized.fechaNotificacion.day, 20);
      expect(deserialized.horaNotificacion, isNull);
      expect(deserialized.tieneHoraFija, isFalse);
      expect(deserialized.textoDescriptivo, contains('Todo el día (cada 8h)'));
    });

    test('Serialización y deserialización JSON con hora fija', () {
      final model = RecordatorioTareaModel(
        id: 'rec_2',
        tareaId: 'tarea_456',
        fechaNotificacion: DateTime(2026, 9, 20),
        horaNotificacion: '10:30',
        enviado: true,
      );

      final json = model.toJson();
      expect(json['hora_notificacion'], '10:30');

      final deserialized = RecordatorioTareaModel.fromJson(json);
      expect(deserialized.tieneHoraFija, isTrue);
      expect(deserialized.horaNotificacion, '10:30');
      expect(deserialized.textoDescriptivo, contains('10:30'));
    });

    test('Cálculo de antelación relativo a fecha límite', () {
      final deadline = DateTime(2026, 9, 20, 18, 0);

      final mismoDia = RecordatorioTareaModel(
        id: '1',
        tareaId: 't',
        fechaNotificacion: DateTime(2026, 9, 20),
      );
      expect(mismoDia.calcularAntelacionTexto(deadline), contains('El mismo día'));

      final diaAntes = RecordatorioTareaModel(
        id: '2',
        tareaId: 't',
        fechaNotificacion: DateTime(2026, 9, 19),
        horaNotificacion: '09:00',
      );
      expect(diaAntes.calcularAntelacionTexto(deadline), contains('El día antes (09:00)'));

      final tresDiasAntes = RecordatorioTareaModel(
        id: '3',
        tareaId: 't',
        fechaNotificacion: DateTime(2026, 9, 17),
      );
      expect(tresDiasAntes.calcularAntelacionTexto(deadline), contains('3 días antes (cada 8h)'));

      final unaSemanaAntes = RecordatorioTareaModel(
        id: '4',
        tareaId: 't',
        fechaNotificacion: DateTime(2026, 9, 13),
      );
      expect(unaSemanaAntes.calcularAntelacionTexto(deadline), contains('1 semana antes (cada 8h)'));
    });

    test('copyWith modifica correctamente los atributos', () {
      final initial = RecordatorioTareaModel(
        id: 'rec_initial',
        tareaId: 't1',
        fechaNotificacion: DateTime(2026, 9, 20),
        horaNotificacion: '08:00',
      );

      final updated = initial.copyWith(
        clearHoraNotificacion: true,
        enviado: true,
      );

      expect(updated.id, 'rec_initial');
      expect(updated.horaNotificacion, isNull);
      expect(updated.tieneHoraFija, isFalse);
      expect(updated.enviado, isTrue);
    });

    test('Manejo de ultimoEnvioAt, createdAt y clearUltimoEnvioAt', () {
      final now = DateTime.now();
      final model = RecordatorioTareaModel(
        id: 'rec_audit',
        tareaId: 'tarea_audit',
        fechaNotificacion: DateTime(2026, 9, 21),
        ultimoEnvioAt: now,
        createdAt: now,
      );

      final json = model.toJson();
      expect(json['ultimo_envio_at'], isNotNull);
      expect(json['created_at'], isNotNull);

      final deserialized = RecordatorioTareaModel.fromJson(json);
      expect(deserialized.ultimoEnvioAt, isNotNull);
      expect(deserialized.createdAt, isNotNull);

      final cleared = deserialized.copyWith(clearUltimoEnvioAt: true);
      expect(cleared.ultimoEnvioAt, isNull);
    });
  });
}
