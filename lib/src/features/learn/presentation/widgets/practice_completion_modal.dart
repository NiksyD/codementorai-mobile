import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

class PracticeCompletionModal extends StatelessWidget {
  const PracticeCompletionModal({
    super.key,
    required this.exerciseTitle,
    required this.onBackToModule,
    this.onViewAiReview,
    this.solved = true,
    this.testSummary,
  });

  final String exerciseTitle;
  final VoidCallback onBackToModule;
  final VoidCallback? onViewAiReview;

  /// False when the attempt was submitted but some tests failed.
  final bool solved;

  /// For example "2 of 4 test cases passed", shown when not solved.
  final String? testSummary;

  static Future<void> show(
    BuildContext context, {
    required String exerciseTitle,
    required VoidCallback onBackToModule,
    VoidCallback? onViewAiReview,
    bool solved = true,
    String? testSummary,
  }) {
    HapticFeedback.heavyImpact();
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => PracticeCompletionModal(
        exerciseTitle: exerciseTitle,
        onBackToModule: onBackToModule,
        onViewAiReview: onViewAiReview,
        solved: solved,
        testSummary: testSummary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBg = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Icon(
                    solved ? Icons.check_rounded : Icons.edit_note_rounded,
                    size: 24.0,
                    color: textPrimary,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    solved ? 'Exercise solved' : 'Attempt submitted',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                exerciseTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8.0),
              Text(
                solved
                    ? 'All test cases passed and your progress has been updated.'
                    : '${testSummary ?? 'Some test cases did not pass.'}. This attempt is saved in History. Keep working on it and submit again whenever you are ready.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  height: 1.45,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 20.0),
              if (!solved) ...<Widget>[
                SizedBox(
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: isDark
                          ? AppColors.onPrimaryDark
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text(
                      'Keep editing',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (onViewAiReview != null)
                  TextButton(
                    onPressed: onViewAiReview,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48.0, 48.0),
                    ),
                    child: Text(
                      'View code review',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: onBackToModule,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48.0, 48.0),
                  ),
                  child: Text(
                    'Back to module',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ),
              ] else if (onViewAiReview != null) ...<Widget>[
                SizedBox(
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: onViewAiReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: isDark
                          ? AppColors.onPrimaryDark
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text(
                      'View code review',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
                TextButton(
                  onPressed: onBackToModule,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48.0, 48.0),
                  ),
                  child: Text(
                    'Back to module',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: onBackToModule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: isDark
                          ? AppColors.onPrimaryDark
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text(
                      'Back to module',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                      ),
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
