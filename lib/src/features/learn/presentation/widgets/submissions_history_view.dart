import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../common_widgets/shimmer_skeleton.dart';
import '../../../../common_widgets/app_toast.dart';
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
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (widget.isLoading) {
      return ShimmerLoading(
        child: Column(
          children: <Widget>[
            // Header skeleton
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
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
                separatorBuilder: (BuildContext context, int index) => Divider(
                  height: 1.0,
                  color: borderColor.withValues(alpha: 0.4),
                ),
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 14.0,
                    ),
                    child: Row(
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            SkeletonBox(
                              width: 100.0,
                              height: 14.0,
                              borderRadius: 4.0,
                            ),
                            SizedBox(height: 6.0),
                            SkeletonBox(
                              width: 60.0,
                              height: 11.0,
                              borderRadius: 4.0,
                            ),
                          ],
                        ),
                        const Spacer(),
                        const SkeletonBox(
                          width: 34.0,
                          height: 14.0,
                          borderRadius: 4.0,
                        ),
                        const SizedBox(width: 10.0),
                        const SkeletonBox(
                          width: 14.0,
                          height: 14.0,
                          borderRadius: 4.0,
                        ),
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
                        Text(
                          'No attempts yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          'Submit your solution and each attempt will be listed here with its score and code.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: textSecondary,
                            height: 1.45,
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

    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0),
    );

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'Total attempts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.submissions.length}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: widget.submissions.length,
              separatorBuilder: (BuildContext context, int index) =>
                  Divider(height: 1.0, thickness: 1.0, color: borderColor),
              itemBuilder: (BuildContext context, int index) {
                final SubmissionHistoryModel sub = widget.submissions[index];
                final bool isExpanded = _expandedSubmissionId == sub.id;
                final int attemptNumber = widget.submissions.length - index;
                final bool showVerdict =
                    !sub.isAccepted &&
                    sub.verdict.isNotEmpty &&
                    !sub.verdict.toLowerCase().contains('optimal');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _expandedSubmissionId = isExpanded ? null : sub.id;
                        });
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text.rich(
                                          TextSpan(
                                            children: <InlineSpan>[
                                              TextSpan(
                                                text: 'Attempt ',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 14.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: textPrimary,
                                                    ),
                                              ),
                                              TextSpan(
                                                text: '$attemptNumber',
                                                style:
                                                    GoogleFonts.jetBrainsMono(
                                                      fontSize: 14.0,
                                                      color: textPrimary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10.0),
                                        Icon(
                                          sub.isAccepted
                                              ? Icons.check_rounded
                                              : Icons.close_rounded,
                                          size: 16.0,
                                          color: sub.isAccepted
                                              ? textSecondary
                                              : AppColors.error,
                                        ),
                                        const SizedBox(width: 2.0),
                                        Text(
                                          sub.isAccepted ? 'Passed' : 'Failed',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w600,
                                            color: sub.isAccepted
                                                ? textSecondary
                                                : AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      showVerdict
                                          ? '${sub.timeAgoFormatted}  ·  ${sub.verdict}'
                                          : sub.timeAgoFormatted,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.0,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                sub.score != null ? '${sub.score}%' : '—',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  color: sub.score != null
                                      ? textPrimary
                                      : textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 22.0,
                                color: textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20.0,
                          0.0,
                          20.0,
                          14.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  _languageName(sub.language),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: sub.code),
                                    );
                                    HapticFeedback.lightImpact();
                                    AppToast.showSuccess(
                                      context,
                                      'Code copied to clipboard',
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16.0,
                                  ),
                                  label: const Text('Copy'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textPrimary,
                                    minimumSize: const Size(48.0, 44.0),
                                    side: BorderSide(color: borderColor),
                                    shape: buttonShape,
                                    textStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    widget.onRestoreCode(
                                      sub.code,
                                      sub.language,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.settings_backup_restore_rounded,
                                    size: 16.0,
                                  ),
                                  label: const Text('Restore'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textPrimary,
                                    minimumSize: const Size(48.0, 44.0),
                                    side: BorderSide(color: borderColor),
                                    shape: buttonShape,
                                    textStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceLowest
                                    : AppColors.lightSurfaceCard,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: borderColor),
                              ),
                              child: SelectableText(
                                sub.code.trim().isNotEmpty
                                    ? sub.code
                                    : '// No code recorded for this attempt.',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
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

  String _languageName(String lang) {
    const Map<String, String> names = <String, String>{
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'php': 'PHP',
      'cpp': 'C++',
      'csharp': 'C#',
      'sql': 'SQL',
    };
    final String l = lang.toLowerCase();
    return names[l] ??
        (l.length <= 2
            ? l.toUpperCase()
            : (l.isEmpty ? l : l[0].toUpperCase() + l.substring(1)));
  }
}
