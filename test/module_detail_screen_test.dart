import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/data/pathway_repository.dart';
import 'package:codementorai_mobile/src/features/learn/domain/learn_dashboard_data.dart';
import 'package:codementorai_mobile/src/features/learn/domain/module_detail_model.dart';
import 'package:codementorai_mobile/src/features/learn/domain/module_review_model.dart';
import 'package:codementorai_mobile/src/features/learn/domain/pathway_model.dart';
import 'package:codementorai_mobile/src/features/learn/domain/practice_exercise_model.dart';
import 'package:codementorai_mobile/src/features/learn/domain/submission_history_model.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/module_detail_screen.dart';

class FakeDetailPathwayRepository implements PathwayRepository {
  FakeDetailPathwayRepository({
    this.moduleDetail,
    this.reviews = const <ModuleReviewModel>[],
    this.submissions = const <DashboardSubmission>[],
  });

  final ModuleDetailModel? moduleDetail;
  final List<ModuleReviewModel> reviews;
  final List<DashboardSubmission> submissions;

  @override
  ModuleDetailModel? getCachedModuleDetails(String moduleId) => moduleDetail;

  @override
  Future<ModuleDetailModel?> getModuleDetails(String moduleId, String userId) async =>
      moduleDetail;

  @override
  Future<List<ModuleReviewModel>> getModuleReviews(String moduleId) async => reviews;

  @override
  Future<List<DashboardSubmission>> getUserSubmissions(String userId) async =>
      submissions;

  @override
  Future<List<PathwayModel>> getAllModules(String userId) async => <PathwayModel>[];

  @override
  Future<bool> enrollModule(String userId, String moduleId) async => true;

  @override
  Future<bool> toggleBookmark(String userId, String moduleId, bool isBookmarked) async => true;

  @override
  Future<LearnDashboardData> getLearnDashboardData(String userId) async =>
      const LearnDashboardData(
        activePathway: null,
        enrolledPathways: <PathwayModel>[],
        allPathways: <PathwayModel>[],
        currentStreak: 0,
        totalActiveDays: 0,
        easySolved: 0,
        mediumSolved: 0,
        hardSolved: 0,
      );

  @override
  Future<PracticeExerciseModel?> getPracticeExercise(String moduleId, String exerciseId, String userId) async => null;

  @override
  Future<bool> submitPracticeExercise(String userId, String moduleId, String exerciseId, String code, String language) async => true;

  @override
  Future<PracticeExerciseModel?> getChallengeExercise(String moduleId, String challengeId, String userId) async => null;

  @override
  Future<bool> submitChallengeExercise(String userId, String moduleId, String challengeId, String code, String language) async => true;

  @override
  Future<List<SubmissionHistoryModel>> getExerciseSubmissions({required String userId, required String moduleId, required String exerciseId}) async => <SubmissionHistoryModel>[];

  @override
  Future<bool> submitModuleReview({required String moduleId, required String userId, required int rating, required String comment}) async => true;

  @override
  Future<Map<String, dynamic>?> getActiveModuleReport({required String moduleId, required String userId}) async => null;

  @override
  Future<bool> submitModuleReport({required String moduleId, required String userId, required String reason, required String details}) async => true;

  @override
  Future<List<dynamic>> getLearnerRooms(String userId) async => <dynamic>[];

  @override
  Future<Map<String, dynamic>> joinRoom({required String code, required String userId}) async => <String, dynamic>{'success': true};
}

