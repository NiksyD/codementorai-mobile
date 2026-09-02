import '../domain/learn_dashboard_data.dart';
import '../domain/module_detail_model.dart';
import '../domain/pathway_model.dart';

abstract class PathwayRepository {
  Future<LearnDashboardData> getLearnDashboardData(String userId);
  Future<List<PathwayModel>> getAllModules(String userId);
  Future<bool> enrollModule(String userId, String moduleId);
  Future<bool> toggleBookmark(String userId, String moduleId, bool isBookmarked);
  Future<ModuleDetailModel?> getModuleDetails(String moduleId, String userId);
}
