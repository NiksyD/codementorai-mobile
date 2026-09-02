import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import 'app_toast.dart';

class SocialAuthButtons extends StatefulWidget {
  const SocialAuthButtons({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends State<SocialAuthButtons> {
  bool _isGoogleLoading = false;
  bool _isGithubLoading = false;

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      await widget.authRepository.signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, 'Google Sign-In Error: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _handleGithubSignIn() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isGithubLoading = true;
    });

    try {
      await widget.authRepository.signInWithGithub();
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, 'GitHub Sign-In Error: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isGithubLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      children: <Widget>[
        const SizedBox(height: 24.0),
        // Divider Line with JetBrains Mono Text (matching web parity)
        Row(
          children: <Widget>[
            Expanded(
              child: Divider(
                color: borderColor.withValues(alpha: 0.6),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                'OR CONTINUE WITH',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: textColor.withValues(alpha: 0.75),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: borderColor.withValues(alpha: 0.6),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18.0),

        // GitHub and Google OAuth Buttons Row
        Row(
          children: <Widget>[
            // GitHub Button
            Expanded(
              child: _SocialButton(
                icon: FontAwesomeIcons.github,
                label: 'GitHub',
                isLoading: _isGithubLoading,
                onPressed: (_isGoogleLoading || _isGithubLoading) ? null : _handleGithubSignIn,
              ),
            ),
            const SizedBox(width: 12.0),
            // Google Button
            Expanded(
              child: _SocialButton(
                icon: FontAwesomeIcons.google,
                label: 'Google',
                isLoading: _isGoogleLoading,
                onPressed: (_isGoogleLoading || _isGithubLoading) ? null : _handleGoogleSignIn,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final FaIconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Semantics(
      button: true,
      label: 'Sign in with $label',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46.0),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12.0),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          FaIcon(
                            icon,
                            size: 16.0,
                            color: textColor,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
