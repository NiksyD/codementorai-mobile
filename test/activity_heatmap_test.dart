import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/domain/dashboard_submission.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/activity_heatmap.dart';

void main() {
  group('ActivityHeatmap Widget Tests', () {
    final DateTime now = DateTime.now();
    final String todayDateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final List<DashboardSubmission> testSubmissions = <DashboardSubmission>[
      DashboardSubmission(
        id: 'sub-1',
        itemId: 'act-1',
        title: 'Two Sum in Python',
        module: 'Python Essentials',
        difficulty: 'Easy',
        language: 'python',
        status: 'Passed',
        score: 98,
        submittedAt: now,
        rawDate: todayDateStr,
      ),
    ];

    testWidgets('Renders Practice Activity header and streak badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityHeatmap(
              submissions: testSubmissions,
              totalActiveDays: 14,
              currentStreak: 5,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Practice Activity'), findsOneWidget);
      expect(find.text('5 Day Streak'), findsOneWidget);
      expect(find.textContaining('14 active day'), findsAtLeastNWidgets(1));
      expect(find.text('Full Activity History'), findsOneWidget);
    });

    testWidgets('Tapping cell selects day and reveals breakdown list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityHeatmap(
                submissions: testSubmissions,
                totalActiveDays: 1,
                currentStreak: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find cell for today
      final Finder cellFinder = find.byKey(ValueKey<String>('cell-$todayDateStr'));
      expect(cellFinder, findsOneWidget);

      // Tap cell for today
      await tester.tap(cellFinder);
      await tester.pump();

      // Should now display the inline activity breakdown
      expect(find.text('Two Sum in Python'), findsOneWidget);
      expect(find.text('Python Essentials'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('98%'), findsOneWidget);

      // Tap the close button to dismiss breakdown
      final Finder closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);
      await tester.tap(closeIconFinder);
      await tester.pump();

      // Breakdown dismissed, legend restored
      expect(find.text('Two Sum in Python'), findsNothing);
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });
  });
}
