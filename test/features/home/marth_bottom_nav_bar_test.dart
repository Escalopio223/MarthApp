import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/home/presentation/widgets/marth_bottom_nav_bar.dart';

void main() {
  group('MarthBottomNavBar Tests (2-Tab)', () {
    testWidgets('renders 2 navigation items: Entornos and Ocio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MarthBottomNavBar(
              currentIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Entornos'), findsOneWidget);
      expect(find.text('Ocio'), findsOneWidget);
    });

    testWidgets('calls onTabSelected when Ocio tab is tapped', (tester) async {
      int selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MarthBottomNavBar(
              currentIndex: 0,
              onTabSelected: (index) {
                selectedIndex = index;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ocio'));
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(1));
    });

    testWidgets('calls onTabSelected when Entornos tab is tapped', (tester) async {
      int selectedIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MarthBottomNavBar(
              currentIndex: 1,
              onTabSelected: (index) {
                selectedIndex = index;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Entornos'));
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(0));
    });

    testWidgets('displays badge for pending invitations on Entornos tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MarthBottomNavBar(
              currentIndex: 0,
              onTabSelected: (_) {},
              pendingInvitesCount: 4,
            ),
          ),
        ),
      );

      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('strictly adheres to claymorphic system without BackdropFilter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MarthBottomNavBar(
              currentIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
