import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/services/notification_id_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NotificationIdRegistry.instance.initialize();
    await NotificationIdRegistry.instance.clearAll();
  });

  group('NotificationIdRegistry Tests', () {
    test('Generates sequential unique 32-bit IDs starting at 1', () async {
      final id1 = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-1', 'tarea-1');
      final id2 = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-2', 'tarea-1');
      final id3 = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-3', 'tarea-2');

      expect(id1, equals(1));
      expect(id2, equals(2));
      expect(id3, equals(3));
    });

    test('Reuses existing ID when querying same reminder ID', () async {
      final id1 = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-100', 'tarea-10');
      final id2 = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-100', 'tarea-10');

      expect(id1, equals(id2));
    });

    test('Indexes and removes all IDs by entity correctly', () async {
      await NotificationIdRegistry.instance.obtenerOCrearId('rem-a', 'entity-1');
      await NotificationIdRegistry.instance.obtenerOCrearId('rem-b', 'entity-1');
      await NotificationIdRegistry.instance.obtenerOCrearId('rem-c', 'entity-2');

      final removedEntity1 = await NotificationIdRegistry.instance
          .obtenerYRemoverIdsPorEntidad('entity-1');

      expect(removedEntity1.length, equals(2));
      expect(removedEntity1, contains(1));
      expect(removedEntity1, contains(2));

      // entity-2 should remain untouched
      final idRemC =
          await NotificationIdRegistry.instance.obtenerId('rem-c');
      expect(idRemC, equals(3));

      // Further removal on entity-1 returns empty
      final empty = await NotificationIdRegistry.instance
          .obtenerYRemoverIdsPorEntidad('entity-1');
      expect(empty, isEmpty);
    });

    test('Removes individual reminder ID correctly', () async {
      final id = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-single', 'entity-x');
      final removed =
          await NotificationIdRegistry.instance.removerId('rem-single');

      expect(removed, equals(id));
      expect(
          await NotificationIdRegistry.instance.obtenerId('rem-single'), isNull);
    });

    test('Overflow cycle resets from maxSafeInt32 - 1 to 1 and never yields 0',
        () async {
      // Set sequence at boundary (maxSafeInt32 - 1 = 2147483646)
      SharedPreferences.setMockInitialValues({
        'notif_seq_id': NotificationIdRegistry.maxSafeInt32 - 1,
      });
      await NotificationIdRegistry.instance.initialize();

      // (2147483646 + 1) % 2147483647 = 0 -> wraps to 1
      final idWrap = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-wrap', 'entity-wrap');
      expect(idWrap, equals(1));
      expect(idWrap, isNot(equals(0)));

      // Subsequent call advances to 2
      final idNext = await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-next', 'entity-next');
      expect(idNext, equals(2));
    });

    test('State persists across re-initialization', () async {
      await NotificationIdRegistry.instance
          .obtenerOCrearId('rem-persist', 'entity-p');

      // Re-initialize registry (simulating app restart)
      await NotificationIdRegistry.instance.initialize();

      final id =
          await NotificationIdRegistry.instance.obtenerId('rem-persist');
      expect(id, equals(1));
    });
  });
}
