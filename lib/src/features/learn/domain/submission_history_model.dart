class SubmissionHistoryModel {
  const SubmissionHistoryModel({
    required this.id,
    required this.code,
    required this.language,
    required this.status,
    required this.verdict,
    required this.submittedAt,
  });

  final String id;
  final String code;
  final String language;
  final String status;
  final String verdict;
  final DateTime submittedAt;

  bool get isAccepted => status.toLowerCase() == 'accepted';

  String get timeAgoFormatted {
    final Duration diff = DateTime.now().toUtc().difference(submittedAt.toUtc());
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${submittedAt.month}/${submittedAt.day}/${submittedAt.year}';
    }
  }

  factory SubmissionHistoryModel.fromJson(Map<String, dynamic> json) {
    return SubmissionHistoryModel(
      id: json['sub_id']?.toString() ?? '',
      code: json['sub_code']?.toString() ?? '',
      language: json['sub_language']?.toString() ?? 'java',
      status: json['sub_status']?.toString() ?? 'Accepted',
      verdict: json['sub_verdict']?.toString() ?? 'Optimal',
      submittedAt: json['sub_submitted_at'] != null
          ? DateTime.tryParse(json['sub_submitted_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
