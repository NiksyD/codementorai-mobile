import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/social_auth_buttons.dart';
import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _password = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() {
        _password = _passwordController.text;
      });
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Password Criteria (100% Web Parity)
  bool get _hasMinLength => _password.length >= 8;
  bool get _hasUpperAndLower =>
      RegExp(r'[A-Z]').hasMatch(_password) && RegExp(r'[a-z]').hasMatch(_password);
  bool get _hasNumberOrSymbol =>
      RegExp(r'[0-9]|[^A-Za-z0-9]').hasMatch(_password);

  // Password Strength Score (0 to 4)
  int get _strengthScore {
    if (_password.isEmpty) return 0;
    int score = 0;
    if (_password.length >= 8) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(_password) && RegExp(r'[a-z]').hasMatch(_password)) {
      score += 1;
    }
    if (RegExp(r'[0-9]').hasMatch(_password)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(_password) || _password.length >= 12) {
      score += 1;
    }
    return score;
  }

  static const List<Color> _strengthColors = <Color>[
    Color(0x332E333F),
    Color(0xFFEF4444), // Weak (Red)
    Color(0xFFF59E0B), // Fair (Amber)
    Color(0xFF38BDF8), // Good (Sky)
    Color(0xFF3ECF8E), // Strong (Mint / Emerald)
  ];

  static const List<String> _strengthLabels = <String>[
    'Empty',
    'Weak',
    'Fair',
    'Good',
    'Strong',
  ];

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.vibrate();
      return;
    }

    if (!_hasMinLength || !_hasUpperAndLower || !_hasNumberOrSymbol) {
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
      final String fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

      await widget.authRepository.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: fullName.isNotEmpty ? fullName : null,
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      AppToast.showSuccess(
        context,
        'Registration successful!',
      );

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        context.go('/onboarding');
      } else {
        context.pop();
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
                vertical: 20.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 8.0),

                    // Brand Logo (Matching Web Parity)
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
                    const SizedBox(height: 24.0),

                    // Error Banner
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
                      const SizedBox(height: 18.0),
                    ],

                    // First Name & Last Name (2-Column Row matching Web)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'First Name',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              TextFormField(
                                controller: _firstNameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  color: textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Jane',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20.0),
                                ),
                                validator: (String? value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'First name is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Last Name',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              TextFormField(
                                controller: _lastNameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  color: textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Doe',
                                ),
                                validator: (String? value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Last name is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // Email Address Field
                    Text(
                      'Email Address',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6.0),
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
                    const SizedBox(height: 16.0),

                    // Password Field
                    Text(
                      'Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        color: textPrimary,
                      ),
                      onFieldSubmitted: (_) => _handleRegister(),
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
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),

                    // Real-Time Password Strength Meter (100% Web Parity)
                    if (_password.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10.0),
                      // 4-Bar Strength Progress Indicator
                      Row(
                        children: List<Widget>.generate(4, (int index) {
                          final bool isFilled = index < _strengthScore;
                          final Color barColor = isFilled
                              ? _strengthColors[_strengthScore]
                              : (isDark
                                  ? const Color(0x332E333F)
                                  : const Color(0x33C4C6CF));

                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 5.0,
                              margin: EdgeInsets.only(
                                right: index < 3 ? 5.0 : 0.0,
                              ),
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6.0),

                      // Strength Text Label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'PASSWORD STRENGTH',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            _strengthLabels[_strengthScore],
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _strengthColors[_strengthScore],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),

                      // Real-Time Validation Checklist
                      _buildCriteriaItem(
                        isValid: _hasMinLength,
                        label: 'At least 8 characters',
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 4.0),
                      _buildCriteriaItem(
                        isValid: _hasUpperAndLower,
                        label: 'Uppercase and lowercase letters',
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 4.0),
                      _buildCriteriaItem(
                        isValid: _hasNumberOrSymbol,
                        label: 'At least one number or symbol',
                        textSecondary: textSecondary,
                      ),
                    ],
                    const SizedBox(height: 24.0),

                    // Primary Create Account Button (Matching Web Solid bg-primary with on-primary text)
                    SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
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
                                'Create Account',
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
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Go back to sign in screen',
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.pop();
                              },
                              borderRadius: BorderRadius.circular(6.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                  vertical: 6.0,
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

  Widget _buildCriteriaItem({
    required bool isValid,
    required String label,
    required Color textSecondary,
  }) {
    final Color activeColor = AppColors.primary;
    final Color inactiveColor = textSecondary.withValues(alpha: 0.5);

    return Row(
      children: <Widget>[
        Container(
          width: 14.0,
          height: 14.0,
          decoration: BoxDecoration(
            color: isValid
                ? activeColor.withValues(alpha: 0.2)
                : inactiveColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '✓',
              style: TextStyle(
                fontSize: 9.0,
                fontWeight: FontWeight.bold,
                color: isValid ? activeColor : inactiveColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: isValid ? FontWeight.w600 : FontWeight.w400,
            color: isValid ? activeColor : inactiveColor,
          ),
        ),
      ],
    );
  }
}
