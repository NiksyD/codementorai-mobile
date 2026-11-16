import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/domain/learn_dashboard_data.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/competency_profile_view.dart';

void main() {
  testWidgets('CompetencyProfileView tabs do not include redundant score values', (WidgetTester tester) async {
    final List<DashboardSubmission> sampleSubmissions = <DashboardSubmission>[
      DashboardSubmission(
        id: 'sub-1',
        itemId: 'act-1',
        title: 'Two Sum',
        module: 'Algorithms',
        difficulty: 'Easy',
        language: 'python',
        submittedAt: DateTime.parse('2026-03-29T10:00:00Z'),
        rawDate: '2026-03-29',
        status: 'Passed',
        score: 90,
        findings: const <String, dynamic>{
          'correctness': <String, dynamic>{'score': 90},
          'readability': <String, dynamic>{'score': 90},
          'maintainability': <String, dynamic>{'score': 90},
          'efficiency': <String, dynamic>{'score': 90},
        },
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CompetencyProfileView(
              submissions: sampleSubmissions,
              assessmentAttempts: const <Map<String, dynamic>>[],
              isLoading: false,
              isDark: false,
              textPrimary: Colors.black,
              textSecondary: Colors.grey,
              borderColor: Colors.black12,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify tab labels exist
    expect(find.text('Programming competency'), findsOneWidget);
    expect(find.text('Competition readiness'), findsOneWidget);

    // Verify that the tab text does NOT have attached scores (e.g., 'Programming competency  90%')
    expect(find.textContaining('Programming competency  '), findsNothing);
    expect(find.textContaining('Competition readiness  '), findsNothing);

    // Verify main 44pt score is rendered in the body
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w is Text && w.data == '90%' && w.style?.fontSize == 44.0,
      ),
      findsOneWidget,
    );

    // Tap 'Competition readiness'
    await tester.tap(find.text('Competition readiness'));
    await tester.pumpAndSettle();

    // In Competition readiness (no attempts), main score should show uncalibrated em-dash '—'
    expect(find.text('Not rated yet'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });
}
