import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/profile/domain/models/avatar_catalog.dart';

void main() {
  group('AvatarIconCatalog Tests', () {
    test('contains expected standard icons in catalog', () {
      expect(AvatarIconCatalog.icons.containsKey('person'), isTrue);
      expect(AvatarIconCatalog.icons.containsKey('bolt'), isTrue);
      expect(AvatarIconCatalog.icons.containsKey('rocket'), isTrue);
      expect(AvatarIconCatalog.icons.containsKey('shield'), isTrue);
      expect(AvatarIconCatalog.icons.containsKey('gamepad'), isTrue);
    });

    test('getIcon returns correct IconData for existing keys', () {
      expect(AvatarIconCatalog.getIcon('rocket'), equals(Icons.rocket_launch_rounded));
      expect(AvatarIconCatalog.getIcon('bolt'), equals(Icons.bolt_rounded));
      expect(AvatarIconCatalog.getIcon('gamepad'), equals(Icons.sports_esports_rounded));
    });

    test('getIcon returns fallback person icon for null or unknown keys', () {
      expect(AvatarIconCatalog.getIcon(null), equals(Icons.person_rounded));
      expect(AvatarIconCatalog.getIcon('non_existent_key_123'), equals(Icons.person_rounded));
    });
  });

  group('AvatarColorPalette Tests', () {
    test('contains preset hex colors', () {
      expect(AvatarColorPalette.presetColors.isNotEmpty, isTrue);
      expect(AvatarColorPalette.presetColors, contains('#00E5FF'));
      expect(AvatarColorPalette.presetColors, contains('#00E676'));
      expect(AvatarColorPalette.presetColors, contains('#FF3366'));
    });

    test('parseHex parses 6-digit hex string correctly', () {
      final color = AvatarColorPalette.parseHex('#00E5FF');
      expect(color, equals(const Color(0xFF00E5FF)));
    });

    test('parseHex parses 8-digit hex string correctly', () {
      final color = AvatarColorPalette.parseHex('FF00E676');
      expect(color, equals(const Color(0xFF00E676)));
    });

    test('parseHex returns fallback for null, empty or invalid hex strings', () {
      const fallback = Color(0xFFFF0000);
      expect(AvatarColorPalette.parseHex(null, fallback: fallback), equals(fallback));
      expect(AvatarColorPalette.parseHex('', fallback: fallback), equals(fallback));
      expect(AvatarColorPalette.parseHex('invalid_hex', fallback: fallback), equals(fallback));
    });
  });
}
