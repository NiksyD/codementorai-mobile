import 'pathway_model.dart';

class LearnChallengeModel {
  const LearnChallengeModel({
    required this.id,
    required this.title,
    required this.language,
    required this.difficulty,
    required this.category,
    required this.acceptanceRate,
  });

  final String id;
  final String title;
  final String language;
  final String difficulty;
  final String category;
  final String acceptanceRate;
}

class LearnDashboardData {
  const LearnDashboardData({
    required this.activePathway,
    required this.enrolledPathways,
    required this.allPathways,
    required this.currentStreak,
    required this.totalActiveDays,
    required this.easySolved,
    required this.mediumSolved,
    required this.hardSolved,
    required this.recommendedChallenges,
  });

  final PathwayModel? activePathway;
  final List<PathwayModel> enrolledPathways;

  /// Full published module catalog (enrolled + non-enrolled), matching web 1:1.
  final List<PathwayModel> allPathways;

  final int currentStreak;
  final int totalActiveDays;
  final int easySolved;
  final int mediumSolved;
  final int hardSolved;
  final List<LearnChallengeModel> recommendedChallenges;

  int get totalSolved => easySolved + mediumSolved + hardSolved;
}
