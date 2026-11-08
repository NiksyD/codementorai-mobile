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
    expect(r.accuracy, 50);
    expect(r.efficiency, 75);
    expect(r.problemBreadth, 60);
    expect(r.consistency, 93);
    expect(r.readinessIndex, 69);
    expect(r.attemptCount, 4);
    expect(r.assessmentCount, 3);
    expect(r.solvedCount, 3);
    expect(r.attemptedCount, 6);
    expect(r.pendingCount, 1);
  });

  test('without topic tags Problem Breadth is null and the index re-weights', () {
    final CraAnalysis r = computeCra(scenario(topics: false));
    expect(r.problemBreadth, isNull);
    expect(r.readinessIndex, 72);
    expect(r.hasTopicData, isFalse);
  });

  test('growth matches the web: overall only once Consistency exists', () {
    final List<CraGrowthPoint> g = computeCraGrowth(scenario());
    expect(g.map((CraGrowthPoint x) => x.readinessIndex).toList(), <int?>[
      null,
      null,
      null,
      69,
    ]);
    expect(g[0].criteria['accuracy'], 33);
    expect(g[0].criteria['efficiency'], 80);
    expect(g[0].criteria['problemBreadth'], 100);
    expect(g[2].criteria['accuracy'], 50);
    expect(g[3].criteria['consistency'], 93);
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

  test('a rating below the 80 mark counts as missed; 80 counts as solved', () {
    final CraAnalysis low = computeCra(<CraAttempt>[
      a('a', 'x', '2026-01-01T00:00:00Z', <CraProblem>[p('1', true, true, 79, 90)]),
    ]);
    expect(low.accuracy, 0);
    expect(low.efficiency, isNull);
    final CraAnalysis ok = computeCra(<CraAttempt>[
      a('a', 'x', '2026-01-01T00:00:00Z', <CraProblem>[p('1', true, true, 80, 90)]),
    ]);
    expect(ok.accuracy, 100);
    expect(ok.efficiency, 90);
  });

  group('PDF worked examples (same cases as the web test)', () {
    test('constants: mark 80, weights sum to exactly 1', () {
      expect(craSolidRatingMark, 80);
      expect(craWeights['accuracy'], 0.2557);
      expect(craWeights['efficiency'], 0.259);
      expect(craWeights['problemBreadth'], 0.2393);
      expect(craWeights['consistency'], 0.246);
      final double sum = craWeights.values.fold(0.0, (double x, double y) => x + y);
      expect((sum * 10000).round(), 10000);
    });

    test('Efficiency: 85, 90, 80, 75 average 82.5; the 95 below the mark is excluded', () {
      final CraAnalysis r = computeCra(<CraAttempt>[
        a('a', 'x', '2026-01-01T00:00:00Z', <CraProblem>[
          p('1', true, true, 90, 85),
          p('2', true, true, 85, 90),
          p('3', true, true, 80, 80),
          p('4', true, true, 79, 95),
          p('5', true, true, 95, 75),
        ]),
      ]);
      expect(r.efficiency, 83);
    });

    test('Problem Breadth: 4 of 5 assessed topics demonstrated is 80', () {
      final CraAnalysis r = computeCra(<CraAttempt>[
        a('a', 'x', '2026-01-01T00:00:00Z', <CraProblem>[
          p('1', true, true, 90, 80, <String>['arrays']),
          p('2', true, true, 90, 80, <String>['recursion']),
          p('3', true, true, 90, 80, <String>['trees']),
          p('4', true, true, 90, 80, <String>['stacks']),
          p('5', true, false, null, null, <String>['graphs']),
        ]),
      ]);
      expect(r.problemBreadth, 80);
      expect(r.topicsCovered.length, 4);
      expect(r.topicsAssessed.length, 5);
    });

    test('Problem Breadth counts a repeat once, ignores other, leaves pending out', () {
      final CraAnalysis r = computeCra(<CraAttempt>[
        a('a', 'x', '2026-01-01T00:00:00Z', <CraProblem>[
          p('1', true, true, 90, 80, <String>['arrays', 'recursion']),
          p('2', true, true, 90, 80, <String>['arrays']),
          p('3', true, false, null, null, <String>['other', 'trees']),
          p('4', true, true, null, null, <String>['graphs']),
        ]),
      ]);
      expect(r.topicsAssessed.toSet(), <String>{'arrays', 'recursion', 'trees'});
      expect(r.topicsCovered.toSet(), <String>{'arrays', 'recursion'});
      expect(r.problemBreadth, 67);
    });

    test('Problem Breadth is null when no problem carries a topic', () {
      final CraAnalysis r = computeCra(<CraAttempt>[
        a('a', 'x', '2026-01-01T00:00:00Z', <CraProblem>[
          p('1', true, true, 90, 80),
          p('2', true, true, 90, 80),
        ]),
      ]);
      expect(r.problemBreadth, isNull);
    });

    test('Consistency: accuracies 70, 70, 30, 40, 90 give MAD 20 so 80', () {
      final List<int> solved = <int>[7, 7, 3, 4, 9];
      final CraAnalysis r = computeCra(<CraAttempt>[
        for (int i = 0; i < solved.length; i++)
          a('a$i', 'asm$i', '2026-01-${(i + 1).toString().padLeft(2, '0')}T00:00:00Z', <CraProblem>[
            for (int k = 0; k < 10; k++)
              p('$i-$k', true, k < solved[i], k < solved[i] ? 90 : null, k < solved[i] ? 80 : null),
          ]),
      ]);
      expect(r.consistency, 80);
      expect(r.consistencyMad, 20);
      expect(r.consistencyAssessments, 5);
    });

    test('Consistency rewards steady results over a high average', () {
      int run(List<int> solved) =>
          computeCra(<CraAttempt>[
            for (int i = 0; i < solved.length; i++)
              a('a$i', 'asm$i', '2026-01-${(i + 1).toString().padLeft(2, '0')}T00:00:00Z', <CraProblem>[
                for (int k = 0; k < 10; k++)
                  p('$i-$k', true, k < solved[i], k < solved[i] ? 90 : null, k < solved[i] ? 80 : null),
              ]),
          ]).consistency!;
      expect(run(<int>[5, 5, 5]), 100);
      expect(run(<int>[10, 0, 10]), 56);
    });
  });
}
