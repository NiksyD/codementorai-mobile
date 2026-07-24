import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/hero_animations.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future<void>.delayed(const Duration(milliseconds: 2000));

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
          context.go('/profile-setup');
        } else {
          context.go('/dashboard');
        }
      } else {
        context.go('/onboarding');
      }
    } catch (_) {
      if (!mounted) return;
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFF0B0F17),
              Color(0xFF131B2E),
              Color(0xFF1E1B4B),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const AILogoSplashStage(),
                  const SizedBox(height: 28.0),
                  Text(
                    'CodeMentor AI',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'AI-Powered Adaptive Mentorship',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.darkTextSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 48.0),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
