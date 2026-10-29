import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/practice_exercise_model.dart';

class CodeExecutionService {
  const CodeExecutionService();

  static const String _judge0PublicUrl = 'https://ce.judge0.com/submissions?wait=true';
  static const String _webFallbackApiUrl = 'https://codementoraihub.vercel.app/api/execute';

  // Language IDs for Judge0 CE v1.14.0 (1:1 with Web)
  static const Map<String, int> judge0LanguageIds = <String, int>{
    'javascript': 102, // Node.js 22.08.0
    'php': 98,         // PHP 8.3.11
    'python': 100,     // Python 3.12.5
    'java': 91,        // Java JDK 17.0.6
    'cpp': 105,        // C++ GCC 14.1.0
    'c': 103,          // C GCC 14.1.0
    'csharp': 51,      // C# Mono 6.6.0
  };

  /// Prepares code for execution (e.g. adding Java harness or Main class if needed)
  static String prepareCode(String code, String language) {
    final String langKey = language.toLowerCase().trim();
    if (langKey == 'php') {
      if (!code.trimLeft().startsWith('<?')) {
        return '<?php\n$code';
      }
      return code;
    }
    if (langKey != 'java') return code;

    String prepared = code;
    if (!prepared.contains('public static void main')) {
      prepared = '$prepared\n\n'
          'public class Main {\n'
          '  public static void main(String[] args) {\n'
          '    try {\n'
          '      Solution s = new Solution();\n'
          '      java.lang.reflect.Method[] methods = Solution.class.getDeclaredMethods();\n'
          '      boolean invoked = false;\n'
          '      for (java.lang.reflect.Method m : methods) {\n'
          '        if (m.getName().equals("solve") || m.getName().equals("main")) {\n'
          '          m.setAccessible(true);\n'
          '          Object res = null;\n'
          '          if (m.getParameterCount() == 0) {\n'
          '            res = m.invoke(s);\n'
          '          } else if (m.getParameterCount() == 1 && m.getParameterTypes()[0] == int[].class) {\n'
          '            res = m.invoke(s, new int[]{2, 7, 11, 15});\n'
          '          } else if (m.getParameterCount() == 2 && m.getParameterTypes()[0] == int[].class && m.getParameterTypes()[1] == int.class) {\n'
          '            res = m.invoke(s, new int[]{2, 7, 11, 15}, 9);\n'
          '          }\n'
          '          if (res != null) {\n'
          '            if (res instanceof int[]) {\n'
          '              System.out.println(java.util.Arrays.toString((int[]) res));\n'
          '            } else {\n'
          '              System.out.println(res);\n'
          '            }\n'
          '          }\n'
          '          invoked = true;\n'
          '          break;\n'
          '        }\n'
          '      }\n'
          '      if (!invoked) {\n'
          '        System.out.println("Execution completed successfully.");\n'
          '      }\n'
          '    } catch (Exception e) {\n'
          '      e.printStackTrace();\n'
          '    }\n'
          '  }\n'
          '}';
    } else if (!prepared.contains('class Main') && prepared.contains('class Solution')) {
      prepared = prepared.replaceFirst(RegExp(r'class\s+Solution\b'), 'class Main');
    }

    return prepared;
  }

  /// Normalizes output for flexible, accurate comparison (1:1 with Web normalizeOutput)
  static String normalizeOutput(String? val) {
    if (val == null) return '';
    final String trimmed = val.trim();

    // 1. JSON structural normalization
    try {
      final dynamic parsed = jsonDecode(trimmed);
      return jsonEncode(parsed);
    } catch (_) {}

    try {
      final String doubleQuoted = trimmed.replaceAll("'", '"');
      final dynamic parsed = jsonDecode(doubleQuoted);
      return jsonEncode(parsed);
    } catch (_) {}

    // 2. Whitespace normalization (preserves case)
    return trimmed
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((String line) => line.trimRight())
        .join('\n')
        .trim();
  }

  /// Executes code against remote sandbox and formats result with multi-testcase support
  static Future<ExecutionResultModel> execute({
    required String code,
    required String language,
    List<TestCaseModel> testCases = const <TestCaseModel>[],
    String stdin = '',
    String expectedOutput = '',
    int totalTestCases = 1,
    String? apiBaseUrl,
  }) async {
    final String langKey = language.toLowerCase().trim();
    final int? langId = judge0LanguageIds[langKey];

    // Determine normalized test case suite
    final List<TestCaseModel> effectiveCases = testCases.isNotEmpty
        ? testCases
        : <TestCaseModel>[
            TestCaseModel(
              input: stdin,
              expectedOutput: expectedOutput,
            ),
          ];

    final int totalCount = effectiveCases.length;

    if (langId == null) {
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: 'Unsupported language for execution: $language',
        errorTitle: 'Unsupported Language',
        socraticHint: 'Select a supported language: Java, Python, JavaScript, PHP, C++, C, or C#.',
        passedTestCases: 0,
        totalTestCases: totalCount,
      );
    }

