import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/auth_error_banner.dart';
import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const int _resendSeconds = 60;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String _sentTo = '';
  String? _errorMessage;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = _resendSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Sends (or re-sends) the password reset link.
  Future<void> _sendResetLink({required bool isResend}) async {
    // Dismiss keyboard on submit
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!isResend && !(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.lightImpact();

    final String email = isResend ? _sentTo : _emailController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.authRepository.resetPasswordForEmail(email: email);

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      setState(() {
        _emailSent = true;
        _sentTo = email;
      });
      _startResendTimer();
      if (isResend) {
        AppToast.showSuccess(context, 'A new reset link has been sent');
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

  void _useDifferentEmail() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _emailSent = false;
      _errorMessage = null;
      _resendCountdown = 0;
    });
  }

  void _goBackToSignIn() {
    HapticFeedback.lightImpact();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
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
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color onPrimary = isDark ? AppColors.onPrimaryDark : Colors.white;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
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

                        Text(
                          _emailSent ? 'Check your email' : 'Reset your password',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24.0,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          _emailSent
                              ? 'We sent a password reset link to'
                              : "Enter your email address and we'll send you a link to reset your password.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: textSecondary,
                          ),
                        ),
                        if (_emailSent)
                          Text(
                            _sentTo,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                              color: textPrimary,
                            ),
                          ),
                        const SizedBox(height: 28.0),

                        if (_errorMessage != null) ...<Widget>[
                          AuthErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 20.0),
                        ],

                        if (!_emailSent) ...<Widget>[
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
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[AutofillHints.email],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              color: textPrimary,
                            ),
                            onFieldSubmitted: (_) =>
                                _sendResetLink(isResend: false),
                            decoration: const InputDecoration(
                              hintText: 'jane.doe@example.com',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                size: 20.0,
                              ),
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
                          const SizedBox(height: 24.0),

                          // Primary Button (WCAG Min 48dp height, solid primary like Sign In)
                          SizedBox(
                            height: 48.0,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _sendResetLink(isResend: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: onPrimary,
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
                                        color: onPrimary,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : Text(
                                      'Send Reset Link',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w700,
                                        color: onPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...<Widget>[
                          // Confirmation state
                          Container(
                            padding: const EdgeInsets.all(14.0),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(
                                  Icons.mark_email_read_outlined,
                                  color: AppColors.primary,
                                  size: 20.0,
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Text(
                                    'Open the email on this phone and tap "Reset password". The link opens CodeMentorAI so you can choose a new password.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          SizedBox(
                            height: 48.0,
                            child: OutlinedButton(
                              onPressed: (_isLoading || _resendCountdown > 0)
                                  ? null
                                  : () => _sendResetLink(isResend: true),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20.0,
                                      width: 20.0,
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : Text(
                                      _resendCountdown > 0
                                          ? 'Resend link in ${_resendCountdown}s'
                                          : 'Resend Link',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w700,
                                        color: _resendCountdown > 0
                                            ? textSecondary
                                            : textPrimary,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Center(
                            child: TextButton(
                              onPressed: _useDifferentEmail,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48.0, 48.0),
                              ),
                              child: Text(
                                'Use a different email',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16.0),

                        // Back to sign in footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'Remember your password? ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Back to sign in',
                              child: InkWell(
                                onTap: _goBackToSignIn,
                                borderRadius: BorderRadius.circular(6.0),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 48.0,
                                    minWidth: 48.0,
                                  ),
                                  child: Center(
                                    widthFactor: 1.0,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      child: Text(
                                        'Sign In',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
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

              // Back navigation (nested route)
              Positioned(
                top: 4.0,
                left: 8.0,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20.0,
                    color: textPrimary,
                  ),
                  tooltip: 'Back',
                  constraints: const BoxConstraints(
                    minWidth: 48.0,
                    minHeight: 48.0,
                  ),
                  onPressed: _goBackToSignIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
