import 'assessment_model.dart';

/// Outcome of one assessment challenge after real test execution.
class AssessmentChallengeResult {
  const AssessmentChallengeResult({
    required this.challenge,
    required this.code,
    required this.language,
    required this.passed,
    required this.verdict,
    this.passedCases = 0,
    this.totalCases = 0,
    this.submissionId,
    this.detail,
  });

  final AssessmentChallengeModel challenge;
  final String code;
  final String language;
  final bool passed;
  final String verdict;
  final int passedCases;
  final int totalCases;

  /// First error line from the code runner (compile or runtime error), if any.
  final String? detail;

  /// Saved submission id (null if the submission could not be stored).
  final String? submissionId;

  /// Verdicts that mean the code was never actually judged.
  static const Set<String> notEvaluatedVerdicts = <String>{
    'No Submission',
    'Unchanged Starter Code',
    'Could Not Run',
  };

  /// True when the code really ran against the tests (pass or fail).
  bool get wasEvaluated => !notEvaluatedVerdicts.contains(verdict);
}

/// Everything the post-submission report needs (passed via router `extra`).
class AssessmentReportArgs {
  const AssessmentReportArgs({
    required this.assessment,
    required this.score,
    required this.timeSpentSecs,
    required this.results,
  });

  final AssessmentModel assessment;
  final int score;
  final int timeSpentSecs;
  final List<AssessmentChallengeResult> results;

  /// How many tasks were actually judged.
  int get evaluatedCount =>
      results.where((AssessmentChallengeResult r) => r.wasEvaluated).length;

  /// False when nothing was judged, so a score would be meaningless.
  bool get hasEvaluation => evaluatedCount > 0;

  int get passedCount =>
      results.where((AssessmentChallengeResult r) => r.passed).length;
  bool get isPassed => score >= assessment.passingScore;
}
