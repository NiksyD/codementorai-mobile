import 'dashboard_submission.dart';
import 'pathway_model.dart';

export 'dashboard_submission.dart';

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
    this.recommendedChallenges = const <LearnChallengeModel>[],
    this.submissions = const <DashboardSubmission>[],
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
  final List<DashboardSubmission> submissions;

  int get totalSolved => easySolved + mediumSolved + hardSolved;

  LearnDashboardData copyWith({
    PathwayModel? activePathway,
    List<PathwayModel>? enrolledPathways,
    List<PathwayModel>? allPathways,
    int? currentStreak,
    int? totalActiveDays,
    int? easySolved,
    int? mediumSolved,
    int? hardSolved,
    List<LearnChallengeModel>? recommendedChallenges,
    List<DashboardSubmission>? submissions,
  }) {
    return LearnDashboardData(
      activePathway: activePathway ?? this.activePathway,
      enrolledPathways: enrolledPathways ?? this.enrolledPathways,
      allPathways: allPathways ?? this.allPathways,
      currentStreak: currentStreak ?? this.currentStreak,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
      easySolved: easySolved ?? this.easySolved,
      mediumSolved: mediumSolved ?? this.mediumSolved,
      hardSolved: hardSolved ?? this.hardSolved,
      recommendedChallenges: recommendedChallenges ?? this.recommendedChallenges,
      submissions: submissions ?? this.submissions,
    );
  }
}
