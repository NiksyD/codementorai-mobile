import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
    return Column(
      children: <Widget>[
        const SizedBox(height: 24.0),
        // Divider Line with Text
        Row(
          children: <Widget>[
            Expanded(
              child: Divider(
                color: AppColors.darkBorder.withValues(alpha: 0.7),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.darkTextSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColors.darkBorder.withValues(alpha: 0.7),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20.0),

        // GitHub and Google OAuth Buttons Row using FontAwesomeIcons library
        Row(
          children: <Widget>[
            // GitHub Button
            Expanded(
              child: _SocialButton(
                icon: FontAwesomeIcons.github,
                label: 'GitHub',
                isLoading: _isGithubLoading,
                onPressed: _handleGithubSignIn,
              ),
            ),
            const SizedBox(width: 14.0),
            // Google Button
            Expanded(
              child: _SocialButton(
                icon: FontAwesomeIcons.google,
                label: 'Google',
                isLoading: _isGoogleLoading,
                onPressed: _handleGoogleSignIn,
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppColors.darkBorder, width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
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
                      FaIcon(icon, size: 18.0, color: Colors.white),
                      const SizedBox(width: 10.0),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
