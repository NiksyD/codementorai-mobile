class RoomModuleSummary {
  const RoomModuleSummary({
    required this.id,
    required this.title,
    required this.description,
    this.stack = const <String>[],
    this.status = 'published',
    this.topicsCount = 0,
    this.activitiesCount = 0,
    this.displayOrder = 0,
  });

  final String id;
  final String title;
  final String description;
  final List<String> stack;
  final String status;
  final int topicsCount;
  final int activitiesCount;
  final int displayOrder;

  factory RoomModuleSummary.fromJson(Map<String, dynamic> json) {
    List<String> stackList = <String>[];
    final dynamic rawStack = json['stack'] ?? json['mod_stack'];
    if (rawStack is List) {
      stackList = rawStack.map((dynamic e) => e.toString().toLowerCase()).toList();
    } else if (rawStack is String && rawStack.isNotEmpty) {
      stackList = rawStack.split(',').map((String s) => s.trim().toLowerCase()).toList();
    }

    final String rawDesc =
        json['description'] as String? ?? json['mod_description'] as String? ?? '';
    final String cleanDesc = rawDesc.trim().isNotEmpty
        ? rawDesc.trim()
        : 'Self-paced coding practice exercises and challenges.';

    return RoomModuleSummary(
      id: json['id'] as String? ?? json['mod_id'] as String? ?? '',
      title: json['title'] as String? ?? json['mod_title'] as String? ?? 'Module',
      description: cleanDesc,
      stack: stackList,
      status: json['status'] as String? ?? json['mod_status'] as String? ?? 'published',
      topicsCount: (json['topicsCount'] as num?)?.toInt() ?? 0,
      activitiesCount: (json['activitiesCount'] as num?)?.toInt() ?? 0,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoomModel {
  const RoomModel({
    required this.id,
    required this.name,
    required this.section,
    required this.joinCode,
    required this.targetLanguage,
    required this.description,
    required this.status, // 'active', 'pending', 'rejected'
    this.mentorName = 'Mentor',
    this.mentorEmail,
    this.mentorAvatarUrl,
    this.curriculumModules = const <RoomModuleSummary>[],
    this.completedActivitiesCount = 0,
    this.enrolledAt,
    this.requestedAt,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String section;
  final String joinCode;
  final String targetLanguage;
  final String description;
  final String status;
  final String mentorName;
  final String? mentorEmail;
  final String? mentorAvatarUrl;
  final List<RoomModuleSummary> curriculumModules;
  final int completedActivitiesCount;
  final String? enrolledAt;
  final String? requestedAt;
  final bool isArchived;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isActive => status.toLowerCase() == 'active';

  int get totalTopics => curriculumModules.fold<int>(
        0,
        (int acc, RoomModuleSummary m) => acc + m.topicsCount,
      );

  int get totalActivities {
    final int count = curriculumModules.fold<int>(
      0,
      (int acc, RoomModuleSummary m) =>
          acc + (m.activitiesCount > 0 ? m.activitiesCount : m.topicsCount * 3),
    );
    return count > 0 ? count : (totalTopics > 0 ? totalTopics * 3 : 12);
  }

  int get progressPct {
    if (isPending || totalActivities == 0) return 0;
    return ((completedActivitiesCount / totalActivities) * 100).round().clamp(0, 100);
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMods = (json['curriculumModules'] as List<dynamic>?) ?? <dynamic>[];
    final List<RoomModuleSummary> modules = rawMods
        .map((dynamic m) => RoomModuleSummary.fromJson(m as Map<String, dynamic>))
        .toList();

    return RoomModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Collaborative Room',
      section: json['section'] as String? ?? 'General',
      joinCode: json['joinCode'] as String? ?? json['join_code'] as String? ?? '',
      targetLanguage: json['targetLanguage'] as String? ?? json['target_language'] as String? ?? 'python',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      mentorName: json['mentorName'] as String? ?? 'Mentor',
      mentorEmail: json['mentorEmail'] as String?,
      mentorAvatarUrl: json['mentorAvatarUrl'] as String?,
      curriculumModules: modules,
      completedActivitiesCount: (json['completedActivitiesCount'] as num?)?.toInt() ?? 0,
      enrolledAt: json['enrolledAt'] as String?,
      requestedAt: json['requestedAt'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }
}
