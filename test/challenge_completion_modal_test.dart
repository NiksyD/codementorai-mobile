import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/challenge_completion_modal.dart';

void main() {
  group('ChallengeCompletionModal Widget Tests', () {
    testWidgets('Renders solved challenge modal without target complexity', (
      WidgetTester tester,
    ) async {
      bool backClicked = false;
      bool reviewClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    ChallengeCompletionModal.show(
                      context,
                      challengeTitle: 'Two Sum Problem',
                      solved: true,
                      onBackToModule: () => backClicked = true,
                      onViewAiReview: () => reviewClicked = true,
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verified titles
      expect(find.text('Challenge solved'), findsOneWidget);
      expect(find.text('Two Sum Problem'), findsOneWidget);
      expect(
        find.textContaining('All test cases passed'),
        findsOneWidget,
      );

      // Verify Target complexity / time / space are NOT present (matching web)
      expect(find.text('Target complexity'), findsNothing);
      expect(find.textContaining('time ·'), findsNothing);
      expect(find.textContaining('space'), findsNothing);

      // Verify action buttons
      expect(find.text('View code review'), findsOneWidget);
      expect(find.text('Back to module'), findsOneWidget);

      await tester.tap(find.text('View code review'));
      await tester.pumpAndSettle();
      expect(reviewClicked, isTrue);
      expect(backClicked, isFalse);
    });

    testWidgets('Renders unsolved attempt modal without target complexity', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    ChallengeCompletionModal.show(
                      context,
                      challengeTitle: 'Binary Search',
                      solved: false,
                      testSummary: '2 of 5 test cases passed',
                      onBackToModule: () {},
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Attempt submitted'), findsOneWidget);
      expect(find.text('Binary Search'), findsOneWidget);
      expect(find.textContaining('2 of 5 test cases passed'), findsOneWidget);

      // Verify Target complexity is NOT displayed
      expect(find.text('Target complexity'), findsNothing);

      // Verify keep editing button exists
      expect(find.text('Keep editing'), findsOneWidget);
    });
  });
}
