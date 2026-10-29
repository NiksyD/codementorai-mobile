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
import 'package:codementorai_mobile/src/features/learn/presentation/activity_submission_review_screen.dart';

class MockReviewPathwayRepository implements PathwayRepository {
  MockReviewPathwayRepository({required this.review});

  final ActivitySubmissionReviewModel review;

  @override
  Future<ActivitySubmissionReviewModel?> getSubmissionReview(
    String submissionId, {
    DashboardSubmission? cachedSubmission,
  }) async =>
      review;

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
        submissions: <DashboardSubmission>[],
      );

  @override
  Future<List<PathwayModel>> getAllModules(String userId) async =>
      const <PathwayModel>[];

  @override
  Future<bool> enrollModule(String userId, String moduleId) async => true;

  @override
  Future<bool> unlockModuleWithCoins(String userId, String moduleId, int coins) async => true;

  @override
  Future<bool> isModulePurchased(String userId, String moduleId) async => true;

  @override
  Future<bool> toggleBookmark(
    String userId,
    String moduleId,
    bool isBookmarked,
  ) async =>
      true;

  @override
  ModuleDetailModel? getCachedModuleDetails(String moduleId) => null;

  @override
  Future<ModuleDetailModel?> getModuleDetails(
    String moduleId,
    String userId,
  ) async =>
      null;

  @override
  Future<PracticeExerciseModel?> getPracticeExercise(
    String moduleId,
    String exerciseId,
    String userId,
  ) async =>
      null;

  @override
  Future<String?> submitPracticeExercise(
    String userId,
    String moduleId,
    String exerciseId,
    String code,
    String language,
  ) async =>
      'test-submission-id';

  @override
  Future<PracticeExerciseModel?> getChallengeExercise(
    String moduleId,
    String challengeId,
    String userId,
  ) async =>
      null;

  @override
  Future<String?> submitChallengeExercise(
    String userId,
    String moduleId,
    String challengeId,
    String code,
    String language,
  ) async =>
      'test-submission-id';

  @override
  Future<List<SubmissionHistoryModel>> getExerciseSubmissions({
    required String userId,
    required String moduleId,
    required String exerciseId,
  }) async =>
      const <SubmissionHistoryModel>[];

  @override
  Future<List<DashboardSubmission>> getUserSubmissions(String userId) async =>
      const <DashboardSubmission>[];

  @override
  Future<List<ModuleReviewModel>> getModuleReviews(String moduleId) async =>
      const <ModuleReviewModel>[];

  @override
  Future<bool> submitModuleReview({
    required String moduleId,
    required String userId,
    required int rating,
    required String comment,
  }) async =>
      true;

  @override
  Future<Map<String, dynamic>?> getActiveModuleReport({
    required String moduleId,
    required String userId,
    String? activityId,
  }) async =>
      null;

  @override
  Future<bool> submitModuleReport({
    required String moduleId,
    required String userId,
    required String reason,
    required String details,
    String? activityId,
  }) async =>
      true;

  @override
  Future<List<dynamic>> getLearnerRooms(String userId) async =>
      const <dynamic>[];

  @override
  Future<Map<String, dynamic>> joinRoom({
    required String code,
    required String userId,
  }) async =>
      const <String, dynamic>{'success': true};

  @override
  Future<bool> acceptRoomInvitation(String roomId) async => true;

  @override
  Future<bool> declineRoomInvitation(String roomId) async => true;
}

