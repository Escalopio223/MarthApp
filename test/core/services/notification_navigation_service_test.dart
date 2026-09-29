import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/services/notification_navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPayload Normalization Tests', () {
    test('NotificationPayload.fromData normalizes FCM map correctly', () {
      final fcmData = {
        'type': 'task_reminder',
        'tarea_id': 'tarea-uuid-1234',
        'entorno_id': 'entorno-uuid-5678',
      };

      final payload = NotificationPayload.fromData(
        data: fcmData,
        notificationTitle: 'Título de Prueba',
        notificationBody: 'Cuerpo de Prueba',
      );

      expect(payload.type, equals('task_reminder'));
      expect(payload.tareaId, equals('tarea-uuid-1234'));
      expect(payload.targetId, equals('tarea-uuid-1234'));
      expect(payload.entornoId, equals('entorno-uuid-5678'));
      expect(payload.title, equals('Título de Prueba'));
      expect(payload.body, equals('Cuerpo de Prueba'));
      expect(payload.isPlanner, isTrue);
      expect(payload.isFriends, isFalse);
      expect(payload.isEnvironment, isFalse);
    });

    test('NotificationPayload.fromData handles friend requests', () {
      final fcmData = {
        'type': 'friend_request',
        'request_id': 'req-999',
      };

      final payload = NotificationPayload.fromData(data: fcmData);
      expect(payload.type, equals('friend_request'));
      expect(payload.targetId, equals('req-999'));
      expect(payload.isFriends, isTrue);
      expect(payload.isPlanner, isFalse);
    });

    test('NotificationPayload.fromData handles environment invitations', () {
      final fcmData = {
        'type': 'environment_invitation',
        'entorno_id': 'env-888',
      };

      final payload = NotificationPayload.fromData(data: fcmData);
      expect(payload.type, equals('environment_invitation'));
      expect(payload.entornoId, equals('env-888'));
      expect(payload.isEnvironment, isTrue);
    });

    test('NotificationPayload.fromLocalPayload parses colon syntax (tarea:uuid)', () {
      final payload = NotificationPayload.fromLocalPayload('tarea:t-123');

      expect(payload.type, equals('tarea'));
      expect(payload.tareaId, equals('t-123'));
      expect(payload.targetId, equals('t-123'));
      expect(payload.isPlanner, isTrue);
    });

    test('NotificationPayload.fromLocalPayload parses colon syntax (evento:uuid)', () {
      final payload = NotificationPayload.fromLocalPayload('evento:e-456');

      expect(payload.type, equals('evento'));
      expect(payload.eventoId, equals('e-456'));
      expect(payload.targetId, equals('e-456'));
      expect(payload.isPlanner, isTrue);
    });

    test('NotificationPayload.fromLocalPayload parses JSON string', () {
      final jsonStr = jsonEncode({
        'type': 'reparto_sesion',
        'sesion_id': 's-789',
        'title': 'Reparto listo',
        'body': 'Tienes 3 tareas',
      });

      final payload = NotificationPayload.fromLocalPayload(jsonStr);

      expect(payload.type, equals('reparto_sesion'));
      expect(payload.sesionId, equals('s-789'));
      expect(payload.title, equals('Reparto listo'));
      expect(payload.body, equals('Tienes 3 tareas'));
      expect(payload.isPlanner, isTrue);
    });

    test('NotificationPayload.fromLocalPayload handles empty or null safely', () {
      final p1 = NotificationPayload.fromLocalPayload(null);
      expect(p1.type, isNull);
      expect(p1.targetId, isNull);

      final p2 = NotificationPayload.fromLocalPayload('');
      expect(p2.type, isNull);
    });
  });

  group('NotificationNavigationService Tests', () {
    test('setPendingPayload queues and consumePendingPayload drains it atomically', () {
      final service = NotificationNavigationService.instance;

      const payload = NotificationPayload(
        type: 'tarea',
        tareaId: 'tarea-abc',
      );

      service.setPendingPayload(payload);
      expect(service.pendingPayload, equals(payload));

      final consumed = service.consumePendingPayload();
      expect(consumed, equals(payload));
      expect(service.pendingPayload, isNull);

      // Subsequent consume returns null
      final secondConsume = service.consumePendingPayload();
      expect(secondConsume, isNull);
    });

    test('onNotificationTapped stream receives emitted events', () async {
      final service = NotificationNavigationService.instance;

      const payload = NotificationPayload(
        type: 'friend_request',
        targetId: 'req-456',
      );

      expectLater(
        service.onNotificationTapped,
        emits(predicate<NotificationPayload>((p) =>
            p.type == 'friend_request' && p.targetId == 'req-456')),
      );

      service.emitNotificationTapped(payload);
    });
  });
}
