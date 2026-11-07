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
      icon: Icons.check_rounded,
      isError: false,
    );
  }

  static void showError(BuildContext context, dynamic message) {
    _showToast(
      context,
      message: cleanErrorMessage(message),
      icon: Icons.error_outline_rounded,
      isError: true,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      isError: false,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showToast(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      isError: false,
    );
  }

  /// A solid bar with a hairline border: an icon, one message, and a close button.
  /// Only an error uses colour (its icon); the icon shape says what kind of message it is.
  static void _showToast(
    BuildContext context, {
    required String message,
    required IconData icon,
    required bool isError,
  }) {
    HapticFeedback.lightImpact();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark
        ? AppColors.darkSurfaceCard
        : AppColors.lightSurface;
    final Color border = isDark
        ? AppColors.darkBorderVariant
        : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 84.0),
        duration: Duration(seconds: isError ? 5 : 3),
        dismissDirection: DismissDirection.horizontal,
        padding: EdgeInsets.zero,
        content: Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.only(left: 14.0),
            constraints: const BoxConstraints(minHeight: 48.0),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: border),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 20.0,
                  color: isError ? AppColors.error : textPrimary,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      message,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  constraints: const BoxConstraints(
                    minWidth: 48.0,
                    minHeight: 48.0,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18.0,
                    color: textSecondary,
                  ),
                  onPressed: messenger.hideCurrentSnackBar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
