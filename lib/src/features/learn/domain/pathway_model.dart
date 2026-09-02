class PathwayModel {
  const PathwayModel({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.stack,
    required this.status,
    required this.completion,
    required this.totalModules,
    required this.currentModule,
    this.isEnrolled = false,
    this.isBookmarked = false,
    this.coachName,
    this.coachAvatar,
  });

  final String id;
  final String title;
  final String description;
  final String language;
  final List<String> stack;
  final String status; // 'In Progress', 'Not Started', 'Mastered'
  final int completion; // 0 to 100
  final int totalModules;
  final String currentModule;
  final bool isEnrolled;
  final bool isBookmarked;
  final String? coachName;
  final String? coachAvatar;

  PathwayModel copyWith({
    String? id,
    String? title,
    String? description,
    String? language,
    List<String>? stack,
    String? status,
    int? completion,
    int? totalModules,
    String? currentModule,
    bool? isEnrolled,
    bool? isBookmarked,
    String? coachName,
    String? coachAvatar,
  }) {
    return PathwayModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      language: language ?? this.language,
      stack: stack ?? this.stack,
      status: status ?? this.status,
      completion: completion ?? this.completion,
      totalModules: totalModules ?? this.totalModules,
      currentModule: currentModule ?? this.currentModule,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      coachName: coachName ?? this.coachName,
      coachAvatar: coachAvatar ?? this.coachAvatar,
    );
  }

  factory PathwayModel.fromDatabase({
    required Map<String, dynamic> moduleData,
    List<Map<String, dynamic>> topics = const <Map<String, dynamic>>[],
    int userProgress = 0,
    bool isEnrolled = false,
    bool isBookmarked = false,
  }) {
    final String id = moduleData['mod_id'] as String? ?? '';
    final String title =
        moduleData['mod_title'] as String? ?? 'Engineering Pathway';
    final String description = moduleData['mod_description'] as String? ?? '';

    List<String> stackList = <String>[];
    final dynamic rawStack = moduleData['mod_stack'];
    if (rawStack is List) {
      stackList =
          rawStack.map((dynamic e) => e.toString().toLowerCase()).toList();
    } else if (rawStack is String && rawStack.isNotEmpty) {
      stackList =
          rawStack.split(',').map((String s) => s.trim().toLowerCase()).toList();
    }

    final String primaryLang =
        stackList.isNotEmpty ? stackList.first : 'python';

    String currentTopicTitle = 'Module 1: Getting Started';
    if (topics.isNotEmpty) {
      currentTopicTitle =
          topics.first['topic_title'] as String? ?? currentTopicTitle;
    }

    final String status = userProgress >= 100
        ? 'Mastered'
        : (userProgress > 0 || isEnrolled ? 'In Progress' : 'Not Started');

    return PathwayModel(
      id: id,
      title: title,
      description: description,
      language: primaryLang,
      stack: stackList,
      status: status,
      completion: userProgress,
      totalModules: topics.isNotEmpty ? topics.length : 8,
      currentModule: currentTopicTitle,
      isEnrolled: isEnrolled,
      isBookmarked: isBookmarked,
      coachName: moduleData['coach_name'] as String?,
      coachAvatar: moduleData['coach_avatar'] as String?,
    );
  }
}
