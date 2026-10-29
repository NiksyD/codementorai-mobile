import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/common_widgets/app_navbar.dart';

void main() {
  group('AppNavbar Widget Tests (Dynamic Floating Capsule Navigation)', () {
    testWidgets('Renders all 5 navigation items and highlights active Dashboard', (
      WidgetTester tester,
    ) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AppNavbar(
                  selectedIndex: selected,
                  onItemSelected: (int index) {
                    setState(() {
                      selected = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify active label 'Dashboard' is visible
      expect(find.text('Dashboard'), findsOneWidget);

      // Verify all 5 tab icons exist
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });

    testWidgets('Tapping another tab triggers onItemSelected and expands its pill', (
      WidgetTester tester,
    ) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AppNavbar(
                  selectedIndex: selected,
                  onItemSelected: (int index) {
                    setState(() {
                      selected = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);

      // Tap 'Hubs' (index 2)
      await tester.tap(find.byIcon(Icons.hub_outlined));
      await tester.pumpAndSettle();

      expect(selected, 2);
      expect(find.text('Hubs'), findsOneWidget);
      expect(find.byIcon(Icons.hub_rounded), findsOneWidget);

      // Tap 'Activity' (index 3)
      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();

      expect(selected, 3);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.byIcon(Icons.insights_rounded), findsOneWidget);

      // Tap 'Profile' (index 4)
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();

      expect(selected, 4);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });
  });
}
