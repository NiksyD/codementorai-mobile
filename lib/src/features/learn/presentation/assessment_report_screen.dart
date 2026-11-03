import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../domain/assessment_report_args.dart';
import '../domain/dashboard_submission.dart';

/// Post-submission report (mobile counterpart of web's /learn/assessment/[id]/report):
/// overall result, then one review card per challenge that opens its AI code review.
class AssessmentReportScreen extends StatelessWidget {
  const AssessmentReportScreen({super.key, required this.args});

  final AssessmentReportArgs args;

  String _formatDuration(int totalSecs) {
    final int m = totalSecs ~/ 60;
    final int s = totalSecs % 60;
    return m == 0 ? '${s}s' : '${m}m ${s}s';
  }

  void _openReview(BuildContext context, AssessmentChallengeResult r) {
    final String? subId = r.submissionId;
    if (subId == null || subId.isEmpty) return;
    HapticFeedback.selectionClick();

    final DateTime now = DateTime.now();
    final DashboardSubmission sub = DashboardSubmission(
      id: subId,
      itemId: r.challenge.id,
      moduleId: args.assessment.id,
      title: r.challenge.title,
      module: args.assessment.title,
      type: 'assessment',
      difficulty: '',
      language: r.language,
      status: r.passed ? 'Passed' : 'Needs Review',
      score: null,
      submittedAt: now,
      rawDate:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      code: r.code,
      verdict: r.verdict,
    );
    context.push('/learn/activity/$subId', extra: sub);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color cardColor =
        isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final bool isPassed = args.isPassed;
    final Color accent =
        isPassed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) context.go('/assessments');
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 16.0),
                  physics: const BouncingScrollPhysics(),
                  children: <Widget>[
                    // ── Summary ──
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            '${args.score}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 44.0,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              isPassed ? 'PASSED' : 'NEEDS REVIEW',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14.0),
                          Text(
                            args.assessment.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17.0,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _stat('Time Spent',
                                    _formatDuration(args.timeSpentSecs),
                                    textPrimary, textSecondary),
                              ),
                              Container(
                                  width: 1.0, height: 30.0, color: borderColor),
                              Expanded(
                                child: _stat(
                                    'Tasks Passed',
                                    '${args.passedCount} / ${args.results.length}',
                                    textPrimary,
                                    textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22.0),

                    // ── Challenge reviews ──
                    Text(
                      'CHALLENGE REVIEWS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Open a challenge to read its AI code review. Reviews can take a moment to generate after you submit.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    ...args.results.asMap().entries.map(
                      (MapEntry<int, AssessmentChallengeResult> e) {
                        final AssessmentChallengeResult r = e.value;
                        final Color c = r.passed
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444);
                        final bool canOpen = (r.submissionId ?? '').isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Material(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16.0),
                              onTap: canOpen ? () => _openReview(context, r) : null,
                              child: Container(
                                padding: const EdgeInsets.all(14.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 34.0,
                                      height: 34.0,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: c.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        'P${e.key + 1}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.w800,
                                          color: c,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            r.challenge.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3.0),
                                          Text(
                                            r.totalCases > 0
                                                ? '${r.verdict} · ${r.passedCases}/${r.totalCases} tests'
                                                : r.verdict,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (canOpen)
                                      Icon(Icons.chevron_right_rounded,
                                          color: textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.go('/assessments');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor:
                          isDark ? AppColors.onPrimaryDark : Colors.white,
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

  Widget _stat(
      String label, String value, Color textPrimary, Color textSecondary) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 15.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}
