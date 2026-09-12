import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/theme/app_theme.dart';

void main() {
  group('AppTheme Claymorphic Palette & Design Tokens Tests', () {
    test('Exact color tokens match requirements for Midnight Slate', () {
      expect(AppTheme.darkBackground, equals(const Color(0xFF10141D)));
      expect(AppTheme.surfaceDark, equals(const Color(0xFF1A202C)));
      expect(AppTheme.shadowDark, equals(const Color(0xFF0B0F15)));
      expect(AppTheme.shadowLight, equals(const Color(0xFF2D3748)));
      expect(AppTheme.primaryAccent, equals(const Color(0xFF38BDF8)));
      expect(AppTheme.secondaryAccent, equals(const Color(0xFF818CF8)));
      expect(AppTheme.textPrimary, equals(const Color(0xFFF1F5F9)));
      expect(AppTheme.textSecondary, equals(const Color(0xFF94A3B8)));
      expect(AppTheme.structuralBorder, equals(const Color(0xFF94A3B8)));
    });

    test('actionGradient matches 135deg', () {
      final gradient = AppTheme.actionGradient;
      expect(gradient.begin, equals(const Alignment(-0.707, -0.707)));
      expect(gradient.end, equals(const Alignment(0.707, 0.707)));
    });

    test('Claymorphic dual shadows have controlled blur (10px)', () {
      final raisedShadows = AppTheme.clayRaisedShadows();
      expect(raisedShadows.length, equals(2));
      // Outer soft elevation shadow
      expect(raisedShadows[0].blurRadius, equals(10.0));
      expect(raisedShadows[0].offset, equals(const Offset(3, 4)));
      // Top-left specular highlight
      expect(raisedShadows[1].blurRadius, equals(6.0));
      expect(raisedShadows[1].offset, equals(const Offset(-2, -2)));
    });

    test('themeData is Dark Material 3 with darkBackground and surfaceDark',
        () {
      final theme = AppTheme.themeData;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF10141D)));
      expect(theme.colorScheme.surface, equals(const Color(0xFF1A202C)));
      expect(theme.colorScheme.primary, equals(const Color(0xFF38BDF8)));
      expect(theme.colorScheme.secondary, equals(const Color(0xFF818CF8)));
    });
  });
}
