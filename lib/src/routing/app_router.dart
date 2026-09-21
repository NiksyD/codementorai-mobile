import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/verify_otp_screen.dart';
import '../features/dashboard/presentation/main_shell_screen.dart';
import '../features/learn/presentation/activity_screen.dart';
import '../features/learn/presentation/assessment_attempt_screen.dart';
import '../features/learn/presentation/assessments_screen.dart';
import '../features/learn/presentation/challenge_screen.dart';
import '../features/learn/presentation/module_detail_screen.dart';
import '../features/learn/domain/room_model.dart';
import '../features/learn/presentation/practice_screen.dart';
import '../features/learn/presentation/room_detail_screen.dart';
import '../features/learn/presentation/rooms_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_setup_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/rooms',
      builder: (BuildContext context, GoRouterState state) =>
          const RoomsScreen(),
    ),
    GoRoute(
      path: '/learn/rooms',
      builder: (BuildContext context, GoRouterState state) =>
          const RoomsScreen(),
    ),
    GoRoute(
      path: '/rooms/:id',
      builder: (BuildContext context, GoRouterState state) {
        final String roomId = state.pathParameters['id'] ?? '';
        final RoomModel? room = state.extra as RoomModel?;
        return RoomDetailScreen(roomId: roomId, initialRoom: room);
      },
    ),
    GoRoute(
      path: '/learn/classrooms/:id',
      builder: (BuildContext context, GoRouterState state) {
        final String roomId = state.pathParameters['id'] ?? '';
        final RoomModel? room = state.extra as RoomModel?;
        return RoomDetailScreen(roomId: roomId, initialRoom: room);
      },
    ),
    GoRoute(
      path: '/activity',
      builder: (BuildContext context, GoRouterState state) =>
          const ActivityScreen(showBackButton: true),
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) =>
          const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (BuildContext context, GoRouterState state) =>
          const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (BuildContext context, GoRouterState state) =>
          const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (BuildContext context, GoRouterState state) {
        final String email = state.uri.queryParameters['email'] ?? '';
        return VerifyOtpScreen(email: email);
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (BuildContext context, GoRouterState state) =>
          const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (BuildContext context, GoRouterState state) =>
          const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (BuildContext context, GoRouterState state) =>
          const MainShellScreen(),
    ),
    GoRoute(
      path: '/learn',
      builder: (BuildContext context, GoRouterState state) =>
          const MainShellScreen(),
    ),
    GoRoute(
      path: '/assessments',
      builder: (BuildContext context, GoRouterState state) =>
          const AssessmentsScreen(),
    ),
    GoRoute(
      path: '/assessments/:id/take',
      builder: (BuildContext context, GoRouterState state) {
        final String assessmentId = state.pathParameters['id'] ?? '';
        return AssessmentAttemptScreen(assessmentId: assessmentId);
      },
    ),
    GoRoute(
      path: '/modules/:id',
      builder: (BuildContext context, GoRouterState state) {
        final String moduleId = state.pathParameters['id'] ?? '';
        return ModuleDetailScreen(moduleId: moduleId);
      },
    ),
    GoRoute(
      path: '/modules/:id/practice/:exerciseId',
      builder: (BuildContext context, GoRouterState state) {
        final String moduleId = state.pathParameters['id'] ?? '';
        final String exerciseId = state.pathParameters['exerciseId'] ?? '';
        return PracticeScreen(
          moduleId: moduleId,
          exerciseId: exerciseId,
        );
      },
    ),
    GoRoute(
      path: '/modules/:id/challenges/:challengeId',
      builder: (BuildContext context, GoRouterState state) {
        final String moduleId = state.pathParameters['id'] ?? '';
        final String challengeId = state.pathParameters['challengeId'] ?? '';
        return ChallengeScreen(
          moduleId: moduleId,
          challengeId: challengeId,
        );
      },
    ),
  ],
);
