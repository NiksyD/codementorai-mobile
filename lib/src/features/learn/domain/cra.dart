import 'dart:math';

/// Competition Readiness (CRA). A line-for-line port of the web's
/// `lib/competency/cra.ts`, so both apps show the same figures for a learner.
///
/// It works from per-problem results, never from assessment percentages:
///  - SOLVED: all tests pass AND the AI correctness rating is at least
///    [craSolidRatingMark];
///  - MISSED: nothing submitted, tests failed, or the rating is too low;
///  - PENDING: tests passed but the AI rating has not arrived. Left out of
///    every figure until it does, nothing is guessed.
///
/// A criterion without enough data is null and is shown as "—".

/// Initial value, pending calibration.
const int craSolidRatingMark = 70;

/// Different topics a learner must have solved problems in for full Problem Breadth.
const int craBreadthTargetTopics = 6;

/// An assessment is a success for Consistency when this share of it is solved.
const double craConsistencySuccessShare = 0.5;
const int craConsistencyMinAssessments = 3;
const int craConsistencyWindow = 10;

/// Stored but never counted toward Problem Breadth.
const String craOtherTopic = 'other';

/// Index weights from the mentor survey. They sum to 1.
const Map<String, double> craWeights = <String, double>{
  'accuracy': 0.2557,
  'efficiency': 0.259,
  'problemBreadth': 0.2393,
  'consistency': 0.2459,
};

class CraProblem {
  const CraProblem({
    required this.id,
    required this.hasSubmission,
    required this.passedTests,
    this.correctness,
    this.efficiency,
    this.topics = const <String>[],
  });

  final String id;
  final bool hasSubmission;
  final bool passedTests;

  /// AI correctness 0-100, or null while the review has not arrived.
  final double? correctness;

  /// AI efficiency 0-100, or null while the review has not arrived.
  final double? efficiency;
  final List<String> topics;
}

class CraAttempt {
  const CraAttempt({
    required this.id,
    required this.assessmentId,
    required this.submittedAt,
    required this.problems,
  });

  final String id;
  final String assessmentId;
  final DateTime submittedAt;
  final List<CraProblem> problems;
}

enum CraOutcome { solved, missed, pending }

CraOutcome classifyCraProblem(CraProblem p) {
  if (!p.hasSubmission || !p.passedTests) return CraOutcome.missed;
  if (p.correctness == null) return CraOutcome.pending;
  return p.correctness! >= craSolidRatingMark
      ? CraOutcome.solved
      : CraOutcome.missed;
}

class CraAnalysis {
  const CraAnalysis({
    this.hasData = false,
    this.accuracy,
    this.efficiency,
    this.problemBreadth,
    this.consistency,
    this.readinessIndex,
    this.attemptCount = 0,
    this.assessmentCount = 0,
    this.solvedCount = 0,
    this.attemptedCount = 0,
    this.pendingCount = 0,
    this.hasTopicData = false,
  });

  final bool hasData;
  final int? accuracy;
  final int? efficiency;
  final int? problemBreadth;
  final int? consistency;

  /// Weighted blend of the criteria that have data, or null when none do.
  final int? readinessIndex;

  /// Every timed attempt submitted, retakes included.
  final int attemptCount;

  /// Different assessments taken.
  final int assessmentCount;
  final int solvedCount;
  final int attemptedCount;
  final int pendingCount;
  final bool hasTopicData;

  int? valueOf(String criterion) => switch (criterion) {
    'accuracy' => accuracy,
    'efficiency' => efficiency,
    'problemBreadth' => problemBreadth,
    'consistency' => consistency,
    _ => null,
  };
}

int _round(double n) => n.round();

/// Latest or earliest attempt of each assessment. Ties keep the one seen first.
List<CraAttempt> _pickPerAssessment(
  List<CraAttempt> attempts, {
  required bool latest,
}) {
  final Map<String, CraAttempt> by = <String, CraAttempt>{};
  for (final CraAttempt a in attempts) {
    final CraAttempt? cur = by[a.assessmentId];
    if (cur == null) {
      by[a.assessmentId] = a;
      continue;
    }
    final bool better = latest
        ? a.submittedAt.isAfter(cur.submittedAt)
        : a.submittedAt.isBefore(cur.submittedAt);
    if (better) by[a.assessmentId] = a;
  }
  return by.values.toList();
}

