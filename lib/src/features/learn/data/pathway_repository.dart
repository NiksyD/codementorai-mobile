import '../domain/activity_submission_review_model.dart';
import '../domain/learn_dashboard_data.dart';
import '../domain/module_detail_model.dart';
import '../domain/pathway_model.dart';
import '../domain/practice_exercise_model.dart';
import '../domain/module_review_model.dart';
import '../domain/submission_history_model.dart';

abstract class PathwayRepository {
  Future<LearnDashboardData> getLearnDashboardData(String userId);
  Future<List<PathwayModel>> getAllModules(String userId);
  Future<bool> enrollModule(String userId, String moduleId);
  Future<bool> toggleBookmark(String userId, String moduleId, bool isBookmarked);
  ModuleDetailModel? getCachedModuleDetails(String moduleId);
  Future<ModuleDetailModel?> getModuleDetails(String moduleId, String userId);
  Future<PracticeExerciseModel?> getPracticeExercise(
    String moduleId,
    String exerciseId,
    String userId,
  );
  Future<String?> submitPracticeExercise(
    String userId,
    String moduleId,
    String exerciseId,
    String code,
    String language,
  );
  Future<PracticeExerciseModel?> getChallengeExercise(
    String moduleId,
    String challengeId,
    String userId,
  );
  Future<String?> submitChallengeExercise(
    String userId,
    String moduleId,
    String challengeId,
    String code,
    String language,
  );
  Future<List<SubmissionHistoryModel>> getExerciseSubmissions({
    required String userId,
    required String moduleId,
    required String exerciseId,
  });
  Future<List<DashboardSubmission>> getUserSubmissions(String userId) async =>
      (await getLearnDashboardData(userId)).submissions;
  Future<List<ModuleReviewModel>> getModuleReviews(String moduleId);
  Future<bool> submitModuleReview({
    required String moduleId,
    required String userId,
    required int rating,
    required String comment,
  });
  Future<Map<String, dynamic>?> getActiveModuleReport({
    required String moduleId,
    required String userId,
  });
  Future<bool> submitModuleReport({
    required String moduleId,
    required String userId,
    required String reason,
    required String details,
  });
  Future<List<dynamic>> getLearnerRooms(String userId);
  Future<Map<String, dynamic>> joinRoom({
    required String code,
    required String userId,
  });
  Future<ActivitySubmissionReviewModel?> getSubmissionReview(
    String submissionId, {
    DashboardSubmission? cachedSubmission,
  }) async =>
      cachedSubmission != null
          ? ActivitySubmissionReviewModel.fromCachedSubmission(cachedSubmission)
          : null;
}
