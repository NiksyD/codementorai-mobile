import '../domain/assessment_model.dart';

abstract class AssessmentRepository {
  Future<List<AssessmentModel>> getPublishedAssessments(String userId);
  Future<AssessmentModel?> getAssessmentById(String assessmentId);
  Future<List<AssessmentChallengeModel>> getAssessmentChallenges(String assessmentId);
  Future<bool> toggleAssessmentBookmark(String userId, String assessmentId, bool isBookmarked);
  Future<Map<String, dynamic>?> getActiveAssessmentReport({
    required String assessmentId,
    required String userId,
  });
  Future<bool> submitAssessmentReport({
    required String assessmentId,
    required String userId,
    required String reason,
    required String details,
  });
  Future<bool> submitAssessmentAttempt({
    required String assessmentId,
    required String userId,
    required int score,
    required int timeSpentSecs,
    required List<Map<String, dynamic>> challengeSubmissions,
  });
  Future<List<Map<String, dynamic>>> getUserAssessmentAttempts(String userId);

  /// Assessment ids the learner has unlocked (coin unlock, or already attempted).
  Future<Set<String>> getUnlockedAssessmentIds(String userId);

  /// Current CodeCoin wallet balance.
  Future<int> getWalletBalance(String userId);

  /// Unlocks [assessment] with CodeCoins. Returns an error message, or null on success.
  Future<String?> unlockAssessment({
    required String userId,
    required AssessmentModel assessment,
  });
}
