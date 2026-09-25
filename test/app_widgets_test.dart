import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/core/widgets/app_background.dart';
import 'package:marth_app/core/widgets/app_button.dart';
import 'package:marth_app/core/widgets/app_card.dart';
import 'package:marth_app/core/widgets/app_container.dart';

void main() {
  group('AppCard Claymorphic Tests', () {
    testWidgets('renders child content without BackdropFilter',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              borderRadius: 18.0,
              padding: EdgeInsets.all(16.0),
              child: Text('Clay Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Clay Card Content'), findsOneWidget);
      // Ensure zero BackdropFilter for performance
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('triggers onTap callback when provided', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () => tapped = true,
              child: const Text('Tappable Card'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Card'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('AppButton Interactive States Tests', () {
    testWidgets('normal state displays text and triggers onPressed on tap',
        (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Aceptar',
              icon: Icons.check,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);

      await tester.tap(find.text('Aceptar'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('loading state displays CircularProgressIndicator and ignores tap',
        (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Aceptar',
              isLoading: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Aceptar'), findsNothing);

      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(pressed, isFalse);
    });

    testWidgets('disabled state does not trigger onPressed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Deshabilitado',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('Deshabilitado'), findsOneWidget);
      await tester.tap(find.text('Deshabilitado'));
      await tester.pump();
      // Test completes successfully without null pointer
    });
  });

  group('AppBackground Performance Tests', () {
    testWidgets('renders child in SafeArea without BackdropFilter',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppBackground(
            child: Text('Safe Background Child'),
          ),
        ),
      );

      expect(find.text('Safe Background Child'), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('AppContainer Tests', () {
    testWidgets('renders convex container and responds to tap',
        (tester) async {
      bool containerTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppContainer(
              onTap: () => containerTapped = true,
              child: const Text('Container Item'),
            ),
          ),
        ),
      );

      expect(find.text('Container Item'), findsOneWidget);
      await tester.tap(find.text('Container Item'));
      await tester.pump();

      expect(containerTapped, isTrue);
    });

    testWidgets('renders inset container cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppContainer(
              isInset: true,
              child: Text('Inset Item'),
            ),
          ),
        ),
      );

      expect(find.text('Inset Item'), findsOneWidget);
    });
  });

  group('AppBackground Safe Area Tests', () {
    testWidgets('wraps child in SafeArea with default edges when useSafeArea is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: Text('Safe Area Content'),
            ),
          ),
        ),
      );

      expect(find.text('Safe Area Content'), findsOneWidget);
      final safeAreaFinder = find.byType(SafeArea);
      expect(safeAreaFinder, findsOneWidget);

      final safeAreaWidget = tester.widget<SafeArea>(safeAreaFinder);
      expect(safeAreaWidget.top, isTrue);
      expect(safeAreaWidget.bottom, isTrue);
      expect(safeAreaWidget.left, isTrue);
      expect(safeAreaWidget.right, isTrue);
    });

    testWidgets('respects custom edge flags like safeAreaTop: false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackground(
              safeAreaTop: false,
              safeAreaBottom: false,
              child: Text('Custom Safe Area Content'),
            ),
          ),
        ),
      );

      final safeAreaFinder = find.byType(SafeArea);
      expect(safeAreaFinder, findsOneWidget);

      final safeAreaWidget = tester.widget<SafeArea>(safeAreaFinder);
      expect(safeAreaWidget.top, isFalse);
      expect(safeAreaWidget.bottom, isFalse);
      expect(safeAreaWidget.left, isTrue);
      expect(safeAreaWidget.right, isTrue);
    });

    testWidgets('does not wrap in SafeArea when useSafeArea is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackground(
              useSafeArea: false,
              child: Text('No Safe Area Content'),
            ),
          ),
        ),
      );

      expect(find.text('No Safe Area Content'), findsOneWidget);
      expect(find.byType(SafeArea), findsNothing);
    });

    testWidgets('background container stretches edge-to-edge (infinite dimensions)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackground(
              child: Text('Edge to edge'),
            ),
          ),
        ),
      );

      final containerFinder = find.byWidgetPredicate(
        (w) => w is Container &&
            w.constraints?.minWidth == double.infinity &&
            w.constraints?.minHeight == double.infinity,
      );
      expect(containerFinder, findsOneWidget);
    });
  });
}
