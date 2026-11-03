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
  });

  final AssessmentChallengeModel challenge;
  final String code;
  final String language;
  final bool passed;
  final String verdict;
  final int passedCases;
  final int totalCases;

  /// Saved submission id (null if the submission could not be stored).
  final String? submissionId;
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

  int get passedCount =>
      results.where((AssessmentChallengeResult r) => r.passed).length;
  bool get isPassed => score >= assessment.passingScore;
}
