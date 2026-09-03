import '../domain/learn_dashboard_data.dart';
import '../domain/module_detail_model.dart';
import '../domain/pathway_model.dart';
import '../domain/practice_exercise_model.dart';

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
  Future<bool> submitPracticeExercise(
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
  Future<bool> submitChallengeExercise(
    String userId,
    String moduleId,
    String challengeId,
    String code,
    String language,
  );
}
