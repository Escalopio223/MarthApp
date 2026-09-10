import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/settings/domain/friend_code_manager.dart';

void main() {
  group('FriendCodeManager Tests', () {
    test('Initial state should be empty and inactive', () {
      final manager = FriendCodeManager();
      expect(manager.currentCode, isNull);
      expect(manager.hasActiveCode, isFalse);
      expect(manager.remainingSeconds, equals(0));
      expect(manager.isExpired, isFalse);
      expect(manager.addedFriends, isEmpty);
      manager.dispose();
    });

    test('generateNewCode creates valid code and starts 60s timer', () {
      final manager = FriendCodeManager();
      manager.generateNewCode();

      expect(manager.currentCode, isNotNull);
      expect(manager.currentCode!.startsWith('MARTH-'), isTrue);
      expect(manager.currentCode!.length, equals(10)); // MARTH-XXXX = 10 chars
      expect(manager.hasActiveCode, isTrue);
      expect(manager.remainingSeconds, equals(60));
      expect(manager.isExpired, isFalse);
      expect(manager.progress, equals(1.0));

      manager.dispose();
    });

    test('addFriend adds unique code and prevents duplicates', () async {
      final manager = FriendCodeManager();

      final added = await manager.addFriend('MARTH-1234');
      expect(added, isTrue);
      expect(manager.addedFriends, contains('MARTH-1234'));

      // Trying to add the same code again should throw
      expect(
        () async => await manager.addFriend('MARTH-1234'),
        throwsException,
      );

      manager.dispose();
    });
  });
}
