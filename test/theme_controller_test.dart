import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/theme/app_theme_config.dart';
import 'package:marth_app/core/theme/liquid_theme.dart';
import 'package:marth_app/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppThemes Dynamic Multi-Theme Engine Tests', () {
    test('Exactly 10 themes exist (5 dark and 5 light)', () {
      expect(AppThemes.all.length, equals(10));
      expect(AppThemes.darkThemes.length, equals(5));
      expect(AppThemes.lightThemes.length, equals(5));
    });

    test('Midnight Blue has base exact tokens', () {
      final theme = AppThemes.midnightBlue;
      expect(theme.bgCanvas, equals(const Color(0xFF101419)));
      expect(theme.bgSurface, equals(const Color(0xFF1A1F26)));
      expect(theme.shadowDark, equals(const Color(0xFF0D1014)));
      expect(theme.shadowLight, equals(const Color(0xFF222932)));
      expect(theme.accentPrimary, equals(const Color(0xFF7BB6FF)));
      expect(theme.accentSecondary, equals(const Color(0xFFBD93F9)));
      expect(theme.textPrimary, equals(const Color(0xFFE6EDF3)));
      expect(theme.textSecondary, equals(const Color(0xFF8B9BB4)));
      expect(theme.isDark, isTrue);
    });

    test('Cyber Emerald has refined non-strident tokens', () {
      final theme = AppThemes.cyberEmerald;
      expect(theme.bgCanvas, equals(const Color(0xFF0C1715)));
      expect(theme.bgSurface, equals(const Color(0xFF142421)));
      expect(theme.shadowDark, equals(const Color(0xFF060D0B)));
      expect(theme.shadowLight, equals(const Color(0xFF1E3530)));
      expect(theme.accentPrimary, equals(const Color(0xFF10B981)));
      expect(theme.accentSecondary, equals(const Color(0xFF06B6D4)));
      expect(theme.textPrimary, equals(const Color(0xFFECFDF5)));
      expect(theme.textSecondary, equals(const Color(0xFF80A79E)));
    });

    test('Obsidian Crimson has refined non-strident tokens', () {
      final theme = AppThemes.obsidianCrimson;
      expect(theme.bgCanvas, equals(const Color(0xFF130C0E)));
      expect(theme.bgSurface, equals(const Color(0xFF1F1317)));
      expect(theme.shadowDark, equals(const Color(0xFF0A0607)));
      expect(theme.shadowLight, equals(const Color(0xFF2C1C21)));
      expect(theme.accentPrimary, equals(const Color(0xFFE11D48)));
      expect(theme.accentSecondary, equals(const Color(0xFF9F1239)));
      expect(theme.textPrimary, equals(const Color(0xFFFDF2F4)));
      expect(theme.textSecondary, equals(const Color(0xFFA68087)));
    });

    test('Deep Amethyst has exact specification tokens', () {
      final theme = AppThemes.deepAmethyst;
      expect(theme.bgCanvas, equals(const Color(0xFF100C19)));
      expect(theme.bgSurface, equals(const Color(0xFF1B152B)));
      expect(theme.shadowDark, equals(const Color(0xFF09060E)));
      expect(theme.shadowLight, equals(const Color(0xFF281F3E)));
      expect(theme.accentPrimary, equals(const Color(0xFFA855F7)));
      expect(theme.accentSecondary, equals(const Color(0xFFEC4899)));
      expect(theme.textPrimary, equals(const Color(0xFFF3EEFA)));
      expect(theme.textSecondary, equals(const Color(0xFF9B8EA9)));
    });

    test('Eclipse Carbon has exact specification tokens', () {
      final theme = AppThemes.eclipseCarbon;
      expect(theme.bgCanvas, equals(const Color(0xFF121214)));
      expect(theme.bgSurface, equals(const Color(0xFF1C1D21)));
      expect(theme.shadowDark, equals(const Color(0xFF0A0A0B)));
      expect(theme.shadowLight, equals(const Color(0xFF292A30)));
      expect(theme.accentPrimary, equals(const Color(0xFFE2E8F0)));
      expect(theme.accentSecondary, equals(const Color(0xFF94A3B8)));
      expect(theme.textPrimary, equals(const Color(0xFFF8FAFC)));
      expect(theme.textSecondary, equals(const Color(0xFF64748B)));
    });

    test('Frosted Glacier has exact specification tokens and light shadows', () {
      final theme = AppThemes.frostedGlacier;
      expect(theme.bgCanvas, equals(const Color(0xFFF0F5FA)));
      expect(theme.bgSurface, equals(const Color(0xFFFFFFFF)));
      expect(theme.shadowDark, equals(const Color(0xFFD2DFEE)));
      expect(theme.shadowLight, equals(const Color(0xFFFFFFFF)));
      expect(theme.accentPrimary, equals(const Color(0xFF0077E6)));
      expect(theme.accentSecondary, equals(const Color(0xFF00B4D8)));
      expect(theme.textPrimary, equals(const Color(0xFF0F1E2E)));
      expect(theme.textSecondary, equals(const Color(0xFF5A738E)));
      expect(theme.isDark, isFalse);

      // Verify 16px blur on light neumorphism to avoid muddy look
      final raisedShadows = theme.neumorphicRaisedShadows();
      expect(raisedShadows[0].blurRadius, equals(16.0));
      expect(raisedShadows[0].offset, equals(const Offset(8, 8)));
      expect(raisedShadows[1].blurRadius, equals(16.0));
      expect(raisedShadows[1].offset, equals(const Offset(-8, -8)));
    });

    test('All themes support 135deg liquid gradients', () {
      for (final theme in AppThemes.all) {
        final gradient = theme.liquidPrimaryGradient;
        expect(gradient.colors.first, equals(theme.accentPrimary));
        expect(gradient.colors.last, equals(theme.accentSecondary));
        expect(gradient.begin, equals(const Alignment(-0.707, -0.707)));
        expect(gradient.end, equals(const Alignment(0.707, 0.707)));
      }
    });

    test('Glass surface opacity is between 65% and 75% for all themes', () {
      for (final theme in AppThemes.all) {
        final alpha = theme.glassSurfaceColor.a;
        expect(alpha, greaterThanOrEqualTo(0.65));
        expect(alpha, lessThanOrEqualTo(0.75));
        expect(theme.glassBlur, equals(20.0));
      }
    });
  });

  group('ThemeController and Persistence Tests', () {
    test('ThemeController defaults to Midnight Blue', () {
      final controller = ThemeController();
      expect(controller.currentThemeId, equals(ThemeId.midnightBlue));
      expect(controller.isDark, isTrue);
    });

    test('setTheme updates theme, notifier, and global LiquidTheme facade', () async {
      final controller = ThemeController();
      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.setTheme(AppThemes.cyberEmerald);

      expect(notified, isTrue);
      expect(controller.currentThemeId, equals(ThemeId.cyberEmerald));
      expect(LiquidTheme.current.id, equals(ThemeId.cyberEmerald));
      expect(LiquidTheme.primaryLiquid, equals(AppThemes.cyberEmerald.accentPrimary));
    });

    test('setThemeById switches to Light Theme correctly', () async {
      final controller = ThemeController();
      await controller.setThemeById(ThemeId.frostedGlacier);

      expect(controller.currentThemeId, equals(ThemeId.frostedGlacier));
      expect(controller.isDark, isFalse);
      expect(LiquidTheme.current.isDark, isFalse);
      expect(LiquidTheme.textPrimary, equals(const Color(0xFF0F1E2E)));
    });

    test('AppThemes.fromId handles valid and invalid IDs safely', () {
      expect(AppThemes.fromId('roseQuartz').id, equals(ThemeId.roseQuartz));
      expect(AppThemes.fromId('invalidThemeId').id, equals(ThemeId.midnightBlue));
    });
  });
}
