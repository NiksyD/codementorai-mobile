import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../common_widgets/shimmer_skeleton.dart';
import '../../../../constants/app_colors.dart';
import '../../domain/submission_history_model.dart';

class SubmissionsHistoryView extends StatefulWidget {
  const SubmissionsHistoryView({
    super.key,
    required this.submissions,
    required this.isLoading,
    required this.onRefresh,
    required this.onRestoreCode,
  });

  final List<SubmissionHistoryModel> submissions;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final void Function(String code, String language) onRestoreCode;

  @override
  State<SubmissionsHistoryView> createState() => _SubmissionsHistoryViewState();
}

class _SubmissionsHistoryViewState extends State<SubmissionsHistoryView> {
  String? _expandedSubmissionId;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (widget.isLoading) {
      return ShimmerLoading(
        child: Column(
          children: <Widget>[
            // Header skeleton
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor.withValues(alpha: 0.4)),
                ),
              ),
              child: const Row(
                children: <Widget>[
                  SkeletonBox(width: 90.0, height: 13.0, borderRadius: 4.0),
                  Spacer(),
                  SkeletonBox(width: 24.0, height: 16.0, borderRadius: 8.0),
                ],
              ),
            ),
            // Divided rows skeleton
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (BuildContext context, int index) =>
                    Divider(height: 1.0, color: borderColor.withValues(alpha: 0.4)),
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                    child: Row(
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            SkeletonBox(width: 100.0, height: 14.0, borderRadius: 4.0),
                            SizedBox(height: 6.0),
                            SkeletonBox(width: 60.0, height: 11.0, borderRadius: 4.0),
                          ],
                        ),
                        const Spacer(),
                        const SkeletonBox(width: 34.0, height: 14.0, borderRadius: 4.0),
                        const SizedBox(width: 10.0),
                        const SkeletonBox(width: 14.0, height: 14.0, borderRadius: 4.0),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (widget.submissions.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 52.0,
                          height: 52.0,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161618) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            size: 26.0,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'No Attempts Yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          'Submit your code solution to track your version history and performance benchmarks.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: <Widget>[
          // Full-width header row with bottom border separator (1:1 Web parity)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: borderColor.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'TOTAL ATTEMPTS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF26262B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Text(
                    '${widget.submissions.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Full-width divided rows accordion
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: widget.submissions.length,
              separatorBuilder: (BuildContext context, int index) => Divider(
                height: 1.0,
                thickness: 1.0,
                color: borderColor.withValues(alpha: 0.4),
              ),
              itemBuilder: (BuildContext context, int index) {
                final SubmissionHistoryModel sub = widget.submissions[index];
                final bool isExpanded = _expandedSubmissionId == sub.id;
                final int attemptNumber = widget.submissions.length - index;
                final int? scoreVal = sub.score;

                final Color scoreColor = (scoreVal ?? 0) >= 80
                    ? const Color(0xFF10B981)
                    : ((scoreVal ?? 0) >= 60 ? const Color(0xFFF59E0B) : AppColors.error);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Accordion Row Trigger
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _expandedSubmissionId = isExpanded ? null : sub.id;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                        child: Row(
                          children: <Widget>[
                            // Left: Attempt # & Status Badge & Metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        'Attempt #$attemptNumber',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      // Status badge: Passed / Failed (1:1 Web parity)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: (sub.isAccepted ? const Color(0xFF10B981) : AppColors.error)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6.0),
                                          border: Border.all(
                                            color: (sub.isAccepted ? const Color(0xFF10B981) : AppColors.error)
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              sub.isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                              size: 11.0,
                                              color: sub.isAccepted ? const Color(0xFF10B981) : AppColors.error,
                                            ),
                                            const SizedBox(width: 3.5),
                                            Text(
                                              sub.isAccepted ? 'Passed' : 'Failed',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: sub.isAccepted ? const Color(0xFF10B981) : AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4.0),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        sub.timeAgoFormatted,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                      if (!sub.isAccepted &&
                                          sub.verdict.isNotEmpty &&
                                          !sub.verdict.toLowerCase().contains('optimal')) ...<Widget>[
                                        Text(
                                          '  ·  ',
                                          style: TextStyle(fontSize: 11.0, color: textSecondary),
                                        ),
                                        Flexible(
                                          child: Text(
                                            sub.verdict,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              color: AppColors.error.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Right: Pure Numeric Score Percentage & Accordion Chevron
                            if (sub.score != null) ...<Widget>[
                              Text(
                                '${sub.score}%',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: scoreColor,
                                ),
                              ),
                            ] else ...<Widget>[
                              Text(
                                '—',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8.0),
                            Icon(
                              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 18.0,
                              color: textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expanded Code View & Actions (Accordion Content)
                    if (isExpanded)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 14.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161618) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: isDark ? const Color(0xFF26262B) : borderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Integrated Header with Language & Actions
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F5F9),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(9.0)),
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? const Color(0xFF26262B) : borderColor,
                                    width: 0.8,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.code_rounded, size: 14.0, color: textSecondary),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    sub.language.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: sub.code));
                                      HapticFeedback.lightImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Code copied to clipboard',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                                          ),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 13.0),
                                    label: const Text('Copy'),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                      foregroundColor: textPrimary,
                                      textStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      widget.onRestoreCode(sub.code, sub.language);
                                    },
                                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 14.0),
                                    label: const Text('Restore'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6.0),
                                      ),
                                      textStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Monospace code display
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SelectableText(
                                sub.code.trim().isNotEmpty
                                    ? sub.code
                                    : '// No code recorded for this attempt.',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.0,
                                  height: 1.45,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