CraAnalysis computeCra(List<CraAttempt> attempts) {
  final List<CraAttempt> valid = attempts
      .where((CraAttempt a) => a.problems.isNotEmpty)
      .toList();
  if (valid.isEmpty) return const CraAnalysis();

  // Accuracy, Efficiency, Problem Breadth: latest attempt of each assessment.
  final List<CraAttempt> latest = _pickPerAssessment(valid, latest: true);
  int solved = 0;
  int missed = 0;
  int pending = 0;
  final List<double> efficiencyRatings = <double>[];
  final Set<String> topics = <String>{};
  bool anyTopicTags = false;

  for (final CraAttempt a in latest) {
    for (final CraProblem p in a.problems) {
      if (p.topics.isNotEmpty) anyTopicTags = true;
      switch (classifyCraProblem(p)) {
        case CraOutcome.pending:
          pending++;
        case CraOutcome.missed:
          missed++;
        case CraOutcome.solved:
          solved++;
          if (p.efficiency != null) efficiencyRatings.add(p.efficiency!);
          for (final String t in p.topics) {
            if (t.isNotEmpty && t != craOtherTopic) topics.add(t);
          }
      }
    }
  }

  final int attempted = solved + missed;
  final int? accuracy = attempted > 0
      ? _round(solved / attempted * 100)
      : null;
  final int? efficiency = efficiencyRatings.isNotEmpty
      ? _round(
          efficiencyRatings.reduce((double a, double b) => a + b) /
              efficiencyRatings.length,
        )
      : null;
  final int? problemBreadth = anyTopicTags
      ? min(100, _round(topics.length / craBreadthTargetTopics * 100))
      : null;

  // Consistency: first attempt of each of the last N assessments.
  final List<CraAttempt> firsts = _pickPerAssessment(valid, latest: false)
    ..sort(
      (CraAttempt a, CraAttempt b) => b.submittedAt.compareTo(a.submittedAt),
    );
  int rated = 0;
  int successes = 0;
  for (final CraAttempt a in firsts.take(craConsistencyWindow)) {
    int s = 0;
    int m = 0;
    for (final CraProblem p in a.problems) {
      final CraOutcome o = classifyCraProblem(p);
      if (o == CraOutcome.solved) s++;
      if (o == CraOutcome.missed) m++;
    }
    if (s + m == 0) continue;
    rated++;
    if (s / (s + m) >= craConsistencySuccessShare) successes++;
  }
  final int? consistency = rated >= craConsistencyMinAssessments
      ? _round(successes / rated * 100)
      : null;

  // Index: only criteria with data, re-weighted to total 100%.
  final Map<String, int?> values = <String, int?>{
    'accuracy': accuracy,
    'efficiency': efficiency,
    'problemBreadth': problemBreadth,
    'consistency': consistency,
  };
  double weight = 0;
  double sum = 0;
  values.forEach((String k, int? v) {
    if (v == null) return;
    weight += craWeights[k]!;
    sum += v * craWeights[k]!;
  });
  final int? readinessIndex = weight > 0 ? _round(sum / weight) : null;

  return CraAnalysis(
    hasData: attempted > 0,
    accuracy: accuracy,
    efficiency: efficiency,
    problemBreadth: problemBreadth,
    consistency: consistency,
    readinessIndex: readinessIndex,
    attemptCount: valid.length,
    assessmentCount: latest.length,
    solvedCount: solved,
    attemptedCount: attempted,
    pendingCount: pending,
    hasTopicData: anyTopicTags,
  );
}

class CraGrowthPoint {
  const CraGrowthPoint({
    required this.attemptId,
    required this.assessmentId,
    required this.timestamp,
    required this.readinessIndex,
    required this.criteria,
  });

  final String attemptId;
  final String assessmentId;
  final DateTime timestamp;

  /// Null until Consistency can be measured, so the overall line is built from
  /// the same criteria at every point.
  final int? readinessIndex;
  final Map<String, int?> criteria;
}

/// Replays the calculation over the attempts in the order they were submitted,
/// using only what existed at that moment. One point per attempt that has any
/// rated problem.
List<CraGrowthPoint> computeCraGrowth(List<CraAttempt> attempts) {
  final List<CraAttempt> ordered = List<CraAttempt>.of(attempts)
    ..sort(
      (CraAttempt a, CraAttempt b) => a.submittedAt.compareTo(b.submittedAt),
    );
  final List<CraGrowthPoint> points = <CraGrowthPoint>[];
  for (int i = 0; i < ordered.length; i++) {
    final CraAnalysis upTo = computeCra(ordered.sublist(0, i + 1));
    if (!upTo.hasData) continue;
    points.add(
      CraGrowthPoint(
        attemptId: ordered[i].id,
        assessmentId: ordered[i].assessmentId,
        timestamp: ordered[i].submittedAt,
        readinessIndex: upTo.consistency == null ? null : upTo.readinessIndex,
        criteria: <String, int?>{
          'accuracy': upTo.accuracy,
          'efficiency': upTo.efficiency,
          'problemBreadth': upTo.problemBreadth,
          'consistency': upTo.consistency,
        },
      ),
    );
  }
  return points;
}

double? _num(dynamic v) {
  final dynamic n = v is Map ? v['score'] : v;
  return n is num && n.isFinite ? n.toDouble() : null;
}

/// Builds [CraAttempt]s from `user_assessment_attempts` rows that the
/// repository has enriched with a `cra_problems` list (snapshot problems joined
/// with their AI ratings). Rows without one (older mobile attempts, library
/// fallbacks) have no per-problem data and are left out, like on the web.
List<CraAttempt> craAttemptsFromRows(List<Map<String, dynamic>> rows) {
  final List<CraAttempt> out = <CraAttempt>[];
  for (final Map<String, dynamic> r in rows) {
    final String status = r['status']?.toString() ?? 'completed';
    final DateTime? at = DateTime.tryParse(r['submitted_at']?.toString() ?? '');
    final dynamic raw = r['cra_problems'];
    if (status != 'completed' || at == null || raw is! List || raw.isEmpty) {
      continue;
    }
    out.add(
      CraAttempt(
        id: r['id']?.toString() ?? '',
        assessmentId: r['assessment_id']?.toString() ?? '',
        submittedAt: at,
        problems: <CraProblem>[
          for (final dynamic p in raw)
            if (p is Map)
              CraProblem(
                id: p['id']?.toString() ?? '',
                hasSubmission: p['hasSubmission'] == true,
                passedTests: p['passedTests'] == true,
                correctness: _num(p['correctness']),
                efficiency: _num(p['efficiency']),
                topics: <String>[
                  if (p['topics'] is List)
                    for (final dynamic t in p['topics'] as List)
                      if (t is String) t,
                ],
              ),
        ],
      ),
    );
  }
  return out;
}