void main() {
  group('ModuleDetailScreen Widget Tests (Web 1:1 Parity)', () {
    final ModuleDetailModel sampleModule = ModuleDetailModel(
      id: 'python-core',
      title: 'Python Core Mastery',
      description: 'Master idiomatic Python, generator pipelines, and memory optimization.',
      stack: const <String>['python'],
      price: 0.0,
      coachName: 'Sarah Jenkins',
      rating: 4.9,
      completion: 50,
      isEnrolled: true,
      isBookmarked: true,
      topics: const <ModuleTopicModel>[
        ModuleTopicModel(
          id: 'topic-1',
          moduleId: 'python-core',
          title: 'Memory Allocation & Pointers',
          description: 'Understanding object references and garbage collection.',
          orderIndex: 1,
          activities: <ModuleActivityModel>[
            ModuleActivityModel(
              id: 'act-1',
              topicId: 'topic-1',
              title: 'Reference Counting Internals',
              description: 'Inspect sys.getrefcount behavior.',
              category: 'practice',
              difficulty: 'Easy',
              orderIndex: 1,
              isCompleted: true,
            ),
            ModuleActivityModel(
              id: 'act-2',
              topicId: 'topic-1',
              title: 'Cyclic GC Simulation',
              description: 'Break circular references safely.',
              category: 'practice',
              difficulty: 'Medium',
              orderIndex: 2,
              isCompleted: false,
            ),
          ],
        ),
      ],
      challenges: const <ModuleActivityModel>[
        ModuleActivityModel(
          id: 'ch-1',
          topicId: 'python-core',
          title: 'LRU Cache Benchmark',
          description: 'Design a doubly linked list LRU cache.',
          category: 'challenge',
          difficulty: 'Hard',
          orderIndex: 1,
          timeSla: 'O(1)',
          spaceSla: 'O(N)',
          isCompleted: false,
        ),
      ],
    );

    final List<ModuleReviewModel> sampleReviews = <ModuleReviewModel>[
      const ModuleReviewModel(
        id: 'rev-1',
        moduleId: 'python-core',
        userId: 'user-1',
        userName: 'Alex Developer',
        rating: 5,
        comment: 'Outstanding explanations and rigorous SLA challenges!',
        createdAt: '2 days ago',
      ),
      const ModuleReviewModel(
        id: 'rev-2',
        moduleId: 'python-core',
        userId: 'user-2',
        userName: 'Maria Santos',
        rating: 4,
        comment: 'Great pacing and tutor feedback.',
        createdAt: '1 week ago',
      ),
    ];

    Widget createTestWidget(PathwayRepository repo) {
      return MaterialApp(
        theme: ThemeData.light(),
        home: ModuleDetailScreen(
          moduleId: 'python-core',
          pathwayRepository: repo,
        ),
      );
    }

    testWidgets('Renders hero banner, progress card and 4 standardized tabs', (WidgetTester tester) async {
      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: sampleModule,
        reviews: sampleReviews,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // Hero banner checks
      expect(find.text('Python Core Mastery'), findsWidgets);
      expect(find.text('By Sarah Jenkins'), findsOneWidget);
      expect(find.text('MODULE PROGRESS'), findsOneWidget);
      expect(find.text('1/2 Solved'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      // Primary CTA checks per AGENTS.md rule 1.2 (>0% progress -> Continue Learning)
      expect(find.text('Continue Learning'), findsOneWidget);

      // Standardized 4 tabs
      expect(find.text('Guided Practice'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Overview & Mentor'), findsOneWidget);
      expect(find.text('Reviews'), findsOneWidget);
    });

    testWidgets('Strict 0% progress handling per AGENTS.md rule 2.3 & Start Learning CTA', (WidgetTester tester) async {
      final ModuleDetailModel zeroModule = sampleModule.copyWith(
        completion: 0,
        topics: const <ModuleTopicModel>[
          ModuleTopicModel(
            id: 'topic-1',
            moduleId: 'python-core',
            title: 'Memory Allocation',
            description: 'Topic description',
            orderIndex: 1,
            activities: <ModuleActivityModel>[
              ModuleActivityModel(
                id: 'act-1',
                topicId: 'topic-1',
                title: 'Ref count',
                description: 'Description',
                category: 'practice',
                difficulty: 'Easy',
                orderIndex: 1,
                isCompleted: false,
              ),
            ],
          ),
        ],
      );

      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: zeroModule,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // CTA check per AGENTS.md rule 1.2
      expect(find.text('Start Learning'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Not Started'), findsOneWidget);
    });

    testWidgets('Tapping Challenges tab displays SLA benchmarks and difficulty badge', (WidgetTester tester) async {
      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: sampleModule,
        reviews: sampleReviews,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // Tap on Challenges tab
      await tester.tap(find.text('Challenges'));
      await tester.pumpAndSettle();

      // Verify challenge title, SLA constraint and difficulty pill
      expect(find.text('LRU Cache Benchmark'), findsOneWidget);
      expect(find.text('Time: O(1) · Space: O(N)'), findsOneWidget);
      expect(find.text('HARD'), findsOneWidget);
      expect(find.text('Solve Challenge'), findsOneWidget);
    });

    testWidgets('Tapping Overview & Mentor tab displays 2x2 Bento and Instructor card', (WidgetTester tester) async {
      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: sampleModule,
        reviews: sampleReviews,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // Tap on Overview & Mentor tab
      await tester.tap(find.text('Overview & Mentor'));
      await tester.pumpAndSettle();

      // Verify About this Module and 2x2 Bento cards
      expect(find.text('About this Module'), findsOneWidget);
      expect(find.text('WHAT YOU\'LL PRACTICE'), findsOneWidget);
      expect(find.text('In-Browser IDE'), findsOneWidget);
      expect(find.text('AI Code Tutor'), findsOneWidget);
      expect(find.text('SLA Benchmarks'), findsOneWidget);
      expect(find.text('Progress Tracking'), findsOneWidget);

      // Verify Instructor Profile Card
      expect(find.text('View Full Mentor Profile'), findsOneWidget);
    });

    testWidgets('Tapping Reviews tab displays overall score, distribution and review cards', (WidgetTester tester) async {
      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: sampleModule,
        reviews: sampleReviews,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // Tap on Reviews tab
      await tester.tap(find.text('Reviews'));
      await tester.pumpAndSettle();

      // Verify Reviews metric overview
      expect(find.text('OVERALL RATING'), findsOneWidget);
      expect(find.text('/ 5.0'), findsOneWidget);
      expect(find.text('RECOMMENDED'), findsOneWidget);
      expect(find.text('Write a Review'), findsOneWidget);

      // Verify review items
      expect(find.text('Alex Developer'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('“Outstanding explanations and rigorous SLA challenges!”'), findsOneWidget);
    });
  });
}
