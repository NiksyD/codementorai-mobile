import 'package:codementorai_mobile/src/features/learn/domain/assessment_model.dart';
import 'package:codementorai_mobile/src/features/learn/domain/assessment_report_args.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/assessment_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AssessmentReportArgs _args({
  bool withSubmissionIds = true,
  String verdict = 'Compilation Error',
}) {
  const AssessmentModel asm = AssessmentModel(
    id: 'asm-1',
    title: 'Recursive Benchmark',
    description: '',
    stack: <String>['java'],
    difficulty: 'Medium',
    durationMins: 60,
    passingScore: 70,
    maxAttempts: 3,
    status: 'published',
    challengeCount: 2,
  );
  AssessmentChallengeResult result(int i) => AssessmentChallengeResult(
        challenge: AssessmentChallengeModel(
          id: 'c$i',
          title: 'Problem $i',
          problemStatement: '',
          starterCode: '',
          language: 'java',
          difficulty: 'Medium',
        ),
        code: 'class A {}',
        language: 'java',
        passed: false,
        verdict: verdict,
        totalCases: 3,
        submissionId: withSubmissionIds ? 'sub-$i' : null,
        detail: "error: ';' expected",
      );
  return AssessmentReportArgs(
    assessment: asm,
    score: 0,
    timeSpentSecs: 89,
    results: <AssessmentChallengeResult>[result(1), result(2)],
  );
}

void main() {
  testWidgets('keeps the score final but shows AI quality as evaluating', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AssessmentReportScreen(args: _args())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The score is the real pass rate, not a loading state.
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Score = tasks passed ÷ total tasks'), findsOneWidget);

    // The AI part is the asynchronous one.
    expect(find.text('AI code quality'), findsOneWidget);
    expect(find.text('Evaluating'), findsOneWidget);

    // The real runner error is visible on each card.
    expect(find.text("error: ';' expected"), findsNWidgets(2));

    // Leave no pending polling timer behind.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows a blank state instead of 0% when nothing was evaluated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentReportScreen(
          args: _args(verdict: 'Unchanged Starter Code'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Not evaluated'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('Needs review'), findsNothing);
    // No AI review is awaited for work that was never judged.
    expect(find.text('Evaluating'), findsNothing);
  });

  testWidgets('a real failing run still shows 0% (not blank)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AssessmentReportScreen(args: _args())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('—'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows unavailable when there is nothing to evaluate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AssessmentReportScreen(args: _args(withSubmissionIds: false))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Evaluating'), findsNothing);
  });
}
