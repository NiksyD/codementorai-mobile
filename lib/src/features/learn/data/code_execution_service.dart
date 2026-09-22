import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/practice_exercise_model.dart';

class CodeExecutionService {
  const CodeExecutionService();

  static const String _judge0PublicUrl = 'https://ce.judge0.com/submissions?wait=true';

  // Language IDs for Judge0 CE v1.14.0 (1:1 with Web)
  static const Map<String, int> judge0LanguageIds = <String, int>{
    'javascript': 102, // Node.js 22.08.0
    'typescript': 101, // TypeScript 5.6.2
    'python': 100,     // Python 3.12.5
    'java': 91,        // Java JDK 17.0.6
    'cpp': 105,        // C++ GCC 14.1.0
    'c': 103,          // C GCC 14.1.0
    'csharp': 51,      // C# Mono 6.6.0
  };

  /// Prepares code for execution (e.g. adding Java harness if needed)
  static String prepareCode(String code, String language) {
    final String langKey = language.toLowerCase().trim();
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

  /// Executes code against remote sandbox and formats result
  static Future<ExecutionResultModel> execute({
    required String code,
    required String language,
    String stdin = '',
    String expectedOutput = '',
    int totalTestCases = 1,
    String? apiBaseUrl,
  }) async {
    final String langKey = language.toLowerCase().trim();
    final int? langId = judge0LanguageIds[langKey];

    if (langId == null) {
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: 'Unsupported language for execution: $language',
        errorTitle: 'Unsupported Language',
        socraticHint: 'Select a supported language: Java, Python, JavaScript, TypeScript, C++, C, or C#.',
        passedTestCases: 0,
        totalTestCases: totalTestCases,
      );
    }

    final String preparedCode = prepareCode(code, langKey);

    // 1. Try Go backend gateway first if base URL is provided
    if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
      try {
        final String cleanBase = apiBaseUrl.endsWith('/')
            ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
            : apiBaseUrl;
        final Uri gatewayUri = Uri.parse('$cleanBase/api/execute');

        final http.Response res = await http.post(
          gatewayUri,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'language': langKey,
            'code': preparedCode,
            'stdin': stdin,
            'expectedOutput': expectedOutput,
          }),
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final dynamic data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            return _parseApiResponse(data, language, totalTestCases);
          }
        }
      } catch (_) {
        // Fall back gracefully to direct Judge0 CE execution
      }
    }

    // 2. Direct Judge0 CE Execution (Resilient Fallback)
    try {
      final Uri judgeUri = Uri.parse(_judge0PublicUrl);
      final http.Response res = await http.post(
        judgeUri,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'source_code': preparedCode,
          'language_id': langId,
          'stdin': stdin.isNotEmpty ? stdin : null,
          'expected_output': expectedOutput,
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200 && res.statusCode != 201) {
        return ExecutionResultModel(
          isSuccess: false,
          rawLog: 'Execution sandbox returned HTTP ${res.statusCode}: ${res.body}',
          errorTitle: 'Sandbox Error',
          socraticHint: 'The execution engine encountered an issue. Please try again.',
          passedTestCases: 0,
          totalTestCases: totalTestCases,
        );
      }

      final dynamic rawJson = jsonDecode(res.body);
      if (rawJson is! Map<String, dynamic>) {
        return ExecutionResultModel(
          isSuccess: false,
          rawLog: 'Invalid response from execution sandbox.',
          errorTitle: 'Sandbox Error',
          passedTestCases: 0,
          totalTestCases: totalTestCases,
        );
      }

      final Map<String, dynamic> data = rawJson;
      final Map<dynamic, dynamic>? statusMap =
          data['status'] is Map ? data['status'] as Map : null;
      final int statusId = (statusMap?['id'] is num)
          ? (statusMap!['id'] as num).toInt()
          : 0;

      final bool isSuccess = statusId == 3;
      final bool isCompileError = statusId == 6;
      final bool isRuntimeError = statusId == 11 || statusId == 5;

      final String stdout = (data['stdout'] as String? ?? '').trimRight();
      final String stderr = (data['stderr'] as String? ?? '').trimRight();
      final String compileOutput =
          (data['compile_output'] as String? ?? '').trimRight();
      final String statusDesc = statusMap?['description']?.toString() ??
          (isSuccess ? 'Accepted' : 'Failed');

      final String timeStr = data['time'] != null
          ? '${((double.tryParse(data['time'].toString()) ?? 0) * 1000).round()}ms'
          : '—';
      final String memoryStr = data['memory'] is num
          ? '${((data['memory'] as num) / 1024).round()}MB'
          : '—';

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
      rawLogLines.add('Status: $statusDesc | Runtime: $timeStr | Memory: $memoryStr');
      rawLogLines.add('Exit code: ${isSuccess ? 0 : 1}');

      final List<String> stdoutLines = stdout.isNotEmpty ? stdout.split('\n') : <String>[];

      return ExecutionResultModel(
        isSuccess: isSuccess,
        rawLog: rawLogLines.join('\n'),
        errorTitle: isSuccess
            ? null
            : (isCompileError
                ? 'Compilation Error'
                : (isRuntimeError ? 'Runtime Error' : 'Output Mismatch')),
        socraticHint: isSuccess
            ? null
            : (stderr.isNotEmpty
                ? stderr
                : (compileOutput.isNotEmpty
                    ? compileOutput
                    : 'Your program did not produce the expected output.')),
        passedTestCases: isSuccess ? totalTestCases : 0,
        totalTestCases: totalTestCases,
        stdout: stdoutLines,
      );
    } on TimeoutException {
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: 'Execution timed out (exceeded 12 seconds).',
        errorTitle: 'Time Limit Exceeded',
        socraticHint: 'Your code took too long to run. Check for infinite loops or expensive recursion.',
        passedTestCases: 0,
        totalTestCases: totalTestCases,
      );
    } catch (e) {
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: 'Execution failed: $e',
        errorTitle: 'Execution Error',
        socraticHint: 'Could not connect to compiler sandbox. Check network connection.',
        passedTestCases: 0,
        totalTestCases: totalTestCases,
      );
    }
  }

  static ExecutionResultModel _parseApiResponse(
    Map<String, dynamic> data,
    String language,
    int totalTestCases,
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

    return ExecutionResultModel(
      isSuccess: isSuccess,
      rawLog: rawLogLines.join('\n'),
      errorTitle: isSuccess
          ? null
          : (isCompileError
              ? 'Compilation Error'
              : (isRuntimeError ? 'Runtime Error' : 'Output Mismatch')),
      socraticHint: isSuccess
          ? null
          : (stderr.isNotEmpty
              ? stderr
              : (compileOutput.isNotEmpty
                  ? compileOutput
                  : 'Output did not match test specification.')),
      passedTestCases: isSuccess ? totalTestCases : 0,
      totalTestCases: totalTestCases,
      stdout: stdout.isNotEmpty ? stdout.split('\n') : <String>[],
    );
  }
}
