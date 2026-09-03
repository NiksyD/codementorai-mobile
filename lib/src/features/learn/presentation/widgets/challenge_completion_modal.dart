import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

class ChallengeCompletionModal extends StatelessWidget {
  const ChallengeCompletionModal({
    super.key,
    required this.challengeTitle,
    required this.targetTime,
    required this.targetSpace,
    required this.onBackToModule,
    this.onRateModule,
  });

  final String challengeTitle;
  final String targetTime;
  final String targetSpace;
  final VoidCallback onBackToModule;
  final VoidCallback? onRateModule;

  static Future<void> show(
    BuildContext context, {
    required String challengeTitle,
    required String targetTime,
    required String targetSpace,
    required VoidCallback onBackToModule,
    VoidCallback? onRateModule,
  }) {
    HapticFeedback.heavyImpact();
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ChallengeCompletionModal(
        challengeTitle: challengeTitle,
        targetTime: targetTime,
        targetSpace: targetSpace,
        onBackToModule: onBackToModule,
        onRateModule: onRateModule,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
            // Trophy Badge
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
                Icons.emoji_events_rounded,
                color: Color(0xFF3ECF8E),
                size: 36.0,
              ),
            ),
            const SizedBox(height: 18.0),

            Text(
              'Challenge Solved!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20.0,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6.0),

            Text(
              challengeTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3ECF8E),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8.0),

            Text(
              'Your algorithmic solution passed all test assertions and met the target Time & Space complexity SLA bounds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                height: 1.45,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20.0),

            // SLA Performance Bounds (Preserved for Challenges!)
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
                        'Time SLA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        targetTime,
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
                        'Space SLA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        targetSpace,
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
                        'Verdict',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        'Optimal',
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

            if (onRateModule != null) ...<Widget>[
              const SizedBox(height: 10.0),
              TextButton.icon(
                onPressed: onRateModule,
                icon: const Icon(
                  Icons.star_outline_rounded,
                  size: 16.0,
                  color: Color(0xFFFBBF24),
                ),
                label: Text(
                  'Rate & Review this Module',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
