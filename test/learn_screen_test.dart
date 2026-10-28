import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/data/pathway_repository.dart';
import 'package:codementorai_mobile/src/features/learn/domain/learn_dashboard_data.dart';
import 'package:codementorai_mobile/src/features/learn/domain/module_detail_model.dart';
import 'package:codementorai_mobile/src/features/learn/domain/pathway_model.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/learn_screen.dart';
import 'package:codementorai_mobile/src/features/notifications/data/notification_repository.dart';
import 'package:codementorai_mobile/src/features/notifications/domain/notification_model.dart';
import 'package:codementorai_mobile/src/features/profile/data/profile_repository.dart';
import 'package:codementorai_mobile/src/features/profile/domain/profile_model.dart';

class FakeLearnPathwayRepository implements PathwayRepository {
  FakeLearnPathwayRepository(this.dashboardData);

  final LearnDashboardData dashboardData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<LearnDashboardData> getLearnDashboardData(String userId) async {
    return dashboardData;
  }

  @override
  Future<List<PathwayModel>> getAllModules(String userId) async =>
      dashboardData.allPathways;

  @override
  Future<bool> enrollModule(String userId, String moduleId) async => true;

  @override
  Future<bool> toggleBookmark(
    String userId,
    String moduleId,
    bool isBookmarked,
  ) async =>
      true;

  @override
  Future<List<DashboardSubmission>> getUserSubmissions(String userId) async =>
      dashboardData.submissions;

  @override
  ModuleDetailModel? getCachedModuleDetails(String moduleId) => null;

  @override
  Future<List<dynamic>> getLearnerRooms(String userId) async =>
      const <dynamic>[];

  @override
  Future<Map<String, dynamic>> joinRoom({
    required String code,
    required String userId,
  }) async =>
      const <String, dynamic>{'success': true};
}

class FakeLearnProfileRepository implements ProfileRepository {
  FakeLearnProfileRepository(this.profile);

  final ProfileModel? profile;

  @override
  Future<ProfileModel?> getProfile(String userId) async => profile;

  @override
  Future<void> saveProfile(ProfileModel profile) async {}

  @override
  Future<bool> hasCompletedProfile(String userId) async => true;
}

class FakeLearnNotificationRepository implements NotificationRepository {
  FakeLearnNotificationRepository(this.notifications);

  final List<NotificationModel> notifications;

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async =>
      notifications;

  @override
  Future<bool> markAsRead(String notificationId, String userId) async => true;

  @override
  Future<bool> markAllAsRead(String userId) async => true;

  @override
  Future<bool> clearAll(String userId) async => true;
}

void main() {
  group('LearnScreen Widget Tests (Web 1:1 Redesign Parity)', () {
    const PathwayModel samplePathway = PathwayModel(
      id: 'python-core-101',
      title: 'Python Essentials',
      description: 'Master idiomatic Python through interactive exercises.',
      language: 'python',
      stack: <String>['python'],
      status: 'In Progress',
      completion: 45,
      totalModules: 10,
      currentModule: 'Variables & Data Types',
    );

    const ProfileModel sampleProfile = ProfileModel(
      userId: 'user-test-1',
      email: 'alex@example.com',
      firstName: 'Alex',
      lastName: 'Rivera',
    );

    final LearnDashboardData sampleData = LearnDashboardData(
      activePathway: samplePathway,
      enrolledPathways: const <PathwayModel>[samplePathway],
      allPathways: const <PathwayModel>[samplePathway],
      currentStreak: 4,
      totalActiveDays: 12,
      easySolved: 5,
      mediumSolved: 2,
      hardSolved: 0,
      submissions: <DashboardSubmission>[
        DashboardSubmission(
          id: 'sub-1',
          itemId: 'item-1',
          title: 'Hello Variables',
          module: 'Python Essentials',
          difficulty: 'Easy',
          language: 'python',
          status: 'Passed',
          score: 100,
          submittedAt: DateTime.now(),
          rawDate: '2026-10-28',
        ),
      ],
    );

    testWidgets('Renders header with greeting, subtitle, My Hubs, and Bell', (
      WidgetTester tester,
    ) async {
      final fakePathwayRepo = FakeLearnPathwayRepository(sampleData);
      final fakeProfileRepo = FakeLearnProfileRepository(sampleProfile);
      final fakeNotifRepo = FakeLearnNotificationRepository(const <NotificationModel>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: LearnScreen(
            pathwayRepository: fakePathwayRepo,
            profileRepository: fakeProfileRepo,
            notificationRepository: fakeNotifRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header Greeting (AGENTS.md 1.1: "Welcome back," with comma, no emoji)
      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);

      // My Hubs Action Button
      expect(find.text('My Hubs'), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);

      // Notification Bell
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    testWidgets('Renders Split-Block Hero Card matching web 1:1', (
      WidgetTester tester,
    ) async {
      final fakePathwayRepo = FakeLearnPathwayRepository(sampleData);
      final fakeProfileRepo = FakeLearnProfileRepository(sampleProfile);
      final fakeNotifRepo = FakeLearnNotificationRepository(const <NotificationModel>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: LearnScreen(
            pathwayRepository: fakePathwayRepo,
            profileRepository: fakeProfileRepo,
            notificationRepository: fakeNotifRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Upper Block: MODULE kicker + Title + Description + View all topics
      expect(find.text('MODULE'), findsOneWidget);
      expect(find.text('Python Essentials'), findsOneWidget);
      expect(find.text('Master idiomatic Python through interactive exercises.'), findsOneWidget);
      expect(find.text('View all topics'), findsOneWidget);

      // Lower Block: TOPIC kicker + Target Topic + Progress + Continue Learning CTA
      expect(find.text('TOPIC 1'), findsOneWidget);
      expect(find.text('Variables & Data Types'), findsOneWidget);
      expect(find.text('45% Complete'), findsOneWidget);
      expect(find.text('Continue Learning'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Activity Heatmap
      expect(find.text('Practice Activity'), findsOneWidget);
    });

    testWidgets('Renders Start Learning CTA when completion is 0%', (
      WidgetTester tester,
    ) async {
      const PathwayModel unstartedPathway = PathwayModel(
        id: 'python-core-101',
        title: 'Python Essentials',
        description: 'Master idiomatic Python.',
        language: 'python',
        stack: <String>['python'],
        status: 'Not Started',
        completion: 0,
        totalModules: 10,
        currentModule: 'Getting Started',
      );

      final LearnDashboardData unstartedData = LearnDashboardData(
        activePathway: unstartedPathway,
        enrolledPathways: const <PathwayModel>[unstartedPathway],
        allPathways: const <PathwayModel>[unstartedPathway],
        currentStreak: 0,
        totalActiveDays: 0,
        easySolved: 0,
        mediumSolved: 0,
        hardSolved: 0,
      );

      final fakePathwayRepo = FakeLearnPathwayRepository(unstartedData);
      final fakeProfileRepo = FakeLearnProfileRepository(sampleProfile);
      final fakeNotifRepo = FakeLearnNotificationRepository(const <NotificationModel>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: LearnScreen(
            pathwayRepository: fakePathwayRepo,
            profileRepository: fakeProfileRepo,
            notificationRepository: fakeNotifRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0% Complete'), findsOneWidget);
      expect(find.text('Start Learning'), findsOneWidget);
    });
  });
}
