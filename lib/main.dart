import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/constants/app_theme.dart';
import 'src/features/auth/data/password_reset_storage.dart';
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
