import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/data/pathway_repository.dart';
import 'package:codementorai_mobile/src/features/learn/domain/activity_submission_review_model.dart';
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
  Future<bool> unlockModuleWithCoins(String userId, String moduleId, int coins) async => true;

  @override
  Future<bool> isModulePurchased(String userId, String moduleId) async =>
      moduleDetail?.isPurchased ?? false;

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
  Future<String?> submitPracticeExercise(String userId, String moduleId, String exerciseId, String code, String language) async => 'sub-practice-123';

  @override
  Future<PracticeExerciseModel?> getChallengeExercise(String moduleId, String challengeId, String userId) async => null;

  @override
  Future<String?> submitChallengeExercise(String userId, String moduleId, String challengeId, String code, String language) async => 'sub-challenge-123';

  @override
  Future<List<SubmissionHistoryModel>> getExerciseSubmissions({required String userId, required String moduleId, required String exerciseId}) async => <SubmissionHistoryModel>[];

  @override
  Future<bool> submitModuleReview({required String moduleId, required String userId, required int rating, required String comment}) async => true;

  @override
  Future<Map<String, dynamic>?> getActiveModuleReport({required String moduleId, required String userId, String? activityId}) async => null;

  @override
  Future<bool> submitModuleReport({required String moduleId, required String userId, required String reason, required String details, String? activityId}) async => true;

  @override
  Future<List<dynamic>> getLearnerRooms(String userId) async => <dynamic>[];

  @override
  Future<Map<String, dynamic>> joinRoom({required String code, required String userId}) async => <String, dynamic>{'success': true};

  @override
  Future<bool> acceptRoomInvitation(String roomId) async => true;

  @override
  Future<bool> declineRoomInvitation(String roomId) async => true;

  @override
  Future<ActivitySubmissionReviewModel?> getSubmissionReview(
    String submissionId, {
    DashboardSubmission? cachedSubmission,
  }) async =>
      cachedSubmission != null
          ? ActivitySubmissionReviewModel.fromCachedSubmission(cachedSubmission)
          : null;
}

void main() {
  group('ModuleDetailScreen Widget Tests (Web 1:1 Redesign Parity)', () {
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

    testWidgets('Renders split-block hero banner, module outline, and learner reviews', (WidgetTester tester) async {
      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: sampleModule,
        reviews: sampleReviews,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // Split-Block Hero banner checks
      expect(find.text('Python Core Mastery'), findsWidgets);
      expect(find.text('By Sarah Jenkins'), findsOneWidget);
      expect(find.text('MODULE'), findsOneWidget);
      expect(find.text('Progress '), findsOneWidget);
      expect(find.text('Continue Learning'), findsOneWidget);

      // Module Outline checks
      expect(find.text('Module Outline'), findsOneWidget);
      expect(find.text('Memory Allocation & Pointers'), findsWidgets);
      expect(find.text('EXPAND ALL'), findsOneWidget);
      expect(find.text('COLLAPSE ALL'), findsNothing);

      // Verify activities and metadata
      expect(find.text('Reference Counting Internals'), findsOneWidget);
      expect(find.text('Practice'), findsWidgets);

      // Learner Reviews section checks
      expect(find.text('Learner Reviews'), findsOneWidget);
      expect(find.text('Write a Review'), findsOneWidget);
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
        challenges: const <ModuleActivityModel>[],
      );

      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: zeroModule,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // CTA check per AGENTS.md rule 1.2
      expect(find.text('Start Learning'), findsOneWidget);
      expect(find.text('0% Complete'), findsOneWidget);
    });

    testWidgets('Displays benchmark challenges with SLA and Challenge badge in the outline', (WidgetTester tester) async {
      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: sampleModule,
        reviews: sampleReviews,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // Expand all topics to inspect benchmark challenges
      await tester.tap(find.text('EXPAND ALL'));
      await tester.pumpAndSettle();

      expect(find.text('Benchmark Challenges'), findsOneWidget);
      expect(find.text('LRU Cache Benchmark'), findsOneWidget);
      expect(find.text('Challenge'), findsOneWidget);
      expect(find.text('· O(1)'), findsOneWidget);
      expect(find.text('Solve'), findsOneWidget); // Guided practice is free
      expect(find.text('Locked'), findsOneWidget); // Challenge requires CodeCoins unlock
    });

    testWidgets('Learner Reviews section displays overall score, distribution and review cards', (WidgetTester tester) async {
      final FakeDetailPathwayRepository repo = FakeDetailPathwayRepository(
        moduleDetail: sampleModule,
        reviews: sampleReviews,
      );

      await tester.pumpWidget(createTestWidget(repo));
      await tester.pumpAndSettle();

      // Verify Reviews metric overview
      expect(find.text('OVERALL RATING'), findsOneWidget);
      expect(find.text('/ 5.0'), findsOneWidget);
      expect(find.text('RECOMMENDATION'), findsOneWidget);
      expect(find.text('Write a Review'), findsOneWidget);

      // Verify review items
      expect(find.text('Alex Developer'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('“Outstanding explanations and rigorous SLA challenges!”'), findsOneWidget);
    });
  });
}
