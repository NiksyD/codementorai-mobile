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
import 'package:codementorai_mobile/src/features/learn/presentation/activity_screen.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/activity_submission_review_screen.dart';
import 'package:go_router/go_router.dart';

class FakeActivityPathwayRepository implements PathwayRepository {
  FakeActivityPathwayRepository(this.submissions);

  final List<DashboardSubmission> submissions;

  @override
  Future<List<DashboardSubmission>> getUserSubmissions(String userId) async {
    return submissions;
  }

  @override
  Future<LearnDashboardData> getLearnDashboardData(String userId) async {
    return LearnDashboardData(
      activePathway: null,
      enrolledPathways: const <PathwayModel>[],
      allPathways: const <PathwayModel>[],
      currentStreak: 2,
      totalActiveDays: 5,
      easySolved: 2,
      mediumSolved: 1,
      hardSolved: 0,
      submissions: submissions,
    );
  }

  @override
  Future<List<PathwayModel>> getAllModules(String userId) async =>
      const <PathwayModel>[];

  @override
  Future<bool> enrollModule(String userId, String moduleId) async => true;

  @override
  Future<bool> toggleBookmark(
    String userId,
    String moduleId,
    bool isBookmarked,
  ) async => true;

  @override
  ModuleDetailModel? getCachedModuleDetails(String moduleId) => null;

  @override
  Future<ModuleDetailModel?> getModuleDetails(
    String moduleId,
    String userId,
  ) async => null;

  @override
  Future<PracticeExerciseModel?> getPracticeExercise(
    String moduleId,
    String exerciseId,
    String userId,
  ) async => null;

  @override
  Future<bool> submitPracticeExercise(
    String userId,
    String moduleId,
    String exerciseId,
    String code,
    String language,
  ) async => true;

  @override
  Future<PracticeExerciseModel?> getChallengeExercise(
    String moduleId,
    String challengeId,
    String userId,
  ) async => null;

  @override
  Future<bool> submitChallengeExercise(
    String userId,
    String moduleId,
    String challengeId,
    String code,
    String language,
  ) async => true;

  @override
  Future<List<SubmissionHistoryModel>> getExerciseSubmissions({
    required String userId,
    required String moduleId,
    required String exerciseId,
  }) async => const <SubmissionHistoryModel>[];

  @override
  Future<List<ModuleReviewModel>> getModuleReviews(String moduleId) async =>
      const <ModuleReviewModel>[];

  @override
  Future<bool> submitModuleReview({
    required String moduleId,
    required String userId,
    required int rating,
    required String comment,
  }) async => true;

  @override
  Future<Map<String, dynamic>?> getActiveModuleReport({
    required String moduleId,
    required String userId,
  }) async => null;

  @override
  Future<bool> submitModuleReport({
    required String moduleId,
    required String userId,
    required String reason,
    required String details,
  }) async => true;

  @override
  Future<List<dynamic>> getLearnerRooms(String userId) async =>
      const <dynamic>[];

  @override
  Future<Map<String, dynamic>> joinRoom({
    required String code,
    required String userId,
  }) async => const <String, dynamic>{};

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
  final DateTime now = DateTime.now();
  final String todayDateStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final DateTime yesterday = now.subtract(const Duration(days: 1));
  final String yesterdayDateStr =
      '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

  final List<DashboardSubmission> testSubmissions = <DashboardSubmission>[
    DashboardSubmission(
      id: 'sub-1',
      itemId: 'act-1',
      moduleId: 'mod-python',
      title: 'Two Sum in Python',
      module: 'Python Essentials',
      difficulty: 'Easy',
      language: 'python',
      status: 'Passed',
      score: 98,
      submittedAt: now,
      rawDate: todayDateStr,
      code: 'def two_sum(nums, target):\n    return [0, 1]',
      verdict: 'All test cases passed. Optimal O(N) time complexity.',
      feedbackTips: const <String>[
        'Excellent use of hash map for O(N) lookup.',
      ],
    ),
    DashboardSubmission(
      id: 'sub-2',
      itemId: 'act-2',
      moduleId: 'mod-java',
      title: 'Deadlock Detection in Java',
      module: 'Java Concurrency',
      difficulty: 'Hard',
      language: 'java',
      status: 'Needs Review',
      score: 65,
      submittedAt: yesterday,
      rawDate: yesterdayDateStr,
      code: 'class DeadlockChecker {\n    // check deadlock\n}',
      verdict: '2 test cases failed: cycle detection edge case.',
      feedbackTips: const <String>[
        'Consider topological sorting via Tarjan algorithm.',
      ],
    ),
    DashboardSubmission(
      id: 'sub-3',
      itemId: 'act-3',
      moduleId: 'mod-js',
      title: 'Async Event Loop in JavaScript',
      module: 'JavaScript Core',
      difficulty: 'Medium',
      language: 'javascript',
      status: 'Passed',
      score: 92,
      submittedAt: yesterday,
      rawDate: yesterdayDateStr,
      code: 'async function processQueue() {}',
      verdict: 'Passed all tests with high accuracy.',
      feedbackTips: const <String>[],
    ),
  ];

