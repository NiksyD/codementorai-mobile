import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/common_widgets/app_toast.dart';
import 'src/constants/app_theme.dart';
import 'src/features/auth/data/password_reset_storage.dart';
import 'src/features/profile/data/supabase_profile_repository.dart';
import 'src/routing/app_router.dart';
import 'src/theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Initialize Supabase client
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const CodeMentorApp());
}

class CodeMentorApp extends StatefulWidget {
  const CodeMentorApp({super.key});

  @override
  State<CodeMentorApp> createState() => _CodeMentorAppState();
}

class _CodeMentorAppState extends State<CodeMentorApp> {
  @override
  void initState() {
    super.initState();
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final AuthChangeEvent event = data.event;
        final bool isResetPending = await PasswordResetStorage.isResetPending();

        if (isResetPending || event == AuthChangeEvent.passwordRecovery) {
          appRouter.go('/reset-password');
        } else if (event == AuthChangeEvent.signedOut) {
          appRouter.go('/login');
        } else if (event == AuthChangeEvent.signedIn) {
          final session = data.session;
          if (session != null) {
            const profileRepo = SupabaseProfileRepository();
            final profile = await profileRepo.getProfile(session.user.id);

            // Restrict access: mobile is strictly for learners.
            if (!SupabaseProfileRepository.isRoleAllowedOnMobile(
              profile?.role,
            )) {
              await Supabase.instance.client.auth.signOut();
              appRouter.go('/login');
              final navContext = rootNavigatorKey.currentContext;
              if (navContext != null && navContext.mounted) {
                AppToast.showError(
                  navContext,
                  'Access restricted. Mentor and Admin workspaces are available on the web portal only.',
                );
              }
              return;
            }

            final bool hasCompleted =
                profile?.userOnboarded ??
                ((profile?.firstName?.isNotEmpty ?? false) &&
                    (profile?.lastName?.isNotEmpty ?? false));
            if (!hasCompleted) {
              appRouter.go('/onboarding');
            } else {
              appRouter.go('/dashboard');
            }
          }
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeController,
      builder: (BuildContext context, ThemeMode mode, Widget? child) {
        return MaterialApp.router(
          title: 'CodeMentor AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
