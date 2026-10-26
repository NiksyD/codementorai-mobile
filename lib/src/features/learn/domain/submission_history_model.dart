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
    this.score,
  });

  final String id;
  final String code;
  final String language;
  final String status;
  final String verdict;
  final String? grade;
  final int? score;
  final DateTime submittedAt;

  bool get isAccepted =>
      status.toLowerCase() == 'accepted' ||
      status.toLowerCase() == 'passed' ||
      status.toLowerCase() == 'graded' ||
      status.toLowerCase() == 'success' ||
      verdict.toLowerCase() == 'accepted' ||
      verdict.toLowerCase() == 'passed';

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
    int? parsedScore;

    final dynamic rawScore = json['sub_score'];
    if (rawScore is num && rawScore > 0) {
      parsedScore = rawScore.round();
    } else if (rawScore is String) {
      final double? p = double.tryParse(rawScore);
      if (p != null && p > 0) parsedScore = p.round();
    }

    // Check joined ai_audits for real evaluation score
    if (parsedScore == null && json['ai_audits'] != null) {
      final dynamic rawAudits = json['ai_audits'];
      final List<dynamic> auditList = rawAudits is List ? rawAudits : <dynamic>[rawAudits];
      for (final dynamic aud in auditList) {
        if (aud is Map) {
          dynamic findings = aud['audit_findings'];
          if (findings is String) {
            try {
              findings = jsonDecode(findings);
            } catch (_) {}
          }
          if (findings is Map && findings['acf_composite_score'] != null) {
            final dynamic acfVal = findings['acf_composite_score'];
            if (acfVal is num) {
              parsedScore = acfVal.round();
              break;
            } else if (acfVal is String) {
              final double? p = double.tryParse(acfVal);
              if (p != null) {
                parsedScore = p.round();
                break;
              }
            }
          }
        }
      }
    }

    final dynamic rawVerdict = json['sub_verdict'];
    if (rawVerdict is Map) {
      parsedVerdict = rawVerdict['verdict']?.toString() ?? 'Accepted';
      parsedGrade = rawVerdict['grade']?.toString();
      if (parsedScore == null) {
        if (rawVerdict['acf_composite_score'] is num) {
          parsedScore = (rawVerdict['acf_composite_score'] as num).round();
        } else if (rawVerdict['score'] is num) {
          parsedScore = (rawVerdict['score'] as num).round();
        } else if (rawVerdict['score'] is String) {
          final double? p = double.tryParse(rawVerdict['score'].toString());
          if (p != null) parsedScore = p.round();
        }
      }
    } else if (rawVerdict is String && rawVerdict.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(rawVerdict);
        if (decoded is Map) {
          parsedVerdict = decoded['verdict']?.toString() ?? 'Accepted';
          parsedGrade = decoded['grade']?.toString();
          if (parsedScore == null) {
            if (decoded['acf_composite_score'] is num) {
              parsedScore = (decoded['acf_composite_score'] as num).round();
            } else if (decoded['score'] is num) {
              parsedScore = (decoded['score'] as num).round();
            } else if (decoded['score'] is String) {
              final double? p = double.tryParse(decoded['score'].toString());
              if (p != null) parsedScore = p.round();
            }
          }
        } else {
          parsedVerdict = rawVerdict;
        }
      } catch (_) {
        parsedVerdict = rawVerdict;
      }
    }

    // Sanitize verdict: never show "optimal"
    if (parsedVerdict.toLowerCase().contains('optimal')) {
      parsedVerdict = 'Accepted';
    }

    final String statusStr = json['sub_status']?.toString() ?? 'accepted';

    return SubmissionHistoryModel(
      id: json['sub_id']?.toString() ?? '',
      code: json['sub_code']?.toString() ?? json['sub_code_submitted']?.toString() ?? '',
      language: json['sub_language']?.toString() ?? 'javascript',
      status: statusStr,
      verdict: parsedVerdict,
      grade: parsedGrade,
      score: parsedScore,
      submittedAt: json['sub_submitted_at'] != null
          ? DateTime.tryParse(json['sub_submitted_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

