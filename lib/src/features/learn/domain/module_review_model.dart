class ModuleReviewModel {
  const ModuleReviewModel({
    required this.id,
    required this.moduleId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String moduleId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final int rating;
  final String comment;
  final String createdAt;

  factory ModuleReviewModel.fromJson(Map<String, dynamic> json) {
    final dynamic profile = json['profiles'];
    String name = 'Learner';
    String? avatar;

    if (profile is Map<String, dynamic>) {
      final String first = profile['user_first_name'] as String? ?? '';
      final String last = profile['user_last_name'] as String? ?? '';
      final String full = '$first $last'.trim();
      if (full.isNotEmpty) {
        name = full;
      }
      avatar = profile['user_avatar_url'] as String?;
    }

    final String rawDate = json['review_created_at'] as String? ?? '';
    String formattedDate = 'Recent';
    if (rawDate.isNotEmpty) {
      try {
        final DateTime dt = DateTime.parse(rawDate).toLocal();
        final Duration diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          formattedDate = 'Just now';
        } else if (diff.inHours < 1) {
          formattedDate = '${diff.inMinutes}m ago';
        } else if (diff.inDays < 1) {
          formattedDate = '${diff.inHours}h ago';
        } else if (diff.inDays < 7) {
          formattedDate = '${diff.inDays}d ago';
        } else {
          formattedDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        }
      } catch (_) {
        formattedDate = rawDate;
      }
    }

    return ModuleReviewModel(
      id: json['review_id'] as String? ?? '',
      moduleId: json['track_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: name,
      userAvatar: avatar,
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String? ?? '',
      createdAt: formattedDate,
    );
  }
}
