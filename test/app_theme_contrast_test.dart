import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/theme/app_theme_config.dart';

/// Calcula la luminancia relativa según la especificación WCAG 2.1
double calculateRelativeLuminance(Color color) {
  double sRGBtoLinear(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = sRGBtoLinear(color.r);
  final g = sRGBtoLinear(color.g);
  final b = sRGBtoLinear(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calcula el ratio de contraste entre dos colores (1.0 a 21.0)
double calculateContrastRatio(Color foreground, Color background) {
  final l1 = calculateRelativeLuminance(foreground);
  final l2 = calculateRelativeLuminance(background);

  final lighter = max(l1, l2);
  final darker = min(l1, l2);

  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA Contrast Ratio Automated Tests for 6 Core Themes', () {
    test('Exactly 6 core themes exist (3 dark, 3 light)', () {
      expect(AppThemes.all.length, equals(6));
      expect(AppThemes.darkThemes.length, equals(3));
      expect(AppThemes.lightThemes.length, equals(3));
    });

    for (final theme in AppThemes.all) {
      group('Theme: ${theme.name} (${theme.id.name})', () {
        test('textPrimary on bgSurface meets WCAG AA (>= 4.5:1)', () {
          final ratio =
              calculateContrastRatio(theme.textPrimary, theme.bgSurface);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${theme.name}: textPrimary ${theme.textPrimary} on bgSurface ${theme.bgSurface} ratio is ${ratio.toStringAsFixed(2)}:1',
          );
        });

        test('textPrimary on bgCanvas meets WCAG AA (>= 4.5:1)', () {
          final ratio =
              calculateContrastRatio(theme.textPrimary, theme.bgCanvas);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${theme.name}: textPrimary ${theme.textPrimary} on bgCanvas ${theme.bgCanvas} ratio is ${ratio.toStringAsFixed(2)}:1',
          );
        });

        test('ctaTextColor on action gradient endpoints meets WCAG AA (>= 4.5:1)', () {
          for (final gradColor in theme.actionGradientColors) {
            final ratio = calculateContrastRatio(theme.ctaTextColor, gradColor);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '${theme.name}: ctaTextColor ${theme.ctaTextColor} on gradient step $gradColor ratio is ${ratio.toStringAsFixed(2)}:1',
            );
          }
        });
      });
    }
  });
}
