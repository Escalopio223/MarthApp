import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/profile/domain/models/avatar_data.dart';
import 'package:marth_app/features/profile/domain/models/profile_model.dart';

void main() {
  group('AvatarData & AvatarType Domain Tests', () {
    test('AvatarType serializes and deserializes correctly', () {
      expect(AvatarType.fromString('initials'), equals(AvatarType.initials));
      expect(AvatarType.fromString('icon'), equals(AvatarType.icon));
      expect(AvatarType.fromString('image'), equals(AvatarType.image));
      expect(AvatarType.fromString('unknown'), equals(AvatarType.initials));
      expect(AvatarType.fromString(null), equals(AvatarType.initials));

      expect(AvatarType.initials.toDbString(), equals('initials'));
      expect(AvatarType.icon.toDbString(), equals('icon'));
      expect(AvatarType.image.toDbString(), equals('image'));
    });

    test('AvatarData.initials creates consistent state and db map', () {
      const avatar = AvatarData.initials();
      expect(avatar.type, equals(AvatarType.initials));
      expect(avatar.imageUrl, isNull);
      expect(avatar.iconKey, isNull);
      expect(avatar.bgColorHex, isNull);

      final dbMap = avatar.toDbMap();
      expect(dbMap['avatar_type'], equals('initials'));
      expect(dbMap['avatar_url'], isNull);
      expect(dbMap['avatar_icon'], isNull);
      expect(dbMap['avatar_bg_color'], isNull);
    });

    test('AvatarData.icon creates consistent state and nullifies imageUrl in db map', () {
      const avatar = AvatarData.icon(iconKey: 'gamepad', bgColorHex: '#00E5FF');
      expect(avatar.type, equals(AvatarType.icon));
      expect(avatar.iconKey, equals('gamepad'));
      expect(avatar.bgColorHex, equals('#00E5FF'));
      expect(avatar.imageUrl, isNull);

      final dbMap = avatar.toDbMap();
      expect(dbMap['avatar_type'], equals('icon'));
      expect(dbMap['avatar_icon'], equals('gamepad'));
      expect(dbMap['avatar_bg_color'], equals('#00E5FF'));
      expect(dbMap['avatar_url'], isNull);
    });

    test('AvatarData.image creates consistent state and nullifies icon fields in db map', () {
      const avatar = AvatarData.image(imageUrl: 'https://cdn.supabase.com/avatars/user1.png');
      expect(avatar.type, equals(AvatarType.image));
      expect(avatar.imageUrl, equals('https://cdn.supabase.com/avatars/user1.png'));
      expect(avatar.iconKey, isNull);
      expect(avatar.bgColorHex, isNull);

      final dbMap = avatar.toDbMap();
      expect(dbMap['avatar_type'], equals('image'));
      expect(dbMap['avatar_url'], equals('https://cdn.supabase.com/avatars/user1.png'));
      expect(dbMap['avatar_icon'], isNull);
      expect(dbMap['avatar_bg_color'], isNull);
    });

    test('AvatarData.fromDb correctly recovers state from database JSON payload', () {
      final iconAvatar = AvatarData.fromDb(
        typeStr: 'icon',
        icon: 'rocket',
        bgColor: '#FF3366',
        url: null,
      );
      expect(iconAvatar.type, equals(AvatarType.icon));
      expect(iconAvatar.iconKey, equals('rocket'));
      expect(iconAvatar.bgColorHex, equals('#FF3366'));

      final imageAvatar = AvatarData.fromDb(
        typeStr: 'image',
        url: 'https://storage/photo.jpg',
        icon: null,
        bgColor: null,
      );
      expect(imageAvatar.type, equals(AvatarType.image));
      expect(imageAvatar.imageUrl, equals('https://storage/photo.jpg'));
    });
  });

  group('ProfileModel Tests', () {
    test('ProfileModel serializes and deserializes with AvatarData and birthDate', () {
      final now = DateTime.now();
      final birthDate = DateTime(1992, 10, 15);
      final profile = ProfileModel(
        id: 'user_123',
        username: 'arturo_dev',
        avatarData: const AvatarData.icon(iconKey: 'bolt', bgColorHex: '#BD00FF'),
        birthDate: birthDate,
        updatedAt: now,
      );

      final json = profile.toJson();
      expect(json['id'], equals('user_123'));
      expect(json['username'], equals('arturo_dev'));
      expect(json['avatar_type'], equals('icon'));
      expect(json['avatar_icon'], equals('bolt'));
      expect(json['avatar_bg_color'], equals('#BD00FF'));
      expect(json['avatar_url'], isNull);
      expect(json['birth_date'], equals('1992-10-15'));
      expect(json.containsKey('birthday'), isFalse);
      expect(json.containsKey('cumpleanos'), isFalse);

      final deserialized = ProfileModel.fromJson(json);
      expect(deserialized.id, equals('user_123'));
      expect(deserialized.username, equals('arturo_dev'));
      expect(deserialized.avatarType, equals(AvatarType.icon));
      expect(deserialized.avatarIcon, equals('bolt'));
      expect(deserialized.avatarBgColor, equals('#BD00FF'));
      expect(deserialized.birthDate, equals(birthDate));
      // Compatibilidad con getters deprecados
      // ignore: deprecated_member_use_from_same_package
      expect(deserialized.birthday, equals(birthDate));
      // ignore: deprecated_member_use_from_same_package
      expect(deserialized.fechaNacimiento, equals(birthDate));
    });

    test('ProfileModel deserializes legacy fallback fields without data loss', () {
      final jsonLegacyBirthday = {
        'id': 'u_legacy_1',
        'username': 'legacy_user',
        'avatar_type': 'initials',
        'birthday': '1990-04-12',
        'updated_at': DateTime.now().toIso8601String(),
      };
      final profileFromBirthday = ProfileModel.fromJson(jsonLegacyBirthday);
      expect(profileFromBirthday.birthDate, equals(DateTime(1990, 4, 12)));

      final jsonLegacyFechaNac = {
        'id': 'u_legacy_2',
        'username': 'legacy_user_2',
        'avatar_type': 'initials',
        'fecha_nacimiento': '1988-11-23',
        'updated_at': DateTime.now().toIso8601String(),
      };
      final profileFromFechaNac = ProfileModel.fromJson(jsonLegacyFechaNac);
      expect(profileFromFechaNac.birthDate, equals(DateTime(1988, 11, 23)));
    });

    test('ProfileModel copyWith updates fields correctly including birthDate', () {
      final profile = ProfileModel(
        id: 'u1',
        username: 'test_user',
        avatarData: const AvatarData.initials(),
        birthDate: DateTime(1995, 1, 1),
        updatedAt: DateTime.now(),
      );

      final newBirthDate = DateTime(1996, 2, 2);
      final updated = profile.copyWith(
        username: 'new_name',
        avatarData: const AvatarData.image(imageUrl: 'https://new_image.png'),
        birthDate: newBirthDate,
      );

      expect(updated.id, equals('u1'));
      expect(updated.username, equals('new_name'));
      expect(updated.avatarType, equals(AvatarType.image));
      expect(updated.avatarUrl, equals('https://new_image.png'));
      expect(updated.birthDate, equals(newBirthDate));
    });
  });
}
