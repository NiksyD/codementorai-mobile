import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

abstract class AppToast {
  static String cleanErrorMessage(dynamic error) {
    final String str = error.toString();
    if (str.contains('over_email_send_rate_limit') ||
        str.contains('statusCode: 429')) {
      final RegExp regExp = RegExp(r'after (\d+) seconds');
      final Match? match = regExp.firstMatch(str);
      if (match != null) {
        return 'Please wait ${match.group(1)} seconds before requesting another code.';
      }
      return 'Too many requests. Please wait a few seconds before trying again.';
    }
    if (str.contains('otp_expired') || str.contains('Token has expired')) {
      return 'The verification code is invalid or has expired. Please request a new code.';
    }
    if (str.contains('different from the old password') ||
        str.contains('should be different')) {
      return 'Your new password must be different from your old password.';
    }
    // Clean raw AuthApiException strings
    return str
        .replaceAll(RegExp(r'^Update Error:\s*'), '')
        .replaceAll(RegExp(r'^Verification Error:\s*'), '')
        .replaceAll(RegExp(r'^Reset Error:\s*'), '')
        .replaceAll(RegExp(r'^Exception:\s*'), '')
        .replaceAll(RegExp(r'^AuthApiException\(message:\s*'), '')
        .replaceAll(RegExp(r',?\s*statusCode:.*'), '')
        .replaceAll(RegExp(r'\)$'), '')
        .trim();
  }

  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      accentColor: AppColors.primary,
    );
  }

  static void showError(BuildContext context, dynamic message) {
    final String formattedMessage = cleanErrorMessage(message);
    _showToast(
      context,
      message: formattedMessage,
      icon: Icons.error_rounded,
      accentColor: AppColors.error,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.info_rounded,
      accentColor: const Color(0xFF38BDF8), // Clean Sky Blue
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.warning_rounded,
      accentColor: AppColors.warning,
    );
  }

  static void _showToast(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    HapticFeedback.lightImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 84.0),
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                blurRadius: 20.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14.0, 12.0, 12.0, 12.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceCard.withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    // Accent icon squircle
                    Container(
                      width: 32.0,
                      height: 32.0,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          color: accentColor,
                          size: 17.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),

                    // Toast message
                    Expanded(
                      child: Text(
                        message,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          letterSpacing: -0.2,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Close micro-button
                    InkWell(
                      onTap: () {
                        messenger.hideCurrentSnackBar();
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16.0,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
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
