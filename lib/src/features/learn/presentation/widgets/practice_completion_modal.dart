import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

class PracticeCompletionModal extends StatelessWidget {
  const PracticeCompletionModal({
    super.key,
    required this.exerciseTitle,
    required this.onBackToModule,
  });

  final String exerciseTitle;
  final VoidCallback onBackToModule;

  static Future<void> show(
    BuildContext context, {
    required String exerciseTitle,
    required VoidCallback onBackToModule,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBg = isDark ? AppColors.darkBackground : Colors.white;
    final Color cardBg = isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC);
    final Color borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A);
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24.0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Celebration Icon
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3ECF8E).withValues(alpha: 0.4),
                  width: 2.0,
                ),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF3ECF8E),
                size: 36.0,
              ),
            ),
            const SizedBox(height: 18.0),

            Text(
              'Exercise Solved!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20.0,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6.0),

            Text(
              exerciseTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3ECF8E),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8.0),

            Text(
              'Your implementation compiled cleanly, passed all test assertions, and earned curriculum progress.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                height: 1.45,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20.0),

            // Practice Performance Metrics
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Text(
                        'Track',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        'Practice',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1.0,
                    height: 28.0,
                    color: borderColor,
                  ),
                  Column(
                    children: <Widget>[
                      Text(
                        'Build',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        'Clean ✓',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3ECF8E),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1.0,
                    height: 28.0,
                    color: borderColor,
                  ),
                  Column(
                    children: <Widget>[
                      Text(
                        'Status',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        'Completed',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3ECF8E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22.0),

            // Return button
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton(
                onPressed: onBackToModule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Back to Module',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