void main() {
  final ActivitySubmissionReviewModel sampleReview =
      ActivitySubmissionReviewModel(
    submissionId: '73771383-1ccc-4826-80c0-e1f28910a900',
    itemId: 'bad76bd7-4913-4856-8205-1e30495f5d80',
    title: 'Modern Switch Expressions and Short-Circuit Evaluation',
    moduleTitle: 'Java Basic Syntax',
    moduleId: 'java-basic-syntax-7968',
    difficulty: 'Easy',
    language: 'java',
    submittedCode: '''import java.util.Scanner;

public class Solution {
    public static void main(String[] args) {
        System.out.println("Hello");
    }
}''',
    status: 'accepted',
    verdict: 'Accepted',
    submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
    targetTime: 'O(1)',
    targetSpace: 'O(1)',
    acfEvaluation: AcfEvaluationModel(
      compositeScore: 96.26,
      executiveSummary:
          'Solution verified with optimal pattern matching switch syntax.',
      correctness: const AcfCriterionModel(
        id: 'correctness',
        label: 'Correctness',
        weight: '24.84%',
        score: 98,
        cotReasoning: 'All test assertions evaluated successfully.',
        strengths: <String>['Verified functional correctness.'],
        improvements: <String>['No critical regressions detected.'],
        edgeCaseStatus: 'Verified Edge Cases',
      ),
      readability: const AcfCriterionModel(
        id: 'readability',
        label: 'Readability',
        weight: '24.53%',
        score: 95,
        cotReasoning: 'Idiomatic switch arrow expression syntax.',
        strengths: <String>['Clean indentation and naming conventions.'],
        improvements: <String>['Maintain consistent variable naming.'],
      ),
      maintainability: const AcfCriterionModel(
        id: 'maintainability',
        label: 'Maintainability',
        weight: '25.16%',
        score: 92,
        cotReasoning: 'Modular design with encapsulated business rules.',
        strengths: <String>['No global state mutations.'],
        improvements: <String>['Consider separating I/O from parsing.'],
        modularityRating: 'High',
      ),
      efficiency: const AcfCriterionModel(
        id: 'efficiency',
        label: 'Efficiency',
        weight: '25.47%',
        score: 100,
        cotReasoning: 'Constant time lookup with zero dynamic allocations.',
        strengths: <String>['Optimal O(1) time and space complexity.'],
        improvements: <String>['Peak performance achieved.'],
        detectedTime: 'O(1)',
        detectedSpace: 'O(1)',
      ),
      recommendedRefactoring: const AcfRefactoringModel(
        explanation: 'Refactored to eliminate scanner leaks.',
        refactoredCode: '''import java.util.Scanner;

public class RefactoredSolution {
    public static void main(String[] args) {
        // Refactored clean code
    }
}''',
      ),
    ),
    mentorFeedback: const MentorFeedbackModel(
      id: 'fb-1',
      feedbackText: 'Superb switch syntax usage!',
      status: 'published',
      mentorName: 'Sarah Connor',
    ),
  );

  group('ActivitySubmissionReviewScreen Widget Tests', () {
    testWidgets('Renders hero header, score, and all 4 ACF tabs', (
      WidgetTester tester,
    ) async {
      final MockReviewPathwayRepository repo =
          MockReviewPathwayRepository(review: sampleReview);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivitySubmissionReviewScreen(
            submissionId: sampleReview.submissionId,
            pathwayRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App Bar Title
      expect(find.text('Submission Review'), findsOneWidget);

      // Quiet Editorial Header & Inline Metadata
      expect(find.text('Verified Passed'), findsOneWidget);
      expect(find.text('All Tests Passed'), findsOneWidget);
      expect(
        find.text('Modern Switch Expressions and Short-Circuit Evaluation'),
        findsWidgets,
      );
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('RUNTIME'), findsOneWidget);
      expect(find.text('MEMORY'), findsOneWidget);

      // 4 ACF Tabs
      expect(find.text('Correctness'), findsOneWidget);
      expect(find.text('98'), findsOneWidget);

      expect(find.text('Readability'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);

      expect(find.text('Maintainability'), findsOneWidget);
      expect(find.text('92'), findsOneWidget);

      expect(find.text('Efficiency'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);

      // Mentor Feedback Row
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('Superb switch syntax usage!'), findsOneWidget);

      // Code Review Section
      expect(find.text('(solution.java)'), findsOneWidget);
      expect(find.text('Copy Code'), findsOneWidget);

      // Bottom action dock is removed (matching web)
      expect(find.text('Open Module'), findsNothing);
    });

    testWidgets('Tapping ACF tabs updates criterion reasoning', (
      WidgetTester tester,
    ) async {
      final MockReviewPathwayRepository repo =
          MockReviewPathwayRepository(review: sampleReview);

      await tester.pumpWidget(
        MaterialApp(
          home: ActivitySubmissionReviewScreen(
            submissionId: sampleReview.submissionId,
            pathwayRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Correctness is selected
      expect(
        find.text('All test assertions evaluated successfully.'),
        findsOneWidget,
      );

      // Tap Readability
      await tester.tap(find.text('Readability'));
      await tester.pumpAndSettle();

      expect(
        find.text('Idiomatic switch arrow expression syntax.'),
        findsOneWidget,
      );

      // Tap Efficiency
      await tester.tap(find.text('Efficiency'));
      await tester.pumpAndSettle();

      expect(
        find.text('Constant time lookup with zero dynamic allocations.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Displays submitted code with Solution filename without Mentor Refinement',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final MockReviewPathwayRepository repo =
            MockReviewPathwayRepository(review: sampleReview);

        await tester.pumpWidget(
          MaterialApp(
            home: ActivitySubmissionReviewScreen(
              submissionId: sampleReview.submissionId,
              pathwayRepository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Mentor refinement should not exist
        expect(find.textContaining('Mentor Refinement'), findsNothing);
        expect(find.text('Refactored.java'), findsNothing);

        // Submitted code solution header is displayed
        expect(find.text('(solution.java)'), findsOneWidget);
        expect(find.text('Copy Code'), findsOneWidget);
      },
    );
  });
}
