import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/data/pathway_repository.dart';
import 'package:codementorai_mobile/src/features/learn/domain/room_model.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/rooms_screen.dart';

class FakeRoomsPathwayRepository implements PathwayRepository {
  FakeRoomsPathwayRepository({
    this.rooms = const <RoomModel>[],
  });

  final List<RoomModel> rooms;
  String? lastAcceptedId;
  String? lastDeclinedId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<dynamic>> getLearnerRooms(String userId) async {
    return rooms;
  }

  @override
  Future<bool> acceptRoomInvitation(String roomId) async {
    lastAcceptedId = roomId;
    return true;
  }

  @override
  Future<bool> declineRoomInvitation(String roomId) async {
    lastDeclinedId = roomId;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<RoomModel> mockRooms = <RoomModel>[
    const RoomModel(
      id: 'room-1',
      name: 'Web Dev Cohort 2026',
      section: 'CS-101',
      joinCode: 'WD2026',
      targetLanguage: 'php',
      description: 'Full-stack PHP and backend engineering collaborative cohort.',
      status: 'active',
      mentorName: 'Sarah Connor',
      curriculumModules: <RoomModuleSummary>[
        RoomModuleSummary(
          id: 'mod-1',
          title: 'React Fundamentals',
          description: 'Learn modern React hooks and state management.',
          topicsCount: 4,
          activitiesCount: 8,
        ),
      ],
      completedActivitiesCount: 4,
    ),
    const RoomModel(
      id: 'room-2',
      name: 'Algorithms Masterclass',
      section: 'ALG-A',
      joinCode: 'ALGS01',
      targetLanguage: 'python',
      description: 'Data structures, graph algorithms, and dynamic programming.',
      status: 'active',
      mentorName: 'Alan Turing',
      curriculumModules: <RoomModuleSummary>[
        RoomModuleSummary(
          id: 'mod-2',
          title: 'Graph Theory',
          description: 'Traversals and shortest paths.',
          topicsCount: 2,
          activitiesCount: 6,
        ),
      ],
      completedActivitiesCount: 6, // 100% completed
    ),
    const RoomModel(
      id: 'room-3',
      name: 'Mobile Flutter Lab',
      section: 'MOB-1',
      joinCode: 'FLUT99',
      targetLanguage: 'dart',
      description: 'Cross-platform mobile apps with Flutter.',
      status: 'pending',
      joinedVia: 'email_invite',
      mentorName: 'Ada Lovelace',
    ),
    const RoomModel(
      id: 'room-4',
      name: 'Systems Programming',
      section: 'SYS-3',
      joinCode: 'RUST42',
      targetLanguage: 'rust',
      description: 'Memory safety and low-level concurrency.',
      status: 'pending',
      joinedVia: 'code',
      mentorName: 'Linus Torvalds',
    ),
  ];

  Widget createSubject({required PathwayRepository repo}) {
    return MaterialApp(
      home: RoomsScreen(pathwayRepository: repo),
    );
  }

  void setMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('RoomsScreen Widget Tests (Web /learn/hubs 1:1 Redesign Parity)', () {
    testWidgets('Renders header with My Hubs, caption, and Join Hub button',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('My Hubs'), findsOneWidget);
      expect(
        find.text(
            'Access your enrolled hubs, collaborate with mentors, and track your progress.'),
        findsOneWidget,
      );
      expect(find.text('Join Hub'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('Renders search input and filter tabs with dynamic counts',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      // Search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search hubs...'), findsOneWidget);

      // Filter tabs
      expect(find.text('All Hubs'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);

      // Total count: 4, Active: 2, Pending: 2
      expect(find.text('4'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('Renders pending email invitations alert banner',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('You have a pending hub invitation'), findsOneWidget);
      expect(
        find.text(
            'Accept your invitation below to join the cohort and access learning modules.'),
        findsOneWidget,
      );
      expect(find.text('Action Needed'), findsOneWidget);
      expect(find.byIcon(Icons.mark_email_unread_rounded), findsOneWidget);
    });

    testWidgets('Filters hubs when tapping Active and Pending tabs',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      // Initially shows all 4
      expect(find.text('Web Dev Cohort 2026'), findsOneWidget);
      expect(find.text('Algorithms Masterclass'), findsOneWidget);
      expect(find.text('Mobile Flutter Lab'), findsOneWidget);
      expect(find.text('Systems Programming'), findsOneWidget);

      // Tap 'Active' tab
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      expect(find.text('Web Dev Cohort 2026'), findsOneWidget);
      expect(find.text('Algorithms Masterclass'), findsOneWidget);
      expect(find.text('Mobile Flutter Lab'), findsNothing);
      expect(find.text('Systems Programming'), findsNothing);

      // Tap 'Pending' tab
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Web Dev Cohort 2026'), findsNothing);
      expect(find.text('Algorithms Masterclass'), findsNothing);
      expect(find.text('Mobile Flutter Lab'), findsOneWidget);
      expect(find.text('Systems Programming'), findsOneWidget);
    });

    testWidgets('Filters hubs with search query and handles clear search',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      // Enter search term
      await tester.enterText(find.byType(TextField), 'Algorithms');
      await tester.pumpAndSettle();

      expect(find.text('Algorithms Masterclass'), findsOneWidget);
      expect(find.text('Web Dev Cohort 2026'), findsNothing);
      expect(find.text('Mobile Flutter Lab'), findsNothing);

      // Clear search button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Web Dev Cohort 2026'), findsOneWidget);
      expect(find.text('Algorithms Masterclass'), findsOneWidget);
    });

    testWidgets('Renders correct CTA buttons for Active, Completed, Pending, and Email Invite',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      // Active in-progress: Continue
      expect(find.text('Continue'), findsOneWidget);

      // Completed (100%): Review Hub
      expect(find.text('Review Hub'), findsOneWidget);

      // Code pending: View Status
      expect(find.text('View Status'), findsOneWidget);

      // Email invite: Accept & Decline buttons
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('Handles Accept invitation directly on the card',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept'));
      await tester.pump();

      expect(repo.lastAcceptedId, 'room-3');
    });

    testWidgets('Renders empty search state when no hubs match query',
        (WidgetTester tester) async {
      setMobileViewport(tester);
      final FakeRoomsPathwayRepository repo =
          FakeRoomsPathwayRepository(rooms: mockRooms);

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NonexistentQuery');
      await tester.pumpAndSettle();

      expect(find.text('No hubs matching "NonexistentQuery"'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);
    });
  });
}
