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
import 'package:codementorai_mobile/src/features/learn/presentation/modules_screen.dart';

class FakePathwayRepository implements PathwayRepository {
  FakePathwayRepository(this.modules);

  final List<PathwayModel> modules;

  @override
  Future<List<PathwayModel>> getAllModules(String userId) async {
    return modules;
  }

  @override
  Future<bool> enrollModule(String userId, String moduleId) async => true;

  @override
  Future<bool> toggleBookmark(
    String userId,
    String moduleId,
    bool isBookmarked,
  ) async => true;

  @override
  Future<LearnDashboardData> getLearnDashboardData(String userId) async {
    return const LearnDashboardData(
      activePathway: null,
      enrolledPathways: <PathwayModel>[],
      allPathways: <PathwayModel>[],
      currentStreak: 0,
      totalActiveDays: 0,
      easySolved: 0,
      mediumSolved: 0,
      hardSolved: 0,
    );
  }

  @override
  Future<List<DashboardSubmission>> getUserSubmissions(String userId) async =>
      const <DashboardSubmission>[];

  @override
  ModuleDetailModel? getCachedModuleDetails(String moduleId) => null;

  @override
  Future<ModuleDetailModel?> getModuleDetails(String moduleId, String userId) async => null;

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
  Future<List<ModuleReviewModel>> getModuleReviews(String moduleId) async => <ModuleReviewModel>[];

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
  Future<ActivitySubmissionReviewModel?> getSubmissionReview(
    String submissionId, {
    DashboardSubmission? cachedSubmission,
  }) async =>
      cachedSubmission != null
          ? ActivitySubmissionReviewModel.fromCachedSubmission(cachedSubmission)
          : null;
}

void main() {
  group('ModulesScreen Widget Tests', () {
    final List<PathwayModel> testModules = <PathwayModel>[
      const PathwayModel(
        id: 'python-core',
        title: 'Python Essentials',
        description: 'Learn modern Python data structures and clean code.',
        language: 'python',
        stack: <String>['python'],
        status: 'In Progress',
        completion: 45,
        totalModules: 12,
        currentModule: 'Dictionaries & Sets',
        isEnrolled: true,
        isBookmarked: true,
        coachName: 'Dr. Angela Yu',
        rating: 4.9,
      ),
      const PathwayModel(
        id: 'java-concurrency',
        title: 'Java Multithreading & Memory Model',
        description: 'Advanced lock-free primitives and thread pools.',
        language: 'java',
        stack: <String>['java'],
        status: 'Mastered',
        completion: 100,
        totalModules: 8,
        currentModule: 'ForkJoinPool',
        isEnrolled: true,
        isBookmarked: false,
        coachName: 'Venkat Subramaniam',
        rating: 5.0,
      ),
      const PathwayModel(
        id: 'js-react',
        title: 'React & Component Architecture',
        description: 'Build stateful UIs with Hooks, Context, and Suspense.',
        language: 'javascript',
        stack: <String>['javascript', 'react'],
        status: 'Not Started',
        completion: 0,
        totalModules: 15,
        currentModule: 'Introduction to JSX',
        isEnrolled: false,
        isBookmarked: false,
        coachName: 'Dan Abramov',
        rating: 4.8,
      ),
    ];

    testWidgets('Renders Explore Modules screen with header, tabs, and cards', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final FakePathwayRepository repository = FakePathwayRepository(testModules);

      await tester.pumpWidget(
        MaterialApp(
          home: ModulesScreen(pathwayRepository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & caption per AGENTS.md rule 1.3
      expect(find.text('Explore Modules'), findsOneWidget);
      expect(
        find.text('Browse coding modules and practice challenges.'),
        findsOneWidget,
      );

      // Verify filter tabs with dynamic counts
      expect(find.text('All'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('3'), findsAtLeastNWidgets(1)); // 3 total modules

      // Verify module card rendering
      expect(find.text('Python Essentials'), findsOneWidget);
      expect(find.text('Java Multithreading & Memory Model'), findsOneWidget);
      expect(find.text('React & Component Architecture'), findsOneWidget);

      // Verify completed card has "Done" badge and "Review" CTA
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);

      // Verify in-progress card has "Continue Learning" CTA
      expect(find.text('Continue Learning'), findsOneWidget);

      // Verify unenrolled card has "Start Learning" CTA per AGENTS.md rule 1.2
      expect(find.text('Start Learning'), findsOneWidget);
    });

    testWidgets('Filters modules by category tab', (
      WidgetTester tester,
    ) async {
      final FakePathwayRepository repository = FakePathwayRepository(testModules);

      await tester.pumpWidget(
        MaterialApp(
          home: ModulesScreen(pathwayRepository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Saved" tab
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();

      // Only bookmarked Python module should appear
      expect(find.text('Python Essentials'), findsOneWidget);
      expect(find.text('Java Multithreading & Memory Model'), findsNothing);
      expect(find.text('React & Component Architecture'), findsNothing);

      // Tap "Completed" tab
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // Only completed Java module should appear
      expect(find.text('Python Essentials'), findsNothing);
      expect(find.text('Java Multithreading & Memory Model'), findsOneWidget);
      expect(find.text('React & Component Architecture'), findsNothing);
    });

    testWidgets('Searches modules with alias keyword (py -> Python)', (
      WidgetTester tester,
    ) async {
      final FakePathwayRepository repository = FakePathwayRepository(testModules);

      await tester.pumpWidget(
        MaterialApp(
          home: ModulesScreen(pathwayRepository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Enter "py" in search field
      final Finder searchField = find.byType(TextField);
      await tester.enterText(searchField, 'py');
      await tester.pumpAndSettle();

      // Should match Python Essentials via alias
      expect(find.text('Python Essentials'), findsOneWidget);
      expect(find.text('Java Multithreading & Memory Model'), findsNothing);
      expect(find.text('React & Component Architecture'), findsNothing);
    });

    testWidgets('Shows empty state with Clear button when no match', (
      WidgetTester tester,
    ) async {
      final FakePathwayRepository repository = FakePathwayRepository(testModules);

      await tester.pumpWidget(
        MaterialApp(
          home: ModulesScreen(pathwayRepository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search for non-existent topic
      final Finder searchField = find.byType(TextField);
      await tester.enterText(searchField, 'haskell');
      await tester.pumpAndSettle();

      expect(find.text('No modules matching "haskell"'), findsOneWidget);
      expect(find.text('Clear Search & Filters'), findsOneWidget);

      // Tap Clear Search & Filters
      await tester.tap(find.text('Clear Search & Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Python Essentials'), findsOneWidget);
      expect(find.text('Java Multithreading & Memory Model'), findsOneWidget);
    });
  });
}
