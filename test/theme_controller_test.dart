import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/theme/app_theme.dart';
import 'package:marth_app/core/theme/app_theme_config.dart';
import 'package:marth_app/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppThemes Dynamic Multi-Theme Engine Tests', () {
    test('Exactly 6 core themes exist (3 dark and 3 light)', () {
      expect(AppThemes.all.length, equals(6));
      expect(AppThemes.darkThemes.length, equals(3));
      expect(AppThemes.lightThemes.length, equals(3));
    });

    test('Midnight Slate has base exact tokens', () {
      final theme = AppThemes.midnightSlate;
      expect(theme.bgCanvas, equals(const Color(0xFF10141D)));
      expect(theme.bgSurface, equals(const Color(0xFF1A202C)));
      expect(theme.shadowDark, equals(const Color(0xFF0B0F15)));
      expect(theme.shadowLight, equals(const Color(0xFF2D3748)));
      expect(theme.accentPrimary, equals(const Color(0xFF38BDF8)));
      expect(theme.accentSecondary, equals(const Color(0xFF818CF8)));
      expect(theme.textPrimary, equals(const Color(0xFFF1F5F9)));
      expect(theme.textSecondary, equals(const Color(0xFF94A3B8)));
      expect(theme.isDark, isTrue);
    });

    test('Obsidian Amethyst has refined personality tokens', () {
      final theme = AppThemes.obsidianAmethyst;
      expect(theme.bgCanvas, equals(const Color(0xFF130D1E)));
      expect(theme.bgSurface, equals(const Color(0xFF1F1530)));
      expect(theme.shadowDark, equals(const Color(0xFF0A0610)));
      expect(theme.shadowLight, equals(const Color(0xFF2F204A)));
      expect(theme.accentPrimary, equals(const Color(0xFFA855F7)));
      expect(theme.accentSecondary, equals(const Color(0xFFEC4899)));
      expect(theme.textPrimary, equals(const Color(0xFFF3EEFA)));
      expect(theme.textSecondary, equals(const Color(0xFFA798BA)));
      expect(theme.isDark, isTrue);
    });

    test('Soft Clay has warm ceramic tokens', () {
      final theme = AppThemes.softClay;
      expect(theme.bgCanvas, equals(const Color(0xFFF5F2EE)));
      expect(theme.bgSurface, equals(const Color(0xFFFFFFFF)));
      expect(theme.shadowDark, equals(const Color(0xFFDED8D0)));
      expect(theme.shadowLight, equals(const Color(0xFFFFFFFF)));
      expect(theme.accentPrimary, equals(const Color(0xFFD95D39)));
      expect(theme.accentSecondary, equals(const Color(0xFFF28E2B)));
      expect(theme.textPrimary, equals(const Color(0xFF261E1A)));
      expect(theme.textSecondary, equals(const Color(0xFF7A6B63)));
      expect(theme.isDark, isFalse);
    });

    test('Sage Botanical has fresh botanical tokens', () {
      final theme = AppThemes.sageBotanical;
      expect(theme.bgCanvas, equals(const Color(0xFFF0F5F2)));
      expect(theme.bgSurface, equals(const Color(0xFFFFFFFF)));
      expect(theme.shadowDark, equals(const Color(0xFFCFDDD4)));
      expect(theme.shadowLight, equals(const Color(0xFFFFFFFF)));
      expect(theme.accentPrimary, equals(const Color(0xFF15803D)));
      expect(theme.accentSecondary, equals(const Color(0xFF22C55E)));
      expect(theme.textPrimary, equals(const Color(0xFF0F261B)));
      expect(theme.textSecondary, equals(const Color(0xFF537060)));
      expect(theme.isDark, isFalse);
    });

    test('Carbon Eclipse has monochromatic dark tokens', () {
      final theme = AppThemes.carbonEclipse;
      expect(theme.bgCanvas, equals(const Color(0xFF121214)));
      expect(theme.bgSurface, equals(const Color(0xFF1C1D21)));
      expect(theme.shadowDark, equals(const Color(0xFF0A0A0B)));
      expect(theme.shadowLight, equals(const Color(0xFF2B2C33)));
      expect(theme.accentPrimary, equals(const Color(0xFFF8FAFC)));
      expect(theme.accentSecondary, equals(const Color(0xFF94A3B8)));
      expect(theme.textPrimary, equals(const Color(0xFFF8FAFC)));
      expect(theme.textSecondary, equals(const Color(0xFF94A3B8)));
      expect(theme.isDark, isTrue);
    });

    test('Porcelain Chalk has monochromatic light tokens', () {
      final theme = AppThemes.porcelainChalk;
      expect(theme.bgCanvas, equals(const Color(0xFFF4F5F7)));
      expect(theme.bgSurface, equals(const Color(0xFFFFFFFF)));
      expect(theme.shadowDark, equals(const Color(0xFFD4D7DE)));
      expect(theme.shadowLight, equals(const Color(0xFFFFFFFF)));
      expect(theme.accentPrimary, equals(const Color(0xFF111827)));
      expect(theme.accentSecondary, equals(const Color(0xFF374151)));
      expect(theme.textPrimary, equals(const Color(0xFF111827)));
      expect(theme.textSecondary, equals(const Color(0xFF4B5563)));
      expect(theme.isDark, isFalse);
    });

    test('All themes support 135deg action gradients', () {
      for (final theme in AppThemes.all) {
        final gradient = theme.actionGradient;
        expect(gradient.begin, equals(const Alignment(-0.707, -0.707)));
        expect(gradient.end, equals(const Alignment(0.707, 0.707)));
      }
    });
  });

  group('ThemeController and Persistence Tests', () {
    test('ThemeController defaults to Midnight Slate', () {
      final controller = ThemeController();
      expect(controller.currentThemeId, equals(ThemeId.midnightSlate));
      expect(controller.isDark, isTrue);
    });

    test('setTheme updates theme, notifier, and global AppTheme facade',
        () async {
      final controller = ThemeController();
      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.setTheme(AppThemes.obsidianAmethyst);

      expect(notified, isTrue);
      expect(controller.currentThemeId, equals(ThemeId.obsidianAmethyst));
      expect(AppTheme.current.id, equals(ThemeId.obsidianAmethyst));
      expect(AppTheme.primaryAccent,
          equals(AppThemes.obsidianAmethyst.accentPrimary));
    });

    test('setThemeById switches to Light Theme correctly', () async {
      final controller = ThemeController();
      await controller.setThemeById(ThemeId.softClay);

      expect(controller.currentThemeId, equals(ThemeId.softClay));
      expect(controller.isDark, isFalse);
      expect(AppTheme.current.isDark, isFalse);
      expect(AppTheme.textPrimary, equals(const Color(0xFF261E1A)));
    });

    test('AppThemes.fromId handles valid and invalid IDs safely', () {
      expect(AppThemes.fromId('softClay').id, equals(ThemeId.softClay));
      expect(AppThemes.fromId('invalidThemeId').id,
          equals(ThemeId.midnightSlate));
    });
  });
}
