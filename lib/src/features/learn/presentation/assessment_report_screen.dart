import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/assessment_report_args.dart';
import '../domain/dashboard_submission.dart';

/// Post-submission report (mobile counterpart of web's /learn/assessment/[id]/report):
/// the result, an AI code quality figure that shows "Evaluating" until the AI
/// reviews exist, and one review card per challenge.
///
/// The headline score is final: it is tasks passed / total, computed from the
/// test runs that finished before this screen opened. Only the AI review is
/// asynchronous.
class AssessmentReportScreen extends StatefulWidget {
  const AssessmentReportScreen({
    super.key,
    required this.args,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final AssessmentReportArgs args;
  final SupabasePathwayRepository pathwayRepository;

  @override
  State<AssessmentReportScreen> createState() => _AssessmentReportScreenState();
}

class _AssessmentReportScreenState extends State<AssessmentReportScreen> {
  static const int _maxPolls = 10;
  static const Duration _pollInterval = Duration(seconds: 6);

  /// AI composite score (0-100) per submission id, once its review is saved.
  final Map<String, double> _aiScores = <String, double>{};
  Timer? _timer;
  int _polls = 0;
  bool _gaveUp = false;

  List<String> get _submissionIds => widget.args.results
      .map((AssessmentChallengeResult r) => r.submissionId ?? '')
      .where((String id) => id.isNotEmpty)
      .toList();

  bool get _allReady =>
      _submissionIds.isNotEmpty &&
      _submissionIds.every(_aiScores.containsKey);

  @override
  void initState() {
    super.initState();
    // Nothing was judged, so there is no AI review worth waiting for.
    if (widget.args.hasEvaluation) _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    for (final String id in _submissionIds) {
      if (_aiScores.containsKey(id)) continue;
      final double? score = await widget.pathwayRepository.getAiCompositeScore(id);
      if (!mounted) return;
      if (score != null) _aiScores[id] = score;
    }
    if (!mounted) return;
    setState(() {});

    if (_submissionIds.isEmpty || _allReady) return;
    if (_polls >= _maxPolls) {
      setState(() => _gaveUp = true);
      return;
    }
    _timer?.cancel();
    _timer = Timer(_pollInterval, () {
      _polls++;
      _check();
    });
  }

  void _retry() {
    HapticFeedback.lightImpact();
    for (final String id in _submissionIds) {
      if (_aiScores.containsKey(id)) continue;
      SupabasePathwayRepository.resetGenerationCooldown(id);
      // Ask for generation once more; the polling below picks up the result.
      unawaited(widget.pathwayRepository.getSubmissionReview(id));
    }
    setState(() {
      _polls = 0;
      _gaveUp = false;
    });
    _check();
  }

  String _formatDuration(int totalSecs) {
    final int m = totalSecs ~/ 60;
    final int s = totalSecs % 60;
    return m == 0 ? '${s}s' : '${m}m ${s}s';
  }

  /// The report replaced the attempt screen on the navigation stack, so popping
  /// returns to wherever the attempt was started. Fall back to the dashboard if
  /// it was deep-linked.
  void _leave() {
    HapticFeedback.selectionClick();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _openReview(AssessmentChallengeResult r) {
    final String? subId = r.submissionId;
    if (subId == null || subId.isEmpty) return;
    HapticFeedback.selectionClick();

    final DateTime now = DateTime.now();
    final DashboardSubmission sub = DashboardSubmission(
      id: subId,
      itemId: r.challenge.id,
      moduleId: widget.args.assessment.id,
      title: r.challenge.title,
      module: widget.args.assessment.title,
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
    final AssessmentReportArgs args = widget.args;
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

    final bool isPassed = args.hasEvaluation && args.isPassed;
    // Nothing was judged: show a neutral blank state instead of a 0% grade.
    final Color accent = !args.hasEvaluation
        ? textSecondary
        : (isPassed ? AppColors.success : AppColors.warning);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) _leave();
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
                    _SummaryCard(
                      args: args,
                      accent: accent,
                      isPassed: isPassed,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      timeSpent: _formatDuration(args.timeSpentSecs),
                      aiStat: _AiQualityStat(
                        hasSubmissions:
                            args.hasEvaluation && _submissionIds.isNotEmpty,
                        allReady: _allReady,
                        gaveUp: _gaveUp,
                        average: _aiScores.isEmpty
                            ? 0
                            : _aiScores.values.reduce((double a, double b) => a + b) /
                                _aiScores.length,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      onRetry: _gaveUp && !_allReady ? _retry : null,
                    ),
                    const SizedBox(height: 24.0),
                    Text(
                      'Challenge reviews',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Open a challenge to read its AI code review.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    ...args.results.asMap().entries.map(
                      (MapEntry<int, AssessmentChallengeResult> e) {
                        final AssessmentChallengeResult r = e.value;
                        final String subId = r.submissionId ?? '';
                        return Padding(
                          padding: EdgeInsets.zero,
                          child: _ChallengeCard(
                            index: e.key,
                            result: r,
                            reviewReady: subId.isNotEmpty && _aiScores.containsKey(subId),
                            gaveUp: _gaveUp,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: subId.isEmpty ? null : () => _openReview(r),
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
                    onPressed: _leave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor:
                          isDark ? AppColors.onPrimaryDark : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
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
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.args,
    required this.accent,
    required this.isPassed,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.timeSpent,
    required this.aiStat,
    required this.onRetry,
  });

  final AssessmentReportArgs args;
  final Color accent;
  final bool isPassed;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final String timeSpent;
  final Widget aiStat;
  final VoidCallback? onRetry;

  Widget _stat(String label, Widget value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6.0),
          value,
        ],
      ),
    );
  }

  Text _metric(String text) => Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 15.0,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final String status = !args.hasEvaluation
        ? 'Not evaluated'
        : (isPassed ? 'Passed' : 'Needs review');
    final IconData statusIcon = !args.hasEvaluation
        ? Icons.remove_rounded
        : (isPassed ? Icons.check_rounded : Icons.error_outline_rounded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          args.assessment.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.0,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          args.hasEvaluation ? '${args.score}%' : '—',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 44.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8.0),
        Row(
          children: <Widget>[
            Icon(statusIcon, size: 18.0, color: accent),
            const SizedBox(width: 6.0),
            Text(
              status,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          args.hasEvaluation
              ? 'Score = tasks passed ÷ total tasks'
              : 'No task was run, so there is no score yet.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 16.0),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: borderColor)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _stat('Time spent', _metric(timeSpent)),
              _stat(
                'Tasks passed',
                _metric('${args.passedCount} / ${args.results.length}'),
              ),
              _stat('AI code quality', aiStat),
            ],
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(48.0, 48.0)),
            child: Text(
              'Check AI reviews again',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _AiQualityStat extends StatelessWidget {
  const _AiQualityStat({
    required this.hasSubmissions,
    required this.allReady,
    required this.gaveUp,
    required this.average,
    required this.textPrimary,
    required this.textSecondary,
  });

  final bool hasSubmissions;
  final bool allReady;
  final bool gaveUp;
  final double average;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    if (allReady) {
      return Text(
        '${average.round()} / 100',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 15.0,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      );
    }
    if (!hasSubmissions || gaveUp) {
      return Text(
        'Unavailable',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.0,
          fontWeight: FontWeight.w700,
          color: textSecondary,
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      label: 'AI code quality is being evaluated',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 14.0,
            height: 14.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            'Evaluating',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.index,
    required this.result,
    required this.reviewReady,
    required this.gaveUp,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final int index;
  final AssessmentChallengeResult result;
  final bool reviewReady;
  final bool gaveUp;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback? onTap;

  Widget _reviewStatus() {
    if (onTap == null || !result.wasEvaluated) return const SizedBox.shrink();
    if (reviewReady) {
      return Icon(
        Icons.check_rounded,
        size: 18.0,
        color: textSecondary,
        semanticLabel: 'AI review ready',
      );
    }
    if (gaveUp) {
      return Icon(
        Icons.hourglass_empty_rounded,
        size: 20.0,
        color: textSecondary,
        semanticLabel: 'AI review not ready',
      );
    }
    return const SizedBox(
      width: 16.0,
      height: 16.0,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        color: AppColors.primary,
        semanticsLabel: 'AI review generating',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String tests = result.totalCases > 0
        ? '${result.verdict} · ${result.passedCases}/${result.totalCases} tests'
        : result.verdict;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64.0),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 36.0,
              child: Text(
                'P${index + 1}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13.0,
                  color: textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result.challenge.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: <Widget>[
                      Icon(
                        result.passed
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: 14.0,
                        color:
                            result.passed ? textSecondary : AppColors.error,
                      ),
                      const SizedBox(width: 4.0),
                      Expanded(
                        child: Text(
                          tests,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: result.passed
                                ? textSecondary
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((result.detail ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4.0),
                    Text(
                      result.detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        height: 1.4,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            _reviewStatus(),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 4.0),
              Icon(Icons.chevron_right_rounded, color: textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
