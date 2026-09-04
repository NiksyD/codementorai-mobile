import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';
import '../../domain/assessment_model.dart';

class AssessmentResultModal extends StatelessWidget {
  const AssessmentResultModal({
    super.key,
    required this.assessment,
    required this.score,
    required this.timeSpentSecs,
    required this.challengeResults,
    required this.onDone,
  });

  final AssessmentModel assessment;
  final int score;
  final int timeSpentSecs;
  final List<Map<String, dynamic>> challengeResults;
  final VoidCallback onDone;

  static Future<void> show(
    BuildContext context, {
    required AssessmentModel assessment,
    required int score,
    required int timeSpentSecs,
    required List<Map<String, dynamic>> challengeResults,
    required VoidCallback onDone,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AssessmentResultModal(
        assessment: assessment,
        score: score,
        timeSpentSecs: timeSpentSecs,
        challengeResults: challengeResults,
        onDone: onDone,
      ),
    );
  }

  String _formatDuration(int totalSecs) {
    final int m = totalSecs ~/ 60;
    final int s = totalSecs % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final bool isPassed = score >= assessment.passingScore;
    final Color statusColor =
        isPassed ? const Color(0xFF3ECF8E) : const Color(0xFFF59E0B);
    final String verdict =
        isPassed ? 'Benchmark Reached' : 'Needs Review';

    final int passedCount =
        challengeResults.where((r) => r['passed'] == true).length;
    final int totalChallenges =
        assessment.challenges.isNotEmpty ? assessment.challenges.length : 1;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 36.0,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Grab handle
              Center(
                child: Container(
                  width: 38.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),

              // Body content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 16.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: <Widget>[
                      // Certificate Icon Badge
                      Container(
                        width: 64.0,
                        height: 64.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isPassed
                              ? Icons.emoji_events_rounded
                              : Icons.insights_rounded,
                          size: 32.0,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 14.0),

                      // Score Display
                      Text(
                        '$score%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 38.0,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 6.0),

                      // Verdict Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          verdict.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.0),

                      // Title & Subtitle
                      Text(
                        assessment.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        isPassed
                            ? 'Excellent work! You have verified your readiness for competitive programming.'
                            : 'Good effort! Review the challenge test cases and prepare for your next attempt.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          color: textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18.0),

                      // Metrics Grid Card
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Cutoff',
                                value: '${assessment.passingScore}%',
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                            Container(width: 1.0, height: 32.0, color: borderColor),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Time Spent',
                                value: _formatDuration(timeSpentSecs),
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                            Container(width: 1.0, height: 32.0, color: borderColor),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Tasks',
                                value: '$passedCount / $totalChallenges',
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18.0),

                      // Challenge Breakdown Section
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PROBLEM BREAKDOWN',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      ...assessment.challenges.asMap().entries.map((entry) {
                        final int idx = entry.key;
                        final AssessmentChallengeModel ch = entry.value;

                        final Map<String, dynamic> res =
                            challengeResults.firstWhere(
                          (r) => r['challenge_id'] == ch.id,
                          orElse: () => <String, dynamic>{
                            'passed': false,
                            'score': 0,
                          },
                        );
                        final bool passed = res['passed'] == true;
                        final Color itemColor = passed
                            ? const Color(0xFF3ECF8E)
                            : const Color(0xFFEF4444);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 22.0,
                                height: 22.0,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: itemColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  'P${idx + 1}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    color: itemColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      ch.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      '${ch.testCases.length} Test Assertions',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.0,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color: itemColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Text(
                                  passed ? 'PASSED' : 'UNRESOLVED',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    color: itemColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Bottom Action
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      onDone();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: isDark
                          ? AppColors.onPrimaryDark
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}
