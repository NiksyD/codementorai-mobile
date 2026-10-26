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

      // Preferences items
      expect(find.text('Appearance'), findsOneWidget);

      // Sign Out
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('CodeMentor AI v1.0.0 (Build 42)'), findsOneWidget);
    });
  });
}
