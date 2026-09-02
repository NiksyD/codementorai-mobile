import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/password_reset_storage.dart';
import '../data/supabase_auth_repository.dart';
import '../../profile/data/supabase_profile_repository.dart';

import '../../learn/data/supabase_pathway_repository.dart';
import '../../profile/domain/profile_model.dart';

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
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineFade;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Staggered Entrance Animation (Apple / Linear style)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Ambient Breathing Aura
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Elegant branded dwell time
    await Future<void>.delayed(const Duration(milliseconds: 1900));

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
        final pathwayRepo = const SupabasePathwayRepository();

        // Concurrently fetch profile & dashboard data during splash animation
        final results = await Future.wait([
          profileRepo.getProfile(user.id),
          pathwayRepo.getLearnDashboardData(user.id),
        ]);

        if (!mounted) return;

        final ProfileModel? profile = results[0] as ProfileModel?;
        final bool hasCompleted = (profile?.firstName?.isNotEmpty ?? false) &&
            (profile?.lastName?.isNotEmpty ?? false);

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 1. Ambient Background Glow (Subtle Breathing Aura)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (BuildContext context, Widget? child) {
              return Container(
                width: 280.0 * _pulseAnimation.value,
                height: 280.0 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.primary.withValues(
                        alpha: 0.12 * _pulseAnimation.value,
                      ),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Center Brand Presentation
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Logo with Spring Animation
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 72.0,
                      height: 72.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 32.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22.0),

                // Brand Name Typography
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 27.0,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkTextPrimary,
                          letterSpacing: -0.6,
                        ),
                        children: const <TextSpan>[
                          TextSpan(text: 'CodeMentor'),
                          TextSpan(
                            text: 'AI',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),

                // Clean Modern Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: Text(
                      'Master code with AI mentorship',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkTextSecondary.withValues(alpha: 0.8),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
