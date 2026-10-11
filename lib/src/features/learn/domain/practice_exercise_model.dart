class TestCaseModel {
  const TestCaseModel({
    required this.input,
    required this.expectedOutput,
    this.isSample = true,
    this.orderIndex = 1,
  });

  final String input;
  final String expectedOutput;
  final bool isSample;
  final int orderIndex;

  factory TestCaseModel.fromJson(Map<String, dynamic> json) {
    return TestCaseModel(
      input: json['test_input'] as String? ?? 'N/A',
      expectedOutput: json['test_expected_output'] as String? ?? '',
      isSample: json['test_is_sample'] as bool? ?? true,
      orderIndex: (json['test_order_index'] as num?)?.toInt() ?? 1,
    );
  }
}

class PracticeExerciseModel {
  const PracticeExerciseModel({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.category,
    required this.targetTime,
    required this.targetSpace,
    required this.languages,
    required this.starterCodes,
    this.modelSolutions = const <String, String>{},
    this.testCases = const <TestCaseModel>[],
    this.isCompleted = false,
    this.acceptanceRate = '',
    this.isChallenge = false,
  });

  final String id;
  final String moduleId;
  final String title;
  final String description;
  final String difficulty;
  final String category;
  final String targetTime;
  final String targetSpace;
  final List<String> languages;
  final Map<String, String> starterCodes;
  final Map<String, String> modelSolutions;
  final List<TestCaseModel> testCases;
  final bool isCompleted;
  final String acceptanceRate;
  final bool isChallenge;

  PracticeExerciseModel copyWith({
    String? id,
    String? moduleId,
    String? title,
    String? description,
    String? difficulty,
    String? category,
    String? targetTime,
    String? targetSpace,
    List<String>? languages,
    Map<String, String>? starterCodes,
    Map<String, String>? modelSolutions,
    List<TestCaseModel>? testCases,
    bool? isCompleted,
    String? acceptanceRate,
    bool? isChallenge,
  }) {
    return PracticeExerciseModel(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      targetTime: targetTime ?? this.targetTime,
      targetSpace: targetSpace ?? this.targetSpace,
      languages: languages ?? this.languages,
      starterCodes: starterCodes ?? this.starterCodes,
      modelSolutions: modelSolutions ?? this.modelSolutions,
      testCases: testCases ?? this.testCases,
      isCompleted: isCompleted ?? this.isCompleted,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      isChallenge: isChallenge ?? this.isChallenge,
    );
  }
}

class TestCaseResultModel {
  const TestCaseResultModel({
    required this.index,
    required this.input,
    required this.expected,
    required this.actual,
    required this.passed,
    this.runtime,
    this.error,
  });

  final int index;
  final String input;
  final String expected;
  final String actual;
  final bool passed;
  final String? runtime;
  final String? error;
}

class ExecutionResultModel {
  const ExecutionResultModel({
    required this.isSuccess,
    required this.rawLog,
    this.errorTitle,
    this.codeSnippet,
    this.errorLine,
    this.socraticHint,
    this.passedTestCases = 0,
    this.totalTestCases = 0,
    this.stdout = const <String>[],
    this.caseResults = const <TestCaseResultModel>[],
    this.runtime,
    this.isCompileError = false,
    this.isRuntimeError = false,
  });

  final bool isSuccess;
  final String rawLog;
  final String? errorTitle;
  final String? codeSnippet;
  final int? errorLine;
  final String? socraticHint;
  final int passedTestCases;
  final int totalTestCases;
  final List<String> stdout;
  final List<TestCaseResultModel> caseResults;
  final String? runtime;
  final bool isCompileError;
  final bool isRuntimeError;
}
