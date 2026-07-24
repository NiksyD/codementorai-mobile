import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../common_widgets/animated_blob_background.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/password_reset_storage.dart';
import '../data/supabase_auth_repository.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final String email;
  final AuthRepository authRepository;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  static const int _pinLength = 6;
  final List<TextEditingController> _controllers =
      List<TextEditingController>.generate(
        _pinLength,
        (_) => TextEditingController(),
      );
  final List<FocusNode> _focusNodes = List<FocusNode>.generate(
    _pinLength,
    (_) => FocusNode(),
  );

  bool _isLoading = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    for (final FocusNode node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCode =>
      _controllers.map((TextEditingController c) => c.text).join();

  Future<void> _handleVerifyOtp() async {
    final String otp = _otpCode.trim();
    if (otp.length < _pinLength) {
      AppToast.showError(context, 'Please enter the complete 6-digit OTP code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user is already authenticated from a prior OTP verification
      final currentUser = await widget.authRepository.getCurrentUser();
      if (currentUser != null) {
        if (!mounted) return;
        context.pushReplacement('/reset-password');
        return;
      }

      await widget.authRepository.verifyPasswordResetOtp(
        email: widget.email,
        token: otp,
      );

      await PasswordResetStorage.setResetPending(true);

      if (!mounted) return;

      AppToast.showSuccess(context, 'OTP Code Verified!');
      context.pushReplacement('/reset-password');
    } catch (error) {
      if (!mounted) return;

      AppToast.showError(context, 'Verification Error: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0) return;

    try {
      await widget.authRepository.sendPasswordResetOtp(email: widget.email);
      if (!mounted) return;

      AppToast.showSuccess(context, 'A new 6-digit OTP code has been sent!');
      _startResendTimer();
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, 'Resend Error: ${error.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBlobBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Enter Code')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 12.0),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pin_outlined,
                      size: 48.0,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  'Verification Code',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Enter the 6-digit OTP code sent to\n${widget.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36.0),

                // 6-Box PIN Input Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List<Widget>.generate(
                    _pinLength,
                    (int index) => SizedBox(
                      width: 48,
                      height: 56,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.darkBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (String value) {
                          if (value.isNotEmpty && index < _pinLength - 1) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          if (_otpCode.length == _pinLength) {
                            _handleVerifyOtp();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32.0),

                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16.0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18.0),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Resend Code Countdown
                Center(
                  child: TextButton(
                    onPressed: _resendCountdown == 0 ? _handleResendOtp : null,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend code in ${_resendCountdown}s'
                          : 'Resend OTP Code',
                      style: TextStyle(
                        color: _resendCountdown == 0
                            ? AppColors.primary
                            : AppColors.darkTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
