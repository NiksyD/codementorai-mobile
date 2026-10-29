import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/auth/data/auth_repository.dart';
import 'package:codementorai_mobile/src/features/profile/data/profile_repository.dart';
import 'package:codementorai_mobile/src/features/profile/domain/profile_model.dart';
import 'package:codementorai_mobile/src/features/profile/presentation/profile_screen.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile});

  final ProfileModel? profile;

  @override
  Future<ProfileModel?> getProfile(String userId) async => profile;

  @override
  Future<void> saveProfile(ProfileModel profile) async {}

  @override
  Future<bool> hasCompletedProfile(String userId) async => true;
}

void main() {
  group('ProfileScreen Widget Tests (WCAG & Shadcn Parity)', () {
    const ProfileModel sampleProfile = ProfileModel(
      userId: 'user-123',
      email: 'alex.developer@codementorai.dev',
      firstName: 'Alex',
      lastName: 'Dev',
      role: 'student',
    );

    testWidgets('Renders Profile & Settings header, cards, and sections', (WidgetTester tester) async {
      final FakeAuthRepository authRepo = FakeAuthRepository();
      final FakeProfileRepository profileRepo = FakeProfileRepository(profile: sampleProfile);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: ProfileScreen(
            authRepository: authRepo,
            profileRepository: profileRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header
      expect(find.text('Profile & Settings'), findsOneWidget);

      // Section Kickers
      expect(find.text('ACCOUNT DETAILS'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SECURITY & LEGAL'), findsOneWidget);

      // Account items
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);

      // Trailing Affordances: Display Name has chevron (>), Email Address has lock
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);

      // Preferences items
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Light Theme'), findsOneWidget);

      // Tap email address shows informative toast
      await tester.tap(find.text('Email Address'));
      await tester.pump();
      expect(
        find.text('Email address is linked to your account and cannot be modified.'),
        findsOneWidget,
      );

      // Sign Out
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('CodeMentor AI v1.0.0 (Build 42)'), findsOneWidget);
    });

    testWidgets('Renders Dark Theme labels correctly in dark mode', (WidgetTester tester) async {
      final FakeAuthRepository authRepo = FakeAuthRepository();
      final FakeProfileRepository profileRepo = FakeProfileRepository(profile: sampleProfile);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfileScreen(
            authRepository: authRepo,
            profileRepository: profileRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Dark Theme'), findsOneWidget);
    });
  });
}
