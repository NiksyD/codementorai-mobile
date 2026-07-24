import 'package:flutter/material.dart';
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
      iconColor: AppColors.success,
      borderColor: AppColors.success.withValues(alpha: 0.4),
    );
  }

  static void showError(BuildContext context, dynamic message) {
    final String formattedMessage = cleanErrorMessage(message);
    _showToast(
      context,
      message: formattedMessage,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.error,
      borderColor: AppColors.error.withValues(alpha: 0.4),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.primary,
      borderColor: AppColors.primary.withValues(alpha: 0.4),
    );
  }

  static void _showToast(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceCard,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
