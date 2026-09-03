import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final Color cardBg = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: 24.0,
              height: 24.0,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12.0),
            Text(
              'Loading submission history...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textSecondary,
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
                          width: 56.0,
                          height: 56.0,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            size: 28.0,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'No Attempts Yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          'Submit a solution to start tracking your version history and performance benchmarks.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        itemCount: widget.submissions.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12.0),
        itemBuilder: (BuildContext context, int index) {
          final SubmissionHistoryModel sub = widget.submissions[index];
          final bool isExpanded = _expandedSubmissionId == sub.id;
          final int attemptNumber = widget.submissions.length - index;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isExpanded ? AppColors.primary.withValues(alpha: 0.5) : borderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _expandedSubmissionId = isExpanded ? null : sub.id;
                    });
                  },
                  borderRadius: BorderRadius.circular(14.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Row(
                      children: <Widget>[
                        // Status indicator icon
                        Container(
                          width: 28.0,
                          height: 28.0,
                          decoration: BoxDecoration(
                            color: sub.isAccepted
                                ? const Color(0xFF3ECF8E).withValues(alpha: 0.15)
                                : AppColors.error.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            sub.isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 16.0,
                            color: sub.isAccepted ? const Color(0xFF3ECF8E) : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 12.0),

                        // Title & relative time
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4.0),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Text(
                                      sub.language.toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                '${sub.status} · ${sub.verdict} · ${sub.timeAgoFormatted}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Expand chevron
                        Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 20.0,
                          color: textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded code preview & Restore action
                if (isExpanded) ...<Widget>[
                  Divider(color: borderColor, height: 1.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14.0),
                    color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Monospace code display
                        SelectableText(
                          sub.code.trim().isNotEmpty
                              ? sub.code
                              : '// No code recorded for this attempt.',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            height: 1.45,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14.0),

                        // Actions row: Copy + Restore
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            OutlinedButton.icon(
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
                              icon: const Icon(Icons.copy_rounded, size: 14.0),
                              label: Text(
                                'Copy Code',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(color: borderColor),
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                widget.onRestoreCode(sub.code, sub.language);
                              },
                              icon: const Icon(Icons.settings_backup_restore_rounded, size: 15.0),
                              label: Text(
                                'Restore This Code',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
