import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../common_widgets/filter_tab_bar.dart';
import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/activity_submission_review_model.dart';
import '../domain/dashboard_submission.dart';
import 'widgets/code_highlighter.dart';
import 'widgets/practice_code_editor.dart' show highlightedSpans;

class ActivitySubmissionReviewScreen extends StatefulWidget {
  const ActivitySubmissionReviewScreen({
    super.key,
    required this.submissionId,
    this.initialSubmission,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final String submissionId;
  final DashboardSubmission? initialSubmission;
  final PathwayRepository pathwayRepository;

  @override
  State<ActivitySubmissionReviewScreen> createState() =>
      _ActivitySubmissionReviewScreenState();
}

class _ActivitySubmissionReviewScreenState
    extends State<ActivitySubmissionReviewScreen> {
  ActivitySubmissionReviewModel? _review;
  bool _isLoading = true;
  String _selectedCriterionId = 'correctness';
  bool _codeCopied = false;

  // AI review generation: re-check the saved review a limited number of times.
  static const int _maxAiPolls = 10;
  static const Duration _aiPollInterval = Duration(seconds: 6);
  Timer? _aiPollTimer;
  int _aiPolls = 0;
  bool _aiGaveUp = false;

  @override
  void initState() {
    super.initState();
    final ActivitySubmissionReviewModel? cached =
        SupabasePathwayRepository.cachedReview(widget.submissionId);
    if (cached != null) {
      _review = cached;
      _isLoading = false;
    } else if (widget.initialSubmission != null) {
      _review = ActivitySubmissionReviewModel.fromCachedSubmission(
        widget.initialSubmission!,
      );
      _isLoading = false;
    }
    _loadReview();
  }

  @override
  void dispose() {
    _aiPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReview({bool triggerGeneration = true}) async {
    try {
      final ActivitySubmissionReviewModel? data =
          await widget.pathwayRepository.getSubmissionReview(
        widget.submissionId,
        cachedSubmission: widget.initialSubmission,
        triggerGeneration: triggerGeneration,
      );

      if (mounted && data != null) {
        setState(() {
          _review = data;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    _scheduleAiRecheck();
  }

  /// While the AI review has not been saved yet, look again every few seconds
  /// (reading only, without asking the server to generate it again).
  void _scheduleAiRecheck() {
    _aiPollTimer?.cancel();
    if (!mounted) return;
    final bool pending = _review != null && _review!.acfEvaluation == null;
    if (!pending) return;

    if (_aiPolls >= _maxAiPolls) {
      if (!_aiGaveUp) setState(() => _aiGaveUp = true);
      return;
    }
    _aiPollTimer = Timer(_aiPollInterval, () {
      _aiPolls++;
      _loadReview(triggerGeneration: false);
    });
  }

  void _retryAiReview() {
    HapticFeedback.lightImpact();
    SupabasePathwayRepository.resetGenerationCooldown(widget.submissionId);
    setState(() {
      _aiPolls = 0;
      _aiGaveUp = false;
    });
    _loadReview();
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/learn/activity');
    }
  }

  void _handleCopyCode(String code) {
    if (code.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    setState(() {
      _codeCopied = true;
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _codeCopied = false;
        });
      }
    });
  }

  String _getCodeFilename(String prefix, String lang) {
    final String l = lang.toLowerCase();
    switch (l) {
      case 'java':
        return '$prefix.java';
      case 'python':
      case 'py':
        return '${prefix.toLowerCase()}.py';
      case 'javascript':
      case 'js':
        return '${prefix.toLowerCase()}.js';
      case 'php':
        return '${prefix.toLowerCase()}.php';
      case 'cpp':
      case 'c++':
        return '${prefix.toLowerCase()}.cpp';
      case 'c':
        return '${prefix.toLowerCase()}.c';
      case 'csharp':
      case 'c#':
      case 'cs':
        return '$prefix.cs';
      case 'go':
        return '${prefix.toLowerCase()}.go';
      case 'rust':
      case 'rs':
        return '${prefix.toLowerCase()}.rs';
      default:
        return '${prefix.toLowerCase()}.txt';
    }
  }

  String _formatConceptTag(String tag) {
    switch (tag.toLowerCase().trim()) {
      case 'loops':
        return 'Loops & Iterations';
      case 'recursion':
        return 'Recursion & Backtracking';
      case 'boundary_handling':
        return 'Boundary & Edge Case Handling';
      case 'error_handling':
        return 'Error & Exception Handling';
      case 'data_structures':
        return 'Data Structures';
      case 'string_manipulation':
        return 'String Manipulation';
      case 'pointer_management':
        return 'Pointer & Memory Management';
      case 'immutability':
        return 'Immutability & Pure Functions';
      case 'modularity':
        return 'Code Modularity & Clean Architecture';
      case 'type_safety':
        return 'Type Safety & Validation';
      case 'concurrency':
        return 'Concurrency & Multithreading';
      case 'memory_management':
        return 'Memory Management & Allocation';
      case 'algorithmic_thinking':
        return 'Algorithmic Problem Solving';
      case 'io_handling':
        return 'I/O & Stream Handling';
      default:
        return tag
            .split('_')
            .map((String w) => w.isNotEmpty
                ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                : '')
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color surface =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Loading State
    if (_isLoading && _review == null) {
      return PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            context.go('/learn/activity');
          }
        },
        child: Scaffold(
          backgroundColor: bg,
          appBar: _buildAppBar(surface, borderColor, textPrimary),
          body: _buildSkeletonLoader(isDark, borderColor),
        ),
      );
    }

    // Submission Not Found State
    if (_review == null) {
      return PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            context.go('/learn/activity');
          }
        },
        child: Scaffold(
          backgroundColor: bg,
          appBar: _buildAppBar(surface, borderColor, textPrimary),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Submission not found',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    'The requested activity submission could not be retrieved.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  OutlinedButton(
                    onPressed: _handleBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      minimumSize: const Size(160.0, 48.0),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text('Back to Activity'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final ActivitySubmissionReviewModel review = _review!;
    final AcfEvaluationModel? acf = review.acfEvaluation;
    final String currentCode = review.submittedCode;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          context.go('/learn/activity');
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(surface, borderColor, textPrimary),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── 1. QUIET EDITORIAL HEADER (NO CARD) ──────────────────────
                _buildHeaderSection(
                  review: review,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 18.0),

                // ── 2. CLEAN TELEMETRY STRIP (border-y border-border/40) ────
                _buildTelemetryStrip(
                  review: review,
                  isDark: isDark,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 24.0),

                // ── 3. AUTOMATED CODE FEEDBACK (HOLLOW TABS & DIAGNOSTICS) ───
                if (acf != null) ...<Widget>[
                  _buildAcfDiagnosticsSection(
                    acf: acf,
                    isDark: isDark,
                    surface: surface,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 24.0),
                ] else ...<Widget>[
                  _buildAiPendingSection(
                    surface: surface,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 24.0),
                ],

                // ── 4. VERIFIED MENTOR FEEDBACK (HOLLOW ROW) ────────────────
                if (review.mentorFeedback != null &&
                    review.mentorFeedback!.feedbackText.trim().isNotEmpty &&
                    review.mentorFeedback!.status.toLowerCase() == 'published') ...<Widget>[
                  _buildMentorFeedbackSection(
                    feedback: review.mentorFeedback!,
                    isDark: isDark,
                    surface: surface,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 24.0),
                ],

                // ── 5. SUBMITTED CODE REVIEW ─────────────────────────────────
                _buildCodeReviewSection(
                  review: review,
                  currentCode: currentCode,
                  isDark: isDark,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 24.0),

                // ── 6. AREAS FOR GROWTH & RECOMMENDATIONS (LEDGER ROWS) ─────
                if (acf != null &&
                    (acf.weakTopics.isNotEmpty || acf.recommendations.isNotEmpty)) ...<Widget>[
                  _buildGrowthAndRecommendationsSection(
                    acf: acf,
                    isDark: isDark,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 28.0),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared bits ────────────────────────────────────────────────────────────
  Widget _sectionHeader(
    String title,
    Color borderColor,
    Color textPrimary, {
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  // ── AI review pending ──────────────────────────────────────────────────────
  Widget _buildAiPendingSection({
    required Color surface,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool gaveUp = _aiGaveUp;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: borderColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (gaveUp)
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 18.0,
                    color: textSecondary,
                  )
                else
                  const SizedBox(
                    width: 16.0,
                    height: 16.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    gaveUp
                        ? "The AI review isn't ready yet"
                        : 'Generating your AI code review',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            Text(
              gaveUp
                  ? 'It is taking longer than usual. Your submission is saved. Check again in a moment.'
                  : 'This usually takes under a minute. Your submission is saved, and the review will appear here when it is ready.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                height: 1.5,
                color: textSecondary,
              ),
            ),
            if (gaveUp) ...<Widget>[
              const SizedBox(height: 8.0),
              OutlinedButton(
                onPressed: _retryAiReview,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  minimumSize: const Size(48.0, 48.0),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text('Check again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
    Color surface,
    Color borderColor,
    Color textPrimary,
  ) {
    return AppBar(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 22.0),
        constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
        onPressed: _handleBack,
        tooltip: 'Back',
      ),
      title: Text(
        'Submission review',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16.0,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: borderColor, height: 1.0),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeaderSection({
    required ActivitySubmissionReviewModel review,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final String language = review.language.isNotEmpty
        ? '${review.language[0].toUpperCase()}${review.language.substring(1)}'
        : 'Code';
    final String tests = review.testsPassedCount != null
        ? '${review.testsPassedCount}/${review.totalTestsCount ?? review.testsPassedCount} tests passed'
        : (review.isPassed ? 'All tests passed' : 'Tests failed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (review.moduleTitle.trim().isNotEmpty) ...<Widget>[
          Text(
            review.moduleTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 4.0),
        ],
        Text(
          review.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8.0),
        Row(
          children: <Widget>[
            Icon(
              review.isPassed ? Icons.check_rounded : Icons.close_rounded,
              size: 16.0,
              color: review.isPassed ? AppColors.primary : AppColors.error,
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Text(
                '${review.isPassed ? 'Passed' : 'Failed'} · $language · $tests · ${review.timeAgoFormatted}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Telemetry ──────────────────────────────────────────────────────────────
  Widget _buildTelemetryStrip({
    required ActivitySubmissionReviewModel review,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    Widget stat(String label, Widget value) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
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
          const SizedBox(height: 3.0),
          value,
        ],
      ),
      ),
    );

    TextStyle mono() => GoogleFonts.jetBrainsMono(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          stat(
            'Score',
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '${review.overallScore}',
                    style: mono().copyWith(fontSize: 20.0),
                  ),
                  TextSpan(
                    text: ' / 100',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          stat(
            'Result',
            Text(
              review.isPassed ? 'Passed' : review.verdict,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          stat('Target time', Text(review.targetTime, style: mono())),
          stat('Target space', Text(review.targetSpace, style: mono())),
        ],
      ),
    );
  }

  // ── AI feedback ────────────────────────────────────────────────────────────
  Widget _buildAcfDiagnosticsSection({
    required AcfEvaluationModel acf,
    required bool isDark,
    required Color surface,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final List<AcfCriterionModel> criteria = acf.allCriteria;
    final AcfCriterionModel selected = criteria.firstWhere(
      (AcfCriterionModel c) => c.id == _selectedCriterionId,
      orElse: () => criteria.first,
    );

    Widget list(String title, List<String> items, IconData icon) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16.0),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6.0),
        for (final String item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(icon, size: 16.0, color: textSecondary),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionHeader('AI code review', borderColor, textPrimary),
        FilterTabBar(
          tabs: <FilterTabItem>[
            for (final AcfCriterionModel c in criteria)
              FilterTabItem(id: c.id, label: c.label, count: c.score),
          ],
          selectedId: selected.id,
          onTabSelected: (String id) => setState(() => _selectedCriterionId = id),
        ),
        const SizedBox(height: 8.0),
        Text(
          selected.cotReasoning,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.0,
            height: 1.55,
            color: textPrimary,
          ),
        ),
        if (selected.strengths.isNotEmpty)
          list('Strengths', selected.strengths, Icons.check_rounded),
        if (selected.improvements.isNotEmpty)
          list('To improve', selected.improvements, Icons.arrow_right_alt_rounded),
      ],
    );
  }

  // ── Mentor feedback ────────────────────────────────────────────────────────
  Widget _buildMentorFeedbackSection({
    required MentorFeedbackModel feedback,
    required bool isDark,
    required Color surface,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final List<FeedbackCommentModel> comments = feedback.comments.isNotEmpty
        ? feedback.comments
        : <FeedbackCommentModel>[
            FeedbackCommentModel(
              id: 'initial',
              text: feedback.feedbackText,
              authorName: feedback.mentorName ?? 'Mentor',
              authorRole: 'mentor',
              authorAvatarUrl: feedback.mentorAvatarUrl,
              createdAt: feedback.createdAt,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionHeader(
          'Mentor feedback',
          borderColor,
          textPrimary,
          trailing: feedback.gradeOverride != null
              ? Text(
                  'Grade ${feedback.gradeOverride}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12.0),
        for (int i = 0; i < comments.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < comments.length - 1 ? 14.0 : 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${comments[i].authorName ?? (comments[i].authorRole != 'learner' ? 'Mentor' : 'You')} · ${comments[i].authorRole != 'learner' ? 'Mentor' : 'Learner'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  comments[i].text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    height: 1.5,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Submitted code ─────────────────────────────────────────────────────────
  Widget _buildCodeReviewSection({
    required ActivitySubmissionReviewModel review,
    required String currentCode,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionHeader(
          'Submitted code',
          borderColor,
          textPrimary,
          trailing: TextButton.icon(
            onPressed: () => _handleCopyCode(currentCode),
            style: TextButton.styleFrom(
              minimumSize: const Size(48.0, 40.0),
              foregroundColor: textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
            icon: Icon(
              _codeCopied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16.0,
            ),
            label: Text(
              _codeCopied ? 'Copied' : 'Copy',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          _getCodeFilename('solution', review.language),
          style: GoogleFonts.jetBrainsMono(fontSize: 12.0, color: textSecondary),
        ),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceLowest : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: _buildCodeWithLineNumbers(
              currentCode.isNotEmpty
                  ? currentCode
                  : '// No code recorded for this submission.',
              review.language,
              isDark,
              borderColor,
              textPrimary,
              textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeWithLineNumbers(
    String code,
    String language,
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final String text = code.endsWith('\n')
        ? code.substring(0, code.length - 1)
        : code;
    final List<CodeToken> tokens = tokenizeCode(text, language);
    final TextStyle base = GoogleFonts.jetBrainsMono(
      fontSize: 12.5,
      height: 1.5,
      color: textPrimary,
    );

    final List<Widget> rows = <Widget>[];
    int offset = 0;
    int number = 1;
    for (final String line in text.split('\n')) {
      final int start = offset;
      final int end = offset + line.length;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32.0,
                padding: const EdgeInsets.only(right: 8.0),
                margin: const EdgeInsets.only(right: 8.0),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: Text(
                  '$number',
                  textAlign: TextAlign.right,
                  style: base.copyWith(color: textSecondary),
                ),
              ),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(
                    children: line.isEmpty
                        ? <TextSpan>[const TextSpan(text: ' ')]
                        : highlightedSpans(
                            text: text,
                            tokens: tokens,
                            base: base,
                            isDark: isDark,
                            start: start,
                            end: end,
                          ),
                    style: base,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      offset = end + 1;
      number++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  // ── Next steps ─────────────────────────────────────────────────────────────
  Widget _buildGrowthAndRecommendationsSection({
    required AcfEvaluationModel acf,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionHeader('Recommended next steps', borderColor, textPrimary),
        for (final WeakTopicModel wt in acf.weakTopics)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _formatConceptTag(wt.conceptTag),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      wt.dimension.isEmpty
                          ? ''
                          : wt.dimension[0].toUpperCase() +
                                wt.dimension.substring(1),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                if (wt.evidence.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4.0),
                  Text(
                    wt.evidence,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        for (final ModuleRecommendationModel rec in acf.recommendations)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/modules/${rec.moduleId}');
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 56.0),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          rec.moduleTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          rec.rationale,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Practice',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.0,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Skeleton Loader (Clean, minimal placeholder) ───────────────────────────
  Widget _buildSkeletonLoader(bool isDark, Color borderColor) {
    final Color boneColor = isDark
        ? const Color(0xFF27272A)
        : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 140.0,
            height: 12.0,
            decoration: BoxDecoration(
              color: boneColor,
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          const SizedBox(height: 12.0),
          Container(
            width: 220.0,
            height: 20.0,
            decoration: BoxDecoration(
              color: boneColor,
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          const SizedBox(height: 10.0),
          Container(
            width: 180.0,
            height: 12.0,
            decoration: BoxDecoration(
              color: boneColor,
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          const SizedBox(height: 20.0),

          // Telemetry placeholder
          Container(
            height: 52.0,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 24.0),

          // Criteria Grid placeholder
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: boneColor,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Container(
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: boneColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: boneColor,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Container(
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: boneColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),

          // Code placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: boneColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
