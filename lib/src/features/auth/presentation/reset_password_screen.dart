import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/auth_error_banner.dart';
import '../../../common_widgets/password_strength_meter.dart';
import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/password_reset_storage.dart';
import '../data/supabase_auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (_password != _passwordController.text) {
        setState(() {
          _password = _passwordController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    // Dismiss keyboard on submit
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.vibrate();
      return;
    }

    if (!PasswordStrengthMeter.meetsRequirements(_passwordController.text)) {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = 'Please meet all password security requirements.';
      });
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.authRepository.updatePassword(
        newPassword: _passwordController.text,
      );

      // Clear password reset pending state & sign out temporary recovery session
      await PasswordResetStorage.clearResetPending();
      await widget.authRepository.signOut();

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      AppToast.showSuccess(
        context,
        'Password updated. Please sign in with your new password.',
      );

      context.go('/login');
    } catch (error) {
      if (!mounted) return;

      HapticFeedback.heavyImpact();
      final String message = error
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('AuthException: ', '');
      setState(() {
        _errorMessage = message;
      });
      AppToast.showError(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelAndReturnToLogin() async {
    HapticFeedback.lightImpact();
    await PasswordResetStorage.clearResetPending();
    await widget.authRepository.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  InputDecoration _passwordDecoration({
    required IconData prefixIcon,
    required bool obscured,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: '••••••••',
      prefixIcon: Icon(prefixIcon, size: 20.0),
      suffixIcon: IconButton(
        icon: Icon(
          obscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20.0,
        ),
        tooltip: obscured ? 'Show password' : 'Hide password',
        constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
        onPressed: onToggle,
      ),
    );
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
    final Color onPrimary = isDark ? AppColors.onPrimaryDark : Colors.white;

    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        await PasswordResetStorage.clearResetPending();
        await widget.authRepository.signOut();
      },
      child: GestureDetector(
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
                            'Set a new password',
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
                            'Choose a strong password with at least 8 characters, then confirm it below.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28.0),

                          if (_errorMessage != null) ...<Widget>[
                            AuthErrorBanner(message: _errorMessage!),
                            const SizedBox(height: 20.0),
                          ],

                          // New Password
                          Text(
                            'New Password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              color: textPrimary,
                            ),
                            decoration: _passwordDecoration(
                              prefixIcon: Icons.lock_outline_rounded,
                              obscured: _obscurePassword,
                              onToggle: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (String? value) {
                              if (value == null || value.isEmpty) {
                                return 'New password is required';
                              }
                              if (value.length < PasswordStrengthMeter.minLength) {
                                return 'Password must be at least ${PasswordStrengthMeter.minLength} characters';
                              }
                              return null;
                            },
                          ),

                          // Real-Time Password Strength Meter (same as Register)
                          if (_password.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12.0),
                            PasswordStrengthMeter(password: _password),
                          ],
                          const SizedBox(height: 18.0),

                          // Confirm Password
                          Text(
                            'Confirm New Password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              color: textPrimary,
                            ),
                            onFieldSubmitted: (_) => _handleUpdatePassword(),
                            decoration: _passwordDecoration(
                              prefixIcon: Icons.lock_reset_rounded,
                              obscured: _obscureConfirmPassword,
                              onToggle: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (String? value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your new password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24.0),

                          // Primary Button (WCAG Min 48dp height, solid primary like Sign In)
                          SizedBox(
                            height: 48.0,
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _handleUpdatePassword,
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
                                      'Save New Password',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w700,
                                        color: onPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Back navigation: cancels the reset and returns to sign in
                Positioned(
                  top: 4.0,
                  left: 8.0,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20.0,
                      color: textPrimary,
                    ),
                    tooltip: 'Cancel and return to sign in',
                    constraints: const BoxConstraints(
                      minWidth: 48.0,
                      minHeight: 48.0,
                    ),
                    onPressed: _cancelAndReturnToLogin,
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
