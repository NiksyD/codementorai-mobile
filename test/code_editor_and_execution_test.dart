import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/data/code_execution_service.dart';
import 'package:codementorai_mobile/src/features/learn/domain/practice_exercise_model.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/practice_code_editor.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/practice_console_sheet.dart';

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

    testWidgets('Renders test cases and ChoiceChip with showCheckmark false', (
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

      expect(find.text('Console & Testcases'), findsOneWidget);
      expect(find.text('Testcase'), findsOneWidget);
      expect(find.text('Case 1'), findsOneWidget);
      expect(find.text('Case 2'), findsOneWidget);
      expect(find.text('Input:'), findsOneWidget);
      expect(find.text('Expected Output:'), findsOneWidget);

      // Verify ChoiceChip has showCheckmark == false
      final ChoiceChip chip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('Case 1'), matching: find.byType(ChoiceChip)),
      );
      expect(chip.showCheckmark, isFalse);
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

      expect(find.text('Test Results (0/2 Passed)'), findsOneWidget);
      expect(find.text('Wrong Answer (0/2 passed)'), findsOneWidget);
      expect(find.text('Actual Output (stdout):'), findsOneWidget);
      expect(find.text('Invalid'), findsOneWidget);
      expect(find.text('Socratic AI Mentor Hint'), findsOneWidget);
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

      expect(find.text('All Tests Passed (2/2)'), findsOneWidget);
      expect(find.text('Accepted (2/2 passed)'), findsOneWidget);
      expect(find.text('Submit Solution →'), findsOneWidget);

      await tester.tap(find.text('Submit Solution →'));
      await tester.pump();

      expect(submitted, isTrue);
    });
  });
}
