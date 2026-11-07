import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/domain/pathway_model.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/module_preview_sheet.dart';

void main() {
  group('ModulePreviewSheet Widget Tests', () {
    const PathwayModel testModule = PathwayModel(
      id: 'java-oop',
      title: 'Java OOP: Encapsulation',
      description: 'Master object-oriented encapsulation and domain boundaries.',
      language: 'java',
      stack: <String>['java'],
      status: 'Not Started',
      currentModule: 'Encapsulation Basics',
      totalModules: 5,
      completion: 0,
      isEnrolled: false,
      isBookmarked: false,
      coachName: 'HeathTEST PonoTEST2',
      rating: 5.0,
      price: 19.0,
    );

    Widget createTestWidget({required Future<void> Function(String tier) onEnroll}) {
      return MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  ModulePreviewSheet.show(
                    context,
                    module: testModule,
                    onEnroll: onEnroll,
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );
    }

    testWidgets('Renders unlock challenges sheet with sanitized coach, perks, and CodeCoins pricing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(onEnroll: (tier) async {}));
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify header and title
      expect(find.text('Unlock Coding Challenges'), findsOneWidget);
      expect(
        find.text('Full access to all algorithmic benchmarks in this module'),
        findsOneWidget,
      );
      expect(find.text('Java OOP: Encapsulation'), findsOneWidget);

      // Verify coach name is sanitized (HeathTEST PonoTEST2 -> by Heath Pono)
      expect(
        find.textContaining('by Heath Pono', findRichText: true),
        findsOneWidget,
      );

      // Verify Good to know banner is removed per design specifications
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('guided practice exercises in this module are 100% free'),
        ),
        findsNothing,
      );

      // Verify What's Included section
      expect(find.text("What's included"), findsOneWidget);
      expect(find.text('Full access to all coding challenges in this module'), findsOneWidget);
      expect(find.text('Automated test runs with instant feedback'), findsOneWidget);

      // Verify CodeCoins pricing & wallet section
      expect(find.text('Unlock price'), findsOneWidget);
      expect(find.textContaining('1900 coins', findRichText: true), findsOneWidget);
      expect(find.textContaining('₱1,102.00', findRichText: true), findsOneWidget);
      expect(find.text('Your balance'), findsOneWidget);

      // Cancel is a text action. With the default 250-coin wallet the single
      // button says how many coins are missing (and is off).
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Need 1650 more coins'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Need 1650 more coins'),
        findsOneWidget,
      );
    });
  });
}
