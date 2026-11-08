import 'dashboard_submission.dart';

/// One row of the Submission History: either a single practice or module
/// submission, or a whole assessment attempt with its challenges grouped under it.
sealed class HistoryItem {
  const HistoryItem();

  String get key;
  DateTime get date;
  String get title;
  String get language;
  /// 'Passed' | 'Needs Review' | 'Pending' for submissions. An assessment
  /// attempt has no pass mark, so it is 'Completed' (or 'Pending' for old runs
  /// still waiting on a review).
  String get status;

  /// Score as a percentage, or null when it is not known.
  int? get score;
}

class SubmissionHistoryItem extends HistoryItem {
  const SubmissionHistoryItem(this.sub);

  final DashboardSubmission sub;

  @override
  String get key => sub.id;
  @override
  DateTime get date => sub.submittedAt;
  @override
  String get title => sub.title;
  @override
  String get language => sub.language;
  @override
  String get status => DashboardSubmission.normalizeStatus(sub.status);
  @override
  int? get score => sub.score;
}

class AssessmentHistoryItem extends HistoryItem {
  const AssessmentHistoryItem({
    required this.key,
    required this.date,
    required this.title,
    required this.language,
    required this.status,
    required this.score,
    required this.challenges,
  });

  @override
  final String key;
  @override
  final DateTime date;
  @override
  final String title;
  @override
  final String language;
  @override
  final String status;

  /// Overall percentage of the attempt, or null when it is not known.
  @override
  final int? score;

  /// The challenge submissions made in this attempt. Can be empty for old runs.
  final List<DashboardSubmission> challenges;

  int get passedCount =>
      challenges.where((DashboardSubmission s) => s.isPassed).length;
}

/// Submissions of one run are saved seconds apart, so anything within this
/// window belongs to the same attempt.
const Duration _sameRun = Duration(minutes: 15);

String _statusOf(List<DashboardSubmission> subs) {
  if (subs.any((DashboardSubmission s) => s.isPending)) return 'Pending';
  return subs.isNotEmpty && subs.every((DashboardSubmission s) => s.isPassed)
      ? 'Passed'
      : 'Needs Review';
}

/// Same grouping as the web history: practice and module submissions stay one
/// row each, but every assessment attempt is ONE row, not one per challenge.
List<HistoryItem> buildHistoryItems(
  List<DashboardSubmission> submissions,
  List<Map<String, dynamic>> attempts,
) {
  final List<HistoryItem> items = <HistoryItem>[];

  for (final DashboardSubmission s in submissions) {
    if (!s.isAssessment) items.add(SubmissionHistoryItem(s));
  }

  final List<DashboardSubmission> unassigned =
      submissions.where((DashboardSubmission s) => s.isAssessment).toList()
        ..sort(
          (DashboardSubmission a, DashboardSubmission b) =>
              a.submittedAt.compareTo(b.submittedAt),
        );
  final Set<String> taken = <String>{};

  String titleOf(List<DashboardSubmission> subs, String fallback) =>
      subs.isNotEmpty && subs.first.module.isNotEmpty
      ? subs.first.module
      : fallback;

  // 1. Every saved attempt is one entry; attach the challenges made in that run.
  for (final Map<String, dynamic> att in attempts) {
    final String id = att['id']?.toString() ?? '';
    final String assessmentId = att['assessment_id']?.toString() ?? '';
    final DateTime? at = DateTime.tryParse(
      att['submitted_at']?.toString() ?? '',
    );
    // Rows without an id or a time (library fallback) cannot be placed in time.
    if (id.isEmpty || assessmentId.isEmpty || at == null) continue;

    final List<DashboardSubmission> children = unassigned
        .where(
          (DashboardSubmission s) =>
              !taken.contains(s.id) &&
              s.moduleId == assessmentId &&
              s.submittedAt.difference(at).abs() <= _sameRun,
        )
        .toList();
    for (final DashboardSubmission c in children) {
      taken.add(c.id);
    }
    final dynamic rawScore = att['score'];
    items.add(
      AssessmentHistoryItem(
        key: 'attempt-$id',
        date: at,
        title: titleOf(children, 'Assessment'),
        language: children.isNotEmpty ? children.first.language : '',
        status: 'Completed',
        score: rawScore is num ? rawScore.round() : null,
        challenges: children,
      ),
    );
  }

  // 2. Older runs with challenge submissions but no saved attempt: group by
  //    assessment and time.
  final List<DashboardSubmission> leftover = unassigned
      .where((DashboardSubmission s) => !taken.contains(s.id))
      .toList();
  final List<List<DashboardSubmission>> groups = <List<DashboardSubmission>>[];
  for (final DashboardSubmission s in leftover) {
    List<DashboardSubmission>? target;
    for (final List<DashboardSubmission> g in groups.reversed) {
      if (g.first.moduleId == s.moduleId &&
          s.submittedAt.difference(g.last.submittedAt) <= _sameRun) {
        target = g;
        break;
      }
    }
    if (target != null) {
      target.add(s);
    } else {
      groups.add(<DashboardSubmission>[s]);
    }
  }
  for (final List<DashboardSubmission> g in groups) {
    final int passed = g.where((DashboardSubmission s) => s.isPassed).length;
    items.add(
      AssessmentHistoryItem(
        key: 'legacy-${g.first.id}',
        date: g.last.submittedAt,
        title: titleOf(g, 'Assessment'),
        language: g.first.language,
        status: _statusOf(g) == 'Pending' ? 'Pending' : 'Completed',
        score: ((passed / g.length) * 100).round(),
        challenges: g,
      ),
    );
  }

  items.sort((HistoryItem a, HistoryItem b) => b.date.compareTo(a.date));
  return items;
}
