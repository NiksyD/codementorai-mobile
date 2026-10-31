import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/social_auth_buttons.dart';
import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

import '../../profile/data/supabase_profile_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Dismiss keyboard on submit
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await widget.authRepository.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      const profileRepo = SupabaseProfileRepository();
      final profile = await profileRepo.getProfile(user.id);

      // Restrict access: mobile is strictly for learners. Mentors and Admins must use the web portal.
      if (!SupabaseProfileRepository.isRoleAllowedOnMobile(profile?.role)) {
        await widget.authRepository.signOut();
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        const String restrictedMsg =
            'Access restricted. Mentor and Admin workspaces are available on the web portal only.';
        setState(() {
          _errorMessage = restrictedMsg;
        });
        AppToast.showError(context, restrictedMsg);
        return;
      }

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      AppToast.showSuccess(context, 'Signed in successfully!');

      final bool hasCompleted =
          profile?.userOnboarded ??
          ((profile?.firstName?.isNotEmpty ?? false) &&
              (profile?.lastName?.isNotEmpty ?? false));
      if (!mounted) return;

      if (!hasCompleted) {
        context.go('/onboarding');
      } else {
        context.go('/dashboard');
      }
    } catch (error) {
      if (!mounted) return;

      HapticFeedback.heavyImpact();
      final String rawMsg = error
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('AuthException: ', '');
      setState(() {
        _errorMessage = rawMsg;
      });
      AppToast.showError(context, rawMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 12.0),

                    // Brand Logo & Header (Matching Web Parity)
                    Center(
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 52.0,
                        height: 52.0,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // App Brand Title
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24.0,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.4,
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
                    ),
                    const SizedBox(height: 28.0),

                    // Error Banner if Login Failed (Matching Web Styling)
                    if (_errorMessage != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 18.0,
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20.0),
                    ],

                    // Email Address Field
                    Text(
                      'Email Address',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.email],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        color: textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'jane.doe@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20.0),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email address is required';
                        }
                        final bool isValidEmail = RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(value.trim());
                        if (!isValidEmail) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18.0),

                    // Password Field Header with Forgot? Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Password',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Forgot password',
                          child: TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.push('/forgot-password');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 2.0,
                              ),
                              minimumSize: const Size(48.0, 32.0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        color: textPrimary,
                      ),
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20.0),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20.0,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          constraints: const BoxConstraints(
                            minWidth: 48.0,
                            minHeight: 48.0,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24.0),

                    // Primary Sign In Button (WCAG Min 48dp height)
                    // Primary Sign In Button (Matching Web Solid bg-primary with on-primary text)
                    SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20.0,
                                width: 20.0,
                                child: CircularProgressIndicator(
                                  color: isDark ? AppColors.onPrimaryDark : Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.onPrimaryDark : Colors.white,
                                ),
                              ),
                      ),
                    ),

                    // Social Auth Providers (Google & GitHub)
                    SocialAuthButtons(authRepository: widget.authRepository),
                    const SizedBox(height: 24.0),

                    // Account Switch Footer
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Go to registration screen',
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.push('/register');
                              },
                              borderRadius: BorderRadius.circular(6.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 6.0,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push('/register');
                            },
                            borderRadius: BorderRadius.circular(6.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 6.0,
                              ),
                              child: Text(
                                'Sign Up',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
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
