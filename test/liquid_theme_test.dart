import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/theme/liquid_theme.dart';

void main() {
  group('LiquidTheme Exact Palette & System Design Tests', () {
    test('Exact color tokens match requirements', () {
      expect(LiquidTheme.darkBackground, equals(const Color(0xFF101419)));
      expect(LiquidTheme.surfaceDark, equals(const Color(0xFF1A1F26)));
      expect(LiquidTheme.neumorphicDarkShadow, equals(const Color(0xFF0D1014)));
      expect(LiquidTheme.neumorphicLightHighlight, equals(const Color(0xFF222932)));
      expect(LiquidTheme.primaryLiquid, equals(const Color(0xFF7BB6FF)));
      expect(LiquidTheme.secondaryLilac, equals(const Color(0xFFBD93F9)));
      expect(LiquidTheme.textPrimary, equals(const Color(0xFFE6EDF3)));
      expect(LiquidTheme.textSecondary, equals(const Color(0xFF8B9BB4)));
      expect(LiquidTheme.structuralBorder, equals(const Color(0xFF8B9BB4)));
    });

    test('liquidPrimaryGradient matches 135deg and exact colors', () {
      final gradient = LiquidTheme.liquidPrimaryGradient;
      expect(gradient.colors.first, equals(const Color(0xFF7BB6FF)));
      expect(gradient.colors.last, equals(const Color(0xFFBD93F9)));
      expect(gradient.begin, equals(const Alignment(-0.707, -0.707)));
      expect(gradient.end, equals(const Alignment(0.707, 0.707)));
    });

    test('Glassmorphism tokens have 65-75% opacity and 20px blur', () {
      expect(LiquidTheme.glassBlur, equals(20.0));
      final surfaceAlpha = LiquidTheme.glassSurfaceColor.a;
      expect(surfaceAlpha, greaterThanOrEqualTo(0.65));
      expect(surfaceAlpha, lessThanOrEqualTo(0.75));
    });

    test('Neumorphic dual shadows use #0D1014 and #222932', () {
      final raisedShadows = LiquidTheme.neumorphicRaisedShadows();
      expect(raisedShadows.length, equals(2));
      // Dark outer shadow
      expect(raisedShadows[0].color,
          equals(const Color(0xFF0D1014).withValues(alpha: 0.9)));
      expect(raisedShadows[0].offset, equals(const Offset(4, 4)));
      // Light highlight
      expect(raisedShadows[1].color,
          equals(const Color(0xFF222932).withValues(alpha: 0.7)));
      expect(raisedShadows[1].offset, equals(const Offset(-3, -3)));
    });

    test('themeData is Dark Material 3 with darkBackground and surfaceDark', () {
      final theme = LiquidTheme.themeData;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF101419)));
      expect(theme.colorScheme.surface, equals(const Color(0xFF1A1F26)));
      expect(theme.colorScheme.primary, equals(const Color(0xFF7BB6FF)));
      expect(theme.colorScheme.secondary, equals(const Color(0xFFBD93F9)));
    });
  });
}
