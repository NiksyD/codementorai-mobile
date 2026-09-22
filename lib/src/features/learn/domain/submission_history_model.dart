import 'dart:convert';

class SubmissionHistoryModel {
  const SubmissionHistoryModel({
    required this.id,
    required this.code,
    required this.language,
    required this.status,
    required this.verdict,
    required this.submittedAt,
    this.grade,
  });

  final String id;
  final String code;
  final String language;
  final String status;
  final String verdict;
  final String? grade;
  final DateTime submittedAt;

  bool get isAccepted =>
      status.toLowerCase() == 'accepted' || verdict.toLowerCase() == 'accepted';

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
    String parsedVerdict = 'Accepted';
    String? parsedGrade;

    final dynamic rawVerdict = json['sub_verdict'];
    if (rawVerdict is Map) {
      parsedVerdict = rawVerdict['verdict']?.toString() ?? 'Accepted';
      parsedGrade = rawVerdict['grade']?.toString();
    } else if (rawVerdict is String && rawVerdict.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(rawVerdict);
        if (decoded is Map) {
          parsedVerdict = decoded['verdict']?.toString() ?? 'Accepted';
          parsedGrade = decoded['grade']?.toString();
        } else {
          parsedVerdict = rawVerdict;
        }
      } catch (_) {
        parsedVerdict = rawVerdict;
      }
    }

    return SubmissionHistoryModel(
      id: json['sub_id']?.toString() ?? '',
      code: json['sub_code']?.toString() ?? '',
      language: json['sub_language']?.toString() ?? 'java',
      status: json['sub_status']?.toString() ?? 'accepted',
      verdict: parsedVerdict,
      grade: parsedGrade,
      submittedAt: json['sub_submitted_at'] != null
          ? DateTime.tryParse(json['sub_submitted_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

