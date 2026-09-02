import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/password_reset_storage.dart';
import '../data/supabase_auth_repository.dart';
import '../../profile/data/supabase_profile_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  late AnimationController _cursorController;
  late Animation<double> _cursorFade;

  @override
  void initState() {
    super.initState();

    // Entrance Animation (Logo and Typography)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Blinking Cursor Animation for Developer Terminal feel
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);

    _cursorFade = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _cursorController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Elegant dwell time for branded reveal
    await Future<void>.delayed(const Duration(milliseconds: 1800));

    try {
      final bool isResetPending = await PasswordResetStorage.isResetPending();
      final session = Supabase.instance.client.auth.currentSession;
      final String provider =
          session?.user.appMetadata['provider'] as String? ?? '';
      final dynamic amrList = session?.user.appMetadata['amr'];
      final bool isRecovery =
          provider == 'recovery' ||
          (amrList is List &&
              amrList.any(
                (dynamic item) => item is Map && item['method'] == 'recovery',
              ));

      if (!mounted) return;

      if (isResetPending || isRecovery) {
        context.go('/reset-password');
        return;
      }

      final user = await widget.authRepository.getCurrentUser();
      if (!mounted) return;

      if (user != null) {
        final profileRepo = const SupabaseProfileRepository();
        final bool hasCompleted = await profileRepo.hasCompletedProfile(
          user.id,
        );
        if (!mounted) return;

        if (!hasCompleted) {
          context.go('/onboarding');
        } else {
          context.go('/dashboard');
        }
      } else {
        context.go('/login');
      }
    } catch (_) {
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Center Stage: Logo, Brand Typography, and Terminal Prompt
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Clean Standalone Brand Logo
                      Image.asset(
                        'assets/images/app_logo.png',
                        width: 64.0,
                        height: 64.0,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20.0),

                      // Brand Name Typography
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26.0,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkTextPrimary,
                            letterSpacing: -0.5,
                          ),
                          children: const <TextSpan>[
                            TextSpan(text: 'CodeMentor'),
                            TextSpan(
                              text: 'AI',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10.0),

                      // High-Tech Terminal Command Line Prompt
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '> ai_workspace.boot()',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                              color: AppColors.darkTextSecondary.withValues(alpha: 0.75),
                            ),
                          ),
                          FadeTransition(
                            opacity: _cursorFade,
                            child: Text(
                              '_',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Status: Minimalist 2px Progress Bar & Monospace Indicator
            Positioned(
              left: 48.0,
              right: 48.0,
              bottom: 36.0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 2px Sleek Linear Progress Line
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2.0),
                      child: SizedBox(
                        height: 2.0,
                        child: LinearProgressIndicator(
                          backgroundColor: AppColors.darkBorder.withValues(alpha: 0.5),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Heartbeat Status Text
                    Text(
                      'INITIALIZING WORKSPACE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: AppColors.darkTextSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
