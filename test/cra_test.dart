import 'package:codementorai_mobile/src/features/learn/domain/cra.dart';
import 'package:flutter_test/flutter_test.dart';

CraProblem p(
  String id,
  bool sub,
  bool pass,
  double? c,
  double? e, [
  List<String> topics = const <String>[],
]) => CraProblem(
  id: id,
  hasSubmission: sub,
  passedTests: pass,
  correctness: c,
  efficiency: e,
  topics: topics,
);

CraAttempt a(String id, String asm, String date, List<CraProblem> problems) =>
    CraAttempt(
      id: id,
      assessmentId: asm,
      submittedAt: DateTime.parse(date),
      problems: problems,
    );

// The same scenario was run through the web's computeCra (lib/competency/cra.ts);
// the expected numbers below are what it returned.
List<CraAttempt> scenario({bool topics = true}) {
  List<String> t(List<String> x) => topics ? x : const <String>[];
  return <CraAttempt>[
    a('a1', 'x', '2026-01-01T00:00:00Z', <CraProblem>[
      p('1', true, true, 90, 80, t(<String>['arrays'])),
      p('2', true, false, null, null),
      p('3', false, false, null, null),
    ]),
    a('a2', 'y', '2026-01-05T00:00:00Z', <CraProblem>[
      p('4', true, true, 60, 70, t(<String>['loops'])),
      p('5', true, true, 85, 50, t(<String>['recursion'])),
    ]),
    a('a3', 'x', '2026-01-10T00:00:00Z', <CraProblem>[
      p('1', true, true, 95, 90, t(<String>['arrays'])),
      p('2', true, true, 75, 60, t(<String>['strings'])),
      p('3', true, true, null, null),
    ]),
    a('a4', 'z', '2026-01-12T00:00:00Z', <CraProblem>[
      p('7', true, true, 80, 85, t(<String>['arrays', 'graphs'])),
      p('8', true, false, null, null),
    ]),
  ];
}

void main() {
  test('matches the web calculation on the same attempts', () {
    final CraAnalysis r = computeCra(scenario());
    expect(r.accuracy, 67);
    expect(r.efficiency, 71);
    expect(r.problemBreadth, 67);
    expect(r.consistency, 67);
    expect(r.readinessIndex, 68);
    expect(r.attemptCount, 4);
    expect(r.assessmentCount, 3);
    expect(r.solvedCount, 4);
    expect(r.attemptedCount, 6);
    expect(r.pendingCount, 1);
  });

  test('without topic tags Problem Breadth is null and the index re-weights', () {
    final CraAnalysis r = computeCra(scenario(topics: false));
    expect(r.problemBreadth, isNull);
    expect(r.readinessIndex, 68);
    expect(r.hasTopicData, isFalse);
  });

  test('growth matches the web: overall only once Consistency exists', () {
    final List<CraGrowthPoint> g = computeCraGrowth(scenario());
    expect(g.map((CraGrowthPoint x) => x.readinessIndex).toList(), <int?>[
      null,
      null,
      null,
      68,
    ]);
    expect(g[0].criteria['accuracy'], 33);
    expect(g[0].criteria['efficiency'], 80);
    expect(g[0].criteria['problemBreadth'], 17);
    expect(g[2].criteria['accuracy'], 75);
    expect(g[3].criteria['consistency'], 67);
  });

  test('no per-problem data gives no numbers, never a guess', () {
    expect(computeCra(const <CraAttempt>[]).readinessIndex, isNull);
    expect(
      craAttemptsFromRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'assessment_id': 'x',
          'status': 'completed',
          'score': 100,
          'submitted_at': '2026-01-01T00:00:00Z',
        },
      ]),
      isEmpty,
    );
  });

  test('rows with cra_problems become attempts; pending stays out of every figure', () {
    final List<CraAttempt> attempts = craAttemptsFromRows(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': '1',
        'assessment_id': 'x',
        'status': 'completed',
        'submitted_at': '2026-01-01T00:00:00Z',
        'cra_problems': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p1',
            'hasSubmission': true,
            'passedTests': true,
            'correctness': <String, dynamic>{'score': 88},
            'efficiency': 70,
            'topics': <String>['arrays'],
          },
          <String, dynamic>{
            'id': 'p2',
            'hasSubmission': true,
            'passedTests': true,
            'correctness': null,
            'efficiency': null,
            'topics': <String>[],
          },
        ],
      },
    ]);
    final CraAnalysis r = computeCra(attempts);
    expect(r.accuracy, 100);
    expect(r.pendingCount, 1);
    expect(r.consistency, isNull);
  });

  test('a rating below the mark counts as missed', () {
    final CraAnalysis r = computeCra(<CraAttempt>[
      a('a', 'x', '2026-01-01T00:00:00Z', <CraProblem>[p('1', true, true, 69, 90)]),
    ]);
    expect(r.accuracy, 0);
    expect(r.efficiency, isNull);
  });
}
