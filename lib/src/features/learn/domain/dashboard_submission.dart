import 'dart:convert';

class DashboardSubmission {
  const DashboardSubmission({
    required this.id,
    required this.itemId,
    required this.title,
    required this.module,
    required this.difficulty,
    required this.language,
    required this.status,
    required this.score,
    required this.submittedAt,
    required this.rawDate,
    this.moduleId = '',
    this.code = '',
    this.verdict = '',
    this.feedbackTips = const <String>[],
  });

  final String id;
  final String itemId;
  final String moduleId;
  final String title;
  final String module;
  final String difficulty; // 'Easy' | 'Medium' | 'Hard'
  final String language;
  final String status;     // 'Passed' | 'Needs Review' | 'Pending'
  final int? score;
  final DateTime submittedAt;
  final String rawDate;   // 'YYYY-MM-DD'
  final String code;
  final String verdict;
  final List<String> feedbackTips;

  bool get isPassed => status == 'Passed' || status == 'Accepted';
  bool get isPending => status == 'Pending';
  bool get isNeedsReview => !isPassed && !isPending;

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

  static int computeStreak(List<DashboardSubmission> subs) {
    if (subs.isEmpty) return 0;
    final Set<String> daySet = subs
        .map((DashboardSubmission s) => s.rawDate)
        .where((String d) => d.isNotEmpty)
        .toSet();
    final DateTime today = DateTime.now();
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final DateTime checkDate = today.subtract(Duration(days: i));
      final String checkKey =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (daySet.contains(checkKey)) {
        streak++;
      } else if (i == 0) {
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  static int? extractScore(dynamic verdict) {
    if (verdict == null) return null;
    if (verdict is int) return verdict;
    if (verdict is double) return verdict.round();
    if (verdict is Map) {
      final dynamic s = verdict['score'] ?? verdict['grade'];
      if (s is int) return s;
      if (s is double) return s.round();
      if (s is String) return int.tryParse(s);
    } else if (verdict is String && verdict.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(verdict);
        if (decoded is Map) {
          final dynamic s = decoded['score'] ?? decoded['grade'];
          if (s is int) return s;
          if (s is double) return s.round();
          if (s is String) return int.tryParse(s);
        }
      } catch (_) {
        return int.tryParse(verdict);
      }
    }
    return null;
  }

  static String normalizeStatus(String raw) {
    final String s = raw.toLowerCase().trim();
    if (s == 'passed' || s == 'accepted' || s == 'graded' || s == 'success') {
      return 'Passed';
    }
    if (s == 'pending' || s == 'queued' || s == 'evaluating') {
      return 'Pending';
    }
    return 'Needs Review';
  }

  static String normalizeDifficulty(String raw) {
    final String s = raw.toLowerCase().trim();
    if (s == 'easy') return 'Easy';
    if (s == 'hard') return 'Hard';
    return 'Medium';
  }

  static List<String> extractFeedbackTips(dynamic verdict) {
    if (verdict == null) return const <String>[];
    try {
      dynamic v = verdict;
      if (verdict is String && verdict.trim().isNotEmpty) {
        v = jsonDecode(verdict);
      }
      if (v is Map) {
        final dynamic feedback = v['feedback'];
        if (feedback is List) {
          return feedback.map((dynamic item) => item.toString()).toList();
        }
        if (feedback is String && feedback.trim().isNotEmpty) {
          return <String>[feedback.trim()];
        }
        final dynamic message = v['message'];
        if (message is String && message.trim().isNotEmpty) {
          return <String>[message.trim()];
        }
      }
    } catch (_) {}
    return const <String>[];
  }

  static String extractVerdictText(dynamic verdict, String status) {
    if (verdict == null) {
      return status == 'Pending' ? 'Awaiting judge evaluation...' : 'Evaluation complete.';
    }
    try {
      dynamic v = verdict;
      if (verdict is String && verdict.trim().isNotEmpty) {
        v = jsonDecode(verdict);
      }
      if (v is Map) {
        if (v['summary'] is String && (v['summary'] as String).trim().isNotEmpty) {
          return (v['summary'] as String).trim();
        }
        if (v['message'] is String && (v['message'] as String).trim().isNotEmpty) {
          return (v['message'] as String).trim();
        }
        if (v['verdict'] is String && (v['verdict'] as String).trim().isNotEmpty) {
          return (v['verdict'] as String).trim();
        }
      } else if (verdict is String && verdict.trim().isNotEmpty) {
        return verdict.trim();
      }
    } catch (_) {
      if (verdict is String) return verdict.trim();
    }
    return status == 'Pending' ? 'Awaiting judge evaluation...' : 'Evaluation complete.';
  }

  factory DashboardSubmission.fromDatabase({
    required Map<String, dynamic> row,
    String? title,
    String? moduleId,
    String? moduleTitle,
    String? difficulty,
  }) {
    final String id = row['sub_id']?.toString() ?? '';
    final String itemId = row['item_id']?.toString() ?? '';
    final String rawStatus = row['sub_status']?.toString() ?? '';
    final String status = normalizeStatus(rawStatus);
    final String lang = (row['sub_language']?.toString() ?? 'python').toLowerCase();
    final DateTime submittedAt = row['sub_submitted_at'] != null
        ? DateTime.tryParse(row['sub_submitted_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    final String rawDate =
        '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')}';

    final int? score = extractScore(row['sub_verdict']);
    final String code = row['sub_code']?.toString() ?? '';
    final String verdict = extractVerdictText(row['sub_verdict'], status);
    final List<String> feedbackTips = extractFeedbackTips(row['sub_verdict']);

    return DashboardSubmission(
      id: id,
      itemId: itemId,
      moduleId: moduleId ?? '',
      title: title ?? (row['challenge_title']?.toString() ?? 'Practice Challenge'),
      module: moduleTitle ?? (row['module_title']?.toString() ?? 'Active Module'),
      difficulty: normalizeDifficulty(difficulty ?? row['challenge_difficulty']?.toString() ?? 'Medium'),
      language: lang,
      status: status,
      score: score,
      submittedAt: submittedAt,
      rawDate: rawDate,
      code: code,
      verdict: verdict,
      feedbackTips: feedbackTips,
    );
  }
}
