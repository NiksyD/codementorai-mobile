import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/data/code_execution_service.dart';
import 'package:codementorai_mobile/src/features/learn/domain/practice_exercise_model.dart';
import 'package:codementorai_mobile/src/features/learn/domain/submission_history_model.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/practice_code_editor.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/practice_console_sheet.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/submissions_history_view.dart';

void main() {
  group('CodeExecutionService Unit Tests', () {
    test('normalizeOutput handles whitespace, line breaks, and json', () {
      expect(CodeExecutionService.normalizeOutput('  hello  \r\nworld  '), 'hello\nworld');
      expect(CodeExecutionService.normalizeOutput('[ 1,  2, 3 ]'), '[1,2,3]');
      expect(CodeExecutionService.normalizeOutput("{'a': 1}"), '{"a":1}');
    });

    test('prepareCode ensures Java entry point', () {
      const String solutionOnly = 'class Solution { void solve() {} }';
      final String prepared = CodeExecutionService.prepareCode(solutionOnly, 'java');
      expect(prepared.contains('public static void main'), isTrue);
    });
  });

  group('SyntaxHighlightingTextEditingController Tests', () {
    testWidgets('Builds syntax highlighted TextSpans for Java code', (
      WidgetTester tester,
    ) async {
      final SyntaxHighlightingTextEditingController controller =
          SyntaxHighlightingTextEditingController(
        text: '// Step 1: Check\nboolean isValid = true;\nString name = "Alex";\nint num = 42;',
        language: 'java',
        isDark: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                final TextSpan span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                expect(span.children, isNotNull);
                expect(span.children!.isNotEmpty, isTrue);
                return Text.rich(span);
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('// Step 1: Check'), findsOneWidget);
    });
  });

  group('PracticeConsoleSheet Widget Tests', () {
    final List<TestCaseModel> testCases = <TestCaseModel>[
      const TestCaseModel(input: 'A\n1', expectedOutput: 'Excellent'),
      const TestCaseModel(input: 'B\n2', expectedOutput: 'Good'),
    ];

    testWidgets('Renders test cases as plain text tabs with input and expected output', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PracticeConsoleSheet(
              testCases: testCases,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Console and tests'), findsOneWidget);
      expect(find.text('Testcase'), findsOneWidget);
      // Cases are text tabs ("Case 1", "Case 2"), not chips.
      expect(find.textContaining('Case 1', findRichText: true), findsOneWidget);
      expect(find.textContaining('Case 2', findRichText: true), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Input'), findsOneWidget);
      expect(find.text('Expected output'), findsOneWidget);
    });

    testWidgets('Renders execution failure with per-case output and status dots', (
      WidgetTester tester,
    ) async {
      const ExecutionResultModel failureResult = ExecutionResultModel(
        isSuccess: false,
        rawLog: 'Failed assertions',
        errorTitle: 'Wrong Answer / Output Mismatch',
        socraticHint: 'Your program printed Invalid instead of Excellent.',
        passedTestCases: 0,
        totalTestCases: 2,
        caseResults: <TestCaseResultModel>[
          TestCaseResultModel(
            index: 0,
            input: 'A\n1',
            expected: 'Excellent',
            actual: 'Invalid',
            passed: false,
          ),
          TestCaseResultModel(
            index: 1,
            input: 'B\n2',
            expected: 'Good',
            actual: 'Invalid',
            passed: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PracticeConsoleSheet(
              result: failureResult,
              testCases: testCases,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Console and tests'), findsOneWidget);
      expect(
        find.textContaining('Wrong answer', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('0 of 2 passed', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Actual output (does not match)'), findsOneWidget);
      expect(find.text('Invalid'), findsOneWidget);
    });

    testWidgets('Renders execution success and Submit Solution prompt banner', (
      WidgetTester tester,
    ) async {
      bool submitted = false;

      const ExecutionResultModel successResult = ExecutionResultModel(
        isSuccess: true,
        rawLog: 'All tests passed',
        passedTestCases: 2,
        totalTestCases: 2,
        caseResults: <TestCaseResultModel>[
          TestCaseResultModel(
            index: 0,
            input: 'A\n1',
            expected: 'Excellent',
            actual: 'Excellent',
            passed: true,
          ),
          TestCaseResultModel(
            index: 1,
            input: 'B\n2',
            expected: 'Good',
            actual: 'Good',
            passed: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PracticeConsoleSheet(
              result: successResult,
              testCases: testCases,
              onSubmitSolution: () => submitted = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Console and tests'), findsOneWidget);
      expect(
        find.textContaining('Accepted', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 of 2 passed', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Submit solution'), findsOneWidget);

      await tester.tap(find.text('Submit solution'));
      await tester.pump();

      expect(submitted, isTrue);
    });
  });

  group('SubmissionHistoryModel & SubmissionsHistoryView Tests', () {
    test('SubmissionHistoryModel parses score and sanitizes optimal verdict', () {
      final SubmissionHistoryModel model = SubmissionHistoryModel.fromJson(<String, dynamic>{
        'sub_id': 'sub-1',
        'sub_code': 'console.log("hello");',
        'sub_language': 'javascript',
        'sub_status': 'accepted',
        'sub_score': 95,
        'sub_verdict': jsonEncode(<String, dynamic>{
          'verdict': 'Optimal Solution',
          'acf_composite_score': 95,
        }),
        'sub_submitted_at': '2026-10-25T12:00:00Z',
      });

      expect(model.score, equals(95));
      expect(model.verdict, equals('Accepted'));
      expect(model.isAccepted, isTrue);
    });

    test('SubmissionHistoryModel extracts acf_composite_score from joined ai_audits', () {
      final SubmissionHistoryModel model = SubmissionHistoryModel.fromJson(<String, dynamic>{
        'sub_id': 'sub-2',
        'sub_code': 'function test() {}',
        'sub_language': 'javascript',
        'sub_status': 'accepted',
        'sub_verdict': <String, dynamic>{
          'verdict': 'Accepted',
          'grade': 'A+',
        },
        'sub_submitted_at': '2026-10-25T12:00:00Z',
        'ai_audits': <Map<String, dynamic>>[
          <String, dynamic>{
            'audit_findings': <String, dynamic>{
              'acf_composite_score': 96.24,
            },
          },
        ],
      });

      expect(model.score, equals(96));
      expect(model.verdict, equals('Accepted'));
    });

    test('SubmissionHistoryModel leaves score null if no audit exists without faking 100', () {
      final SubmissionHistoryModel model = SubmissionHistoryModel.fromJson(<String, dynamic>{
        'sub_id': 'sub-3',
        'sub_code': 'function test() {}',
        'sub_language': 'javascript',
        'sub_status': 'accepted',
        'sub_verdict': <String, dynamic>{
          'verdict': 'Accepted',
        },
        'sub_submitted_at': '2026-10-25T12:00:00Z',
        'ai_audits': <dynamic>[],
      });

      expect(model.score, isNull);
    });

    testWidgets('SubmissionsHistoryView renders rows accordion without letter grades', (
      WidgetTester tester,
    ) async {
      final List<SubmissionHistoryModel> history = <SubmissionHistoryModel>[
        SubmissionHistoryModel(
          id: 'sub-101',
          code: 'function solve() { return true; }',
          language: 'javascript',
          status: 'accepted',
          verdict: 'Accepted',
          submittedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          score: 100,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubmissionsHistoryView(
              submissions: history,
              isLoading: false,
              onRefresh: () async {},
              onRestoreCode: (String code, String language) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified full-width row header and attempt details
      expect(find.text('Total attempts'), findsOneWidget);
      expect(
        find.textContaining('Attempt', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Strictly verify no letter grade badges
      expect(find.textContaining('Grade'), findsNothing);

      // Tap row to expand accordion
      await tester.tap(find.textContaining('Attempt', findRichText: true));
      await tester.pumpAndSettle();

      // Expanded accordion displays language, Copy and Restore buttons, and code
      expect(find.text('JavaScript'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(
        find.textContaining('function solve()', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