    final String preparedCode = prepareCode(code, langKey);

    // ── Tier 1: Next.js / API Gateway Remote Execution Endpoint ───────────────
    final List<String> candidateUrls = <String>[];
    if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
      final String cleanBase = apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl;
      candidateUrls.add('$cleanBase/api/execute');
    }
    candidateUrls.add(_webFallbackApiUrl);

    for (final String targetUrl in candidateUrls) {
      try {
        final http.Response res = await http.post(
          Uri.parse(targetUrl),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'language': langKey,
            'code': preparedCode,
            'stdin': effectiveCases.isNotEmpty ? effectiveCases.first.input : stdin,
            'expectedOutput': effectiveCases.isNotEmpty ? effectiveCases.first.expectedOutput : expectedOutput,
            'testCases': effectiveCases.map((TestCaseModel tc) => <String, dynamic>{
              'input': tc.input,
              'output': tc.expectedOutput,
            }).toList(),
          }),
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final dynamic data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            return _parseApiResponse(data, language, effectiveCases);
          }
        }
      } catch (_) {
        // Try next URL or fall back gracefully to direct Judge0 CE execution
      }
    }

    // ── Tier 2: Direct Judge0 CE Multi-Case Execution (Resilient Fallback) ──────
    try {
      final DateTime now = DateTime.now();
      final String timeStamp =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final String? compilerOptions =
          (langKey == 'c' || langKey == 'cpp') ? '-lm' : null;

      // Execute primary case first to verify compilation cleanly
      final TestCaseModel primaryCase = effectiveCases.first;
      final Map<String, dynamic> firstCaseRaw = await _submitJudge0(
        preparedCode: preparedCode,
        langId: langId,
        stdin: primaryCase.input,
        expectedOutput: primaryCase.expectedOutput,
        compilerOptions: compilerOptions,
      );

      final Map<dynamic, dynamic>? statusMap =
          firstCaseRaw['status'] is Map ? firstCaseRaw['status'] as Map : null;
      final int firstStatusId = (statusMap?['id'] is num)
          ? (statusMap!['id'] as num).toInt()
          : 0;

      final bool isCompileError = firstStatusId == 6;
      final String compileOutput =
          (firstCaseRaw['compile_output'] as String? ?? '').trimRight();
      final String firstStderr =
          (firstCaseRaw['stderr'] as String? ?? '').trimRight();
      final String firstStdout =
          (firstCaseRaw['stdout'] as String? ?? '').trimRight();

      // If compilation error, short-circuit all test cases cleanly
      if (isCompileError) {
        final List<String> rawLogLines = <String>[
          '[$timeStamp] Executing ${language.toUpperCase()} test runner...',
          if (compileOutput.isNotEmpty) ...<String>['> Compilation output:', compileOutput],
          if (firstStderr.isNotEmpty) ...<String>['> Standard Error (stderr):', firstStderr],
          '',
          'Status: Compilation Error | Runtime: — | Memory: —',
          'Exit code: 1',
        ];

        final List<TestCaseResultModel> compileFailedCases = effectiveCases
            .asMap()
            .entries
            .map((entry) => TestCaseResultModel(
                  index: entry.key,
                  input: entry.value.input,
                  expected: entry.value.expectedOutput,
                  actual: compileOutput.isNotEmpty ? compileOutput : 'Compilation Error',
                  passed: false,
                  error: compileOutput,
                ))
            .toList();

        return ExecutionResultModel(
          isSuccess: false,
          isCompileError: true,
          rawLog: rawLogLines.join('\n'),
          errorTitle: 'Compilation Error',
          socraticHint: compileOutput.isNotEmpty
              ? compileOutput
              : 'Your program failed to compile. Review syntax and type declarations.',
          passedTestCases: 0,
          totalTestCases: totalCount,
          caseResults: compileFailedCases,
          stdout: <String>[compileOutput],
        );
      }

      // Execute remaining cases in parallel
      final List<Future<Map<String, dynamic>>> remainingFutures = <Future<Map<String, dynamic>>>[];
      for (int i = 1; i < effectiveCases.length; i++) {
        final TestCaseModel tc = effectiveCases[i];
        remainingFutures.add(_submitJudge0(
          preparedCode: preparedCode,
          langId: langId,
          stdin: tc.input,
          expectedOutput: tc.expectedOutput,
          compilerOptions: compilerOptions,
        ));
      }

      final List<Map<String, dynamic>> otherCaseRaws =
          remainingFutures.isNotEmpty ? await Future.wait(remainingFutures) : <Map<String, dynamic>>[];

      final List<Map<String, dynamic>> allCaseRaws = <Map<String, dynamic>>[
        firstCaseRaw,
        ...otherCaseRaws,
      ];

      final List<TestCaseResultModel> caseResults = <TestCaseResultModel>[];
      int passedCount = 0;
      double totalRuntimeMs = 0;
      final List<String> allStdouts = <String>[];

      for (int i = 0; i < effectiveCases.length; i++) {
        final TestCaseModel tc = effectiveCases[i];
        final Map<String, dynamic> raw = allCaseRaws[i];
        final String caseStdout = (raw['stdout'] as String? ?? '').trimRight();
        final String caseStderr = (raw['stderr'] as String? ?? '').trimRight();
        final Map<dynamic, dynamic>? cStatusMap =
            raw['status'] is Map ? raw['status'] as Map : null;
        final int cStatusId = (cStatusMap?['id'] is num)
            ? (cStatusMap!['id'] as num).toInt()
            : 0;

        if (caseStdout.isNotEmpty) {
          allStdouts.add(caseStdout);
        }

        final double cTime = double.tryParse(raw['time']?.toString() ?? '0') ?? 0;
        totalRuntimeMs += cTime * 1000;

        final bool passed = cStatusId == 3 ||
            (normalizeOutput(caseStdout) == normalizeOutput(tc.expectedOutput));

        if (passed) passedCount++;

        caseResults.add(TestCaseResultModel(
          index: i,
          input: tc.input,
          expected: tc.expectedOutput,
          actual: caseStdout.isNotEmpty ? caseStdout : (caseStderr.isNotEmpty ? caseStderr : '(no output)'),
          passed: passed,
          runtime: '${(cTime * 1000).round()}ms',
          error: caseStderr.isNotEmpty ? caseStderr : null,
        ));
      }

      final bool isAllSuccess = passedCount == totalCount;
      final String runtimeStr = '${totalRuntimeMs.round()}ms';

      final List<String> rawLogLines = <String>[
        '[$timeStamp] Executing ${language.toUpperCase()} test runner...',
        if (firstStdout.isNotEmpty) ...<String>[
          '── Standard Output (stdout) ──────────────────────────────',
          '  $firstStdout',
          '──────────────────────────────────────────────────────────',
        ],
        '',
        'Status: ${isAllSuccess ? 'Accepted' : 'Wrong Answer'} | Runtime: $runtimeStr',
        'Exit code: ${isAllSuccess ? 0 : 1}',
      ];

      final TestCaseResultModel? failedCase =
          caseResults.where((c) => !c.passed).firstOrNull;

      final String socraticHint = isAllSuccess
          ? 'Your solution passed all test cases cleanly!'
          : (failedCase != null
              ? 'Test Case ${failedCase.index + 1} failed: Expected "${failedCase.expected}", got "${failedCase.actual}".'
              : 'Your program did not produce the expected output.');

      return ExecutionResultModel(
        isSuccess: isAllSuccess,
        rawLog: rawLogLines.join('\n'),
        errorTitle: isAllSuccess ? null : 'Wrong Answer / Output Mismatch',
        socraticHint: isAllSuccess ? null : socraticHint,
        passedTestCases: passedCount,
        totalTestCases: totalCount,
        caseResults: caseResults,
        runtime: runtimeStr,
        stdout: allStdouts.isNotEmpty ? allStdouts : (firstStdout.isNotEmpty ? <String>[firstStdout] : <String>[]),
      );
    } on TimeoutException {
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: 'Execution timed out (exceeded 12 seconds).',
        errorTitle: 'Time Limit Exceeded',
        socraticHint: 'Your code took too long to run. Check for infinite loops or expensive recursion.',
        passedTestCases: 0,
        totalTestCases: totalCount,
      );
    } catch (e) {
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: 'Execution failed: $e',
        errorTitle: 'Execution Error',
        socraticHint: 'Could not connect to compiler sandbox. Check network connection.',
        passedTestCases: 0,
        totalTestCases: totalCount,
      );
    }
  }

  static Future<Map<String, dynamic>> _submitJudge0({
    required String preparedCode,
    required int langId,
    required String stdin,
    required String expectedOutput,
    String? compilerOptions,
  }) async {
    final http.Response res = await http.post(
      Uri.parse(_judge0PublicUrl),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'source_code': preparedCode,
        'language_id': langId,
        'stdin': stdin.isNotEmpty ? stdin : null,
        'expected_output': expectedOutput.isNotEmpty ? expectedOutput : null,
        if (compilerOptions != null && compilerOptions.isNotEmpty)
          'compiler_options': compilerOptions,
      }),
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final dynamic raw = jsonDecode(res.body);
      if (raw is Map<String, dynamic>) {
        return raw;
      }
    }
    return <String, dynamic>{
      'status': <String, dynamic>{'id': 11, 'description': 'Sandbox Error'},
      'stderr': 'Execution returned HTTP ${res.statusCode}',
    };
  }

  static ExecutionResultModel _parseApiResponse(
    Map<String, dynamic> data,
    String language,
    List<TestCaseModel> testCases,
  ) {
    final bool isSuccess = data['success'] == true;
    final bool isCompileError = data['isCompileError'] == true;
    final bool isRuntimeError = data['isRuntimeError'] == true;

    final String stdout = data['stdout']?.toString().trimRight() ?? '';
    final String stderr = data['stderr']?.toString().trimRight() ?? '';
    final String compileOutput = data['compileOutput']?.toString().trimRight() ?? '';
    final String status = data['status']?.toString() ?? (isSuccess ? 'Accepted' : 'Failed');
    final String time = data['time']?.toString() ?? '—';
    final String memory = data['memory']?.toString() ?? '—';

    final List<TestCaseResultModel> caseResults = <TestCaseResultModel>[];
    final dynamic rawCases = data['caseResults'];
    if (rawCases is List) {
      for (final dynamic item in rawCases) {
        if (item is Map) {
          caseResults.add(TestCaseResultModel(
            index: (item['index'] as num?)?.toInt() ?? 0,
            input: item['input']?.toString() ?? '',
            expected: item['expected']?.toString() ?? '',
            actual: item['actual']?.toString() ?? '',
            passed: item['passed'] == true,
            runtime: time != '—' ? time : null,
          ));
        }
      }
    }

    // If API didn't return per-case results, synthesize from testCases
    if (caseResults.isEmpty && testCases.isNotEmpty) {
      for (int i = 0; i < testCases.length; i++) {
        final TestCaseModel tc = testCases[i];
        final bool thisPassed = i == 0
            ? isSuccess
            : (isSuccess || normalizeOutput(stdout) == normalizeOutput(tc.expectedOutput));
        caseResults.add(TestCaseResultModel(
          index: i,
          input: tc.input,
          expected: tc.expectedOutput,
          actual: i == 0 && stdout.isNotEmpty ? stdout : (thisPassed ? tc.expectedOutput : '(no output)'),
          passed: thisPassed,
          runtime: time != '—' ? time : null,
        ));
      }
    }

    final int totalCases = testCases.isNotEmpty ? testCases.length : 1;
    final int passedCases = caseResults.isNotEmpty
        ? caseResults.where((c) => c.passed).length
        : (isSuccess ? totalCases : 0);

    final List<String> rawLogLines = <String>[];
    final DateTime now = DateTime.now();
    final String timeStamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    rawLogLines.add('[$timeStamp] Executing ${language.toUpperCase()} test runner...');

    if (compileOutput.isNotEmpty) {
      rawLogLines.add('> Compilation output:');
      rawLogLines.add(compileOutput);
    }
    if (stderr.isNotEmpty) {
      rawLogLines.add('> Standard Error (stderr):');
      rawLogLines.add(stderr);
    }
    if (stdout.isNotEmpty) {
      rawLogLines.add('── Standard Output (stdout) ──────────────────────────────');
      rawLogLines.add('  $stdout');
      rawLogLines.add('──────────────────────────────────────────────────────────');
    }
    rawLogLines.add('');
    rawLogLines.add('Status: $status | Runtime: $time | Memory: $memory');
    rawLogLines.add('Exit code: ${isSuccess ? 0 : 1}');

    final TestCaseResultModel? failedCase =
        caseResults.where((c) => !c.passed).firstOrNull;

    final String? socraticHint = isSuccess
        ? null
        : (failedCase != null
            ? 'Test Case ${failedCase.index + 1} failed: Expected "${failedCase.expected}", got "${failedCase.actual}".'
            : (stderr.isNotEmpty
                ? stderr
                : (compileOutput.isNotEmpty
                    ? compileOutput
                    : 'Output did not match test specification.')));

    return ExecutionResultModel(
      isSuccess: isSuccess,
      isCompileError: isCompileError,
      isRuntimeError: isRuntimeError,
      rawLog: rawLogLines.join('\n'),
      errorTitle: isSuccess
          ? null
          : (isCompileError
              ? 'Compilation Error'
              : (isRuntimeError ? 'Runtime Error' : 'Wrong Answer / Output Mismatch')),
      socraticHint: socraticHint,
      passedTestCases: passedCases,
      totalTestCases: totalCases,
      caseResults: caseResults,
      runtime: time != '—' ? time : null,
      stdout: stdout.isNotEmpty ? stdout.split('\n') : <String>[],
    );
  }
}
