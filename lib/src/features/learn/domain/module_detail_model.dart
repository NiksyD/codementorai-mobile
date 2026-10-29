class ModuleActivityModel {
  const ModuleActivityModel({
    required this.id,
    required this.topicId,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.orderIndex,
    this.timeSla = 'O(1)',
    this.spaceSla = 'O(N)',
    this.isCompleted = false,
  });

  final String id;
  final String topicId;
  final String title;
  final String description;
  final String category; // 'practice', 'challenge', 'algorithmic'
  final String difficulty; // 'Easy', 'Medium', 'Hard'
  final int orderIndex;
  final String timeSla;
  final String spaceSla;
  final bool isCompleted;

  factory ModuleActivityModel.fromJson(
    Map<String, dynamic> json, {
    bool isCompleted = false,
  }) {
    final String cat = json['act_category'] as String? ?? 'practice';
    final String title = json['act_title'] as String? ?? 'Activity';
    final bool isCh = cat.toLowerCase() == 'challenge' ||
        cat.toLowerCase() == 'assessment' ||
        title.toLowerCase().contains('challenge') ||
        title.toLowerCase().contains('benchmark') ||
        title.toLowerCase().contains('assessment');

    return ModuleActivityModel(
      id: json['act_id'] as String? ?? '',
      topicId: json['topic_id'] as String? ?? '',
      title: title,
      description: json['act_description'] as String? ?? '',
      category: isCh ? 'challenge' : 'practice',
      difficulty: json['act_difficulty'] as String? ?? 'Medium',
      orderIndex: (json['act_order_index'] as num?)?.toInt() ?? 0,
      timeSla: isCh ? 'O(1)' : 'O(N)',
      spaceSla: isCh ? 'O(1)' : 'O(N)',
      isCompleted: isCompleted,
    );
  }
}

class ModuleTopicModel {
  const ModuleTopicModel({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.orderIndex,
    this.activities = const <ModuleActivityModel>[],
    this.isCompleted = false,
  });

  final String id;
  final String moduleId;
  final String title;
  final String description;
  final int orderIndex;
  final List<ModuleActivityModel> activities;
  final bool isCompleted;

  List<ModuleActivityModel> get practiceActivities => activities
      .where((ModuleActivityModel a) => a.category != 'challenge')
      .toList();

  List<ModuleActivityModel> get challengeActivities => activities
      .where((ModuleActivityModel a) => a.category == 'challenge')
      .toList();

  int get solvedCount =>
      activities.where((ModuleActivityModel a) => a.isCompleted).length;

  int get totalCount => activities.length;

  bool get isFullyCompleted =>
      totalCount > 0 && solvedCount == totalCount;

  factory ModuleTopicModel.fromJson(
    Map<String, dynamic> json, {
    List<ModuleActivityModel> activities = const <ModuleActivityModel>[],
    bool isCompleted = false,
  }) {
    return ModuleTopicModel(
      id: json['topic_id'] as String? ?? '',
      moduleId: json['track_id'] as String? ?? '',
      title: json['topic_title'] as String? ?? 'Topic',
      description: json['topic_description'] as String? ?? '',
      orderIndex: (json['topic_order_index'] as num?)?.toInt() ?? 0,
      activities: activities,
      isCompleted: isCompleted,
    );
  }
}

class ModuleDetailModel {
  const ModuleDetailModel({
    required this.id,
    required this.title,
    required this.description,
    required this.stack,
    required this.price,
    required this.coachName,
    required this.rating,
    required this.completion,
    required this.isEnrolled,
    this.isPurchased = false,
    this.isBookmarked = false,
    this.coachAvatar,
    this.topics = const <ModuleTopicModel>[],
    this.challenges = const <ModuleActivityModel>[],
  });

  final String id;
  final String title;
  final String description;
  final List<String> stack;
  final double price;
  final String coachName;
  final String? coachAvatar;
  final double rating;
  final int completion;
  final bool isEnrolled;
  final bool isPurchased;
  final bool isBookmarked;
  final List<ModuleTopicModel> topics;
  final List<ModuleActivityModel> challenges;

  ModuleDetailModel copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? stack,
    double? price,
    String? coachName,
    String? coachAvatar,
    double? rating,
    int? completion,
    bool? isEnrolled,
    bool? isPurchased,
    bool? isBookmarked,
    List<ModuleTopicModel>? topics,
    List<ModuleActivityModel>? challenges,
  }) {
    return ModuleDetailModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      stack: stack ?? this.stack,
      price: price ?? this.price,
      coachName: coachName ?? this.coachName,
      coachAvatar: coachAvatar ?? this.coachAvatar,
      rating: rating ?? this.rating,
      completion: completion ?? this.completion,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      isPurchased: isPurchased ?? this.isPurchased,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      topics: topics ?? this.topics,
      challenges: challenges ?? this.challenges,
    );
  }

  List<ModuleActivityModel> get allPracticeActivities {
    final List<ModuleActivityModel> list = <ModuleActivityModel>[];
    for (final ModuleTopicModel t in topics) {
      list.addAll(t.practiceActivities);
    }
    return list;
  }

  int get solvedPracticeCount =>
      allPracticeActivities.where((ModuleActivityModel a) => a.isCompleted).length;

  int get totalPracticeCount => allPracticeActivities.length;

  int get practiceCompletionPercentage => totalPracticeCount > 0
      ? ((solvedPracticeCount / totalPracticeCount) * 100).round()
      : 0;

  List<ModuleActivityModel> get allChallenges {
    // Prioritize module-level benchmark challenges (track_id == moduleId)
    // to match Web's 1:1 parity where challenges are queried via track_id.
    // Only fall back to topic-level challenge activities when no module-level
    // challenges exist, preventing double-counting (e.g. 7 + 6 = 13).
    if (challenges.isNotEmpty) {
      return challenges;
    }

    // Fallback: aggregate challenge activities from topics
    final List<ModuleActivityModel> list = <ModuleActivityModel>[];
    for (final ModuleTopicModel t in topics) {
      list.addAll(t.challengeActivities);
    }

    // If no challenges found anywhere, provide standard algorithmic challenges
    if (list.isEmpty) {
      list.addAll(<ModuleActivityModel>[
        ModuleActivityModel(
          id: 'ch-1',
          topicId: id,
          title: '$title Type Conversion & Memory Benchmark',
          description:
              'Implement high-throughput primitive data conversion with strict memory allocation bounds.',
          category: 'challenge',
          difficulty: 'Easy',
          orderIndex: 1,
          timeSla: 'O(1)',
          spaceSla: 'O(1)',
        ),
        ModuleActivityModel(
          id: 'ch-2',
          topicId: id,
          title: 'Algorithmic Control Branching Benchmark',
          description:
              'Optimize nested conditional evaluation loops under tight time SLAs.',
          category: 'challenge',
          difficulty: 'Medium',
          orderIndex: 2,
          timeSla: 'O(N)',
          spaceSla: 'O(1)',
        ),
        ModuleActivityModel(
          id: 'ch-3',
          topicId: id,
          title: 'In-Place 2D Matrix Rotation Benchmark',
          description:
              'Rotate a 2D matrix 90 degrees clockwise in-place without auxiliary memory.',
          category: 'challenge',
          difficulty: 'Hard',
          orderIndex: 3,
          timeSla: 'O(N²)',
          spaceSla: 'O(1)',
        ),
      ]);
    }
    return list;
  }
}