  group('ActivityScreen Widget Tests', () {
    testWidgets('Renders header, metrics row, filter tabs, and submissions', (
      WidgetTester tester,
    ) async {
      final FakeActivityPathwayRepository repository =
          FakeActivityPathwayRepository(testSubmissions);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityScreen(
            pathwayRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen title and caption
      expect(find.text('My Activity'), findsOneWidget);
      expect(
        find.text('Submissions history, code reviews, and accuracy logs'),
        findsOneWidget,
      );

      // Metrics row
      expect(find.text('Submissions'), findsOneWidget);
      expect(find.text('Pass Rate'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Review'), findsWidgets);

      // Filter tabs
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Passed'), findsWidgets);
      expect(find.text('Needs Review'), findsWidgets);

      // Submission cards rendered
      expect(find.text('Two Sum in Python'), findsOneWidget);
      expect(find.text('Deadlock Detection in Java'), findsOneWidget);
      expect(find.text('Async Event Loop in JavaScript'), findsOneWidget);
    });

    testWidgets('Filters submissions by status tab', (
      WidgetTester tester,
    ) async {
      final FakeActivityPathwayRepository repository =
          FakeActivityPathwayRepository(testSubmissions);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityScreen(
            pathwayRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Needs Review" tab pill (first occurrence)
      await tester.tap(find.text('Needs Review').first);
      await tester.pumpAndSettle();

      // Only Deadlock Detection should be visible
      expect(find.text('Deadlock Detection in Java'), findsOneWidget);
      expect(find.text('Two Sum in Python'), findsNothing);
      expect(find.text('Async Event Loop in JavaScript'), findsNothing);

      // Tap "Passed" tab pill (first occurrence)
      await tester.tap(find.text('Passed').first);
      await tester.pumpAndSettle();

      expect(find.text('Two Sum in Python'), findsOneWidget);
      expect(find.text('Async Event Loop in JavaScript'), findsOneWidget);
      expect(find.text('Deadlock Detection in Java'), findsNothing);
    });

    testWidgets('Searches submissions by text query', (
      WidgetTester tester,
    ) async {
      final FakeActivityPathwayRepository repository =
          FakeActivityPathwayRepository(testSubmissions);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityScreen(
            pathwayRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search term "Python"
      await tester.enterText(find.byType(TextField), 'Python');
      await tester.pumpAndSettle();

      expect(find.text('Two Sum in Python'), findsOneWidget);
      expect(find.text('Deadlock Detection in Java'), findsNothing);
      expect(find.text('Async Event Loop in JavaScript'), findsNothing);
    });

    testWidgets('Shows empty state with Clear Filters button when no match', (
      WidgetTester tester,
    ) async {
      final FakeActivityPathwayRepository repository =
          FakeActivityPathwayRepository(testSubmissions);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityScreen(
            pathwayRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query that matches nothing
      await tester.enterText(find.byType(TextField), 'xyz non existing');
      await tester.pumpAndSettle();

      expect(find.text('No submissions match your filters'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);

      // Tap Clear Filters
      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();

      // Submissions should be restored
      expect(find.text('Two Sum in Python'), findsOneWidget);
      expect(find.text('Deadlock Detection in Java'), findsOneWidget);
    });

    testWidgets(
      'Tapping submission navigates to dedicated review screen',
      (WidgetTester tester) async {
        final FakeActivityPathwayRepository repository =
            FakeActivityPathwayRepository(testSubmissions);

        final GoRouter router = GoRouter(
          initialLocation: '/learn/activity',
          routes: <RouteBase>[
            GoRoute(
              path: '/learn/activity',
              builder: (BuildContext context, GoRouterState state) =>
                  ActivityScreen(pathwayRepository: repository),
            ),
            GoRoute(
              path: '/learn/activity/:id',
              builder: (BuildContext context, GoRouterState state) {
                final String id = state.pathParameters['id'] ?? '';
                final DashboardSubmission? sub =
                    state.extra as DashboardSubmission?;
                return ActivitySubmissionReviewScreen(
                  submissionId: id,
                  initialSubmission: sub,
                  pathwayRepository: repository,
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        // Tap Two Sum card
        await tester.tap(find.text('Two Sum in Python'));
        await tester.pumpAndSettle();

        // Dedicated review screen is mounted
        expect(find.text('Verified Submission'), findsOneWidget);
        expect(find.text('All Tests Passed'), findsOneWidget);
        expect(find.text('AUTOMATED CODE FEEDBACK (ACF)'), findsOneWidget);
        expect(find.text('Correctness'), findsOneWidget);
        expect(find.text('Readability'), findsOneWidget);
        expect(find.text('Maintainability'), findsOneWidget);
        expect(find.text('Efficiency'), findsOneWidget);
        expect(find.text('Back to Activity'), findsOneWidget);
      },
    );

    testWidgets('Shows empty state with Browse Modules when repository has no submissions', (
      WidgetTester tester,
    ) async {
      final FakeActivityPathwayRepository repository =
          FakeActivityPathwayRepository(const <DashboardSubmission>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityScreen(
            pathwayRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No submissions yet'), findsOneWidget);
      expect(
        find.text(
          'Complete challenges inside any enrolled module to see your submission history here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Browse Modules'), findsOneWidget);
    });
  });
}
