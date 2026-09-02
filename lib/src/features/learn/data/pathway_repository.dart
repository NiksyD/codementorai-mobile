import '../domain/learn_dashboard_data.dart';

abstract class PathwayRepository {
  Future<LearnDashboardData> getLearnDashboardData(String userId);
}
