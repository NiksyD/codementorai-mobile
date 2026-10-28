import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/activity_submission_review_model.dart';
import '../domain/dashboard_submission.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialSubmission != null) {
      _review = ActivitySubmissionReviewModel.fromCachedSubmission(
        widget.initialSubmission!,
      );
      _isLoading = false;
    }
    _loadReview();
  }

  Future<void> _loadReview() async {
    try {
      final ActivitySubmissionReviewModel? data =
          await widget.pathwayRepository.getSubmissionReview(
        widget.submissionId,
        cachedSubmission: widget.initialSubmission,
      );

      if (mounted && data != null) {
        setState(() {
          _review = data;
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
      case 'typescript':
      case 'ts':
        return '${prefix.toLowerCase()}.ts';
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
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.code_rounded,
                      size: 24.0,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Submission Not Found',
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
                      fontSize: 12.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  OutlinedButton.icon(
                    onPressed: _handleBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16.0),
                    label: const Text('Back to Activity Log'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                    ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
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
        icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20.0),
        onPressed: _handleBack,
        tooltip: 'Back to Activity',
      ),
      title: Text(
        'Submission Review',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15.0,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: borderColor.withValues(alpha: 0.6),
          height: 1.0,
        ),
      ),
    );
  }

  // ── 1. Quiet Editorial Header (Hollow, unboxed, natural typography) ─────────
  Widget _buildHeaderSection({
    required ActivitySubmissionReviewModel review,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (review.moduleTitle.trim().isNotEmpty) ...<Widget>[
          Text(
            review.moduleTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 4.0),
        ],

        // Challenge Title
        Text(
          review.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.0,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8.0),

        // Quiet Inline Metadata Row (Unbracketed, quiet dots)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6.0,
          runSpacing: 4.0,
          children: <Widget>[
            // Status Indicator Dot + Text
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6.0,
                  height: 6.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: review.isPassed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 5.0),
                Text(
                  review.isPassed ? 'Verified Passed' : 'Submission Failed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: review.isPassed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            Text('·', style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12.0)),
            Text(
              review.language.isNotEmpty
                  ? '${review.language[0].toUpperCase()}${review.language.substring(1)}'
                  : 'Code',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: textSecondary,
              ),
            ),
            if (review.moduleTitle.isNotEmpty) ...<Widget>[
              Text('·', style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12.0)),
              Text(
                review.moduleTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: textSecondary,
                ),
              ),
            ],
            Text('·', style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12.0)),
            Text(
              review.testsPassedCount != null
                  ? '${review.testsPassedCount}/${review.totalTestsCount ?? review.testsPassedCount} Tests Passed'
                  : 'All Tests Passed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: textSecondary,
              ),
            ),
            Text('·', style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 12.0)),
            Text(
              review.timeAgoFormatted,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. Clean Telemetry Strip (border-y border-border/40, NO CARDS) ─────────
  Widget _buildTelemetryStrip({
    required ActivitySubmissionReviewModel review,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor.withValues(alpha: 0.6), width: 1.0),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.6), width: 1.0),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'SCORE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 3.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      '${review.overallScore}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      ' / 100',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'STATUS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 5.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: review.isPassed
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 5.0),
                    Flexible(
                      child: Text(
                        review.isPassed ? 'Passed' : review.verdict,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: review.isPassed
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Runtime Complexity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'RUNTIME',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  review.targetTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Memory Complexity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'MEMORY',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  review.targetSpace,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Automated Code Feedback (Hollow Tabs & Diagnostics, NO CARDS) ───────
  Widget _buildAcfDiagnosticsSection({
    required AcfEvaluationModel acf,
    required bool isDark,
    required Color surface,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final List<AcfCriterionModel> criteria = acf.allCriteria;
    final AcfCriterionModel selectedCriterion = criteria.firstWhere(
      (AcfCriterionModel c) => c.id == _selectedCriterionId,
      orElse: () => criteria.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Section Header with Hairline Bottom Border
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Automated Code Feedback',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            Text(
              '4 Evaluation Dimensions',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          height: 1.0,
          color: borderColor.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12.0),

        // 4 Criteria Tabs (Hollow 2x2 Grid)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 8.0,
          childAspectRatio: 2.8,
          children: criteria.map((AcfCriterionModel c) {
            final bool isSelected = _selectedCriterionId == c.id;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCriterionId = c.id;
                });
              },
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isSelected
                        ? borderColor
                        : borderColor.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      c.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? textPrimary : textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppColors.darkBackground : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                          color: isSelected
                              ? borderColor.withValues(alpha: 0.6)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${c.score}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primary : textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14.0),

        // Selected Criterion Reasoning Paragraph (Hollow typography)
        Text(
          selectedCriterion.cotReasoning,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            height: 1.5,
            color: textPrimary.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 14.0),

        // Strengths & Opportunities Lists (Clean editorial rows, NO heavy colored card boxes)
        if (selectedCriterion.strengths.isNotEmpty) ...<Widget>[
          Text(
            'STRENGTHS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6.0),
          ...selectedCriterion.strengths.map((String str) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '✓',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      str,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        height: 1.4,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10.0),
        ],

        if (selectedCriterion.improvements.isNotEmpty) ...<Widget>[
          Text(
            'OPPORTUNITIES',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6.0),
          ...selectedCriterion.improvements.map((String imp) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '•',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      imp,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        height: 1.4,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── 4. Verified Mentor Feedback (Conversation Thread, NO CARD) ────────────
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
              authorName: feedback.mentorName ?? 'Verified Mentor',
              authorRole: 'mentor',
              authorAvatarUrl: feedback.mentorAvatarUrl,
              createdAt: feedback.createdAt,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Mentor Feedback',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                if (comments.length > 1) ...<Widget>[
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '${comments.length} notes',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (feedback.gradeOverride != null)
              Text(
                'Grade ${feedback.gradeOverride}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          height: 1.0,
          color: borderColor.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12.0),

        // Conversation thread comments list
        ...comments.asMap().entries.map((MapEntry<int, FeedbackCommentModel> entry) {
          final int idx = entry.key;
          final FeedbackCommentModel comment = entry.value;
          final bool isMentor = comment.authorRole != 'learner';
          final String name = comment.authorName ?? (isMentor ? 'Verified Mentor' : 'Learner');

          return Padding(
            padding: EdgeInsets.only(bottom: idx < comments.length - 1 ? 12.0 : 0.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 13.0,
                  backgroundColor: isMentor
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : surface,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : (isMentor ? 'M' : 'L'),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.0,
                      color: isMentor ? AppColors.primary : textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: isMentor
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : surface,
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: isMentor
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : borderColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              isMentor ? 'Mentor' : 'Learner',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isMentor ? AppColors.primary : textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5.0),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          comment.text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            height: 1.45,
                            color: textPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── 5. Submitted Code Review ───────────────────────────────────────────────
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
        // Header with Filename & Copy Code Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Submitted Code',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 6.0),
                Text(
                  '(${_getCodeFilename("solution", review.language)})',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.0,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _handleCopyCode(currentCode),
              borderRadius: BorderRadius.circular(4.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _codeCopied
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      size: 13.0,
                      color: _codeCopied
                          ? const Color(0xFF10B981)
                          : textSecondary,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      _codeCopied ? 'Copied' : 'Copy Code',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                        color: _codeCopied
                            ? const Color(0xFF10B981)
                            : textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          height: 1.0,
          color: borderColor.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12.0),

        // Dark Code Container with Line Numbers Gutter
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderColor.withValues(alpha: 0.6)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: _buildCodeWithLineNumbers(
              currentCode.isNotEmpty
                  ? currentCode
                  : '// No code recorded for this submission.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeWithLineNumbers(String code) {
    final List<String> rawLines = code.split('\n');
    final List<String> lines =
        rawLines.isNotEmpty && rawLines.last == ''
            ? rawLines.sublist(0, rawLines.length - 1)
            : rawLines;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(lines.length, (int index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Line Number Gutter
                Container(
                  width: 32.0,
                  padding: const EdgeInsets.only(right: 8.0),
                  margin: const EdgeInsets.only(right: 8.0),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: AppColors.darkBorder.withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      height: 1.45,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),

                // Code Content (Soft-wrapped to next line)
                Expanded(
                  child: SelectableText(
                    lines[index].isNotEmpty ? lines[index] : ' ',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      height: 1.45,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── 6. Areas for Growth & Recommendations (Clean Ledger Rows, NO CARDS) ───
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
        // Header
        Text(
          'Recommended Next Steps',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          width: double.infinity,
          height: 1.0,
          color: borderColor.withValues(alpha: 0.5),
        ),

        // Weak Topics (Ledger rows)
        if (acf.weakTopics.isNotEmpty) ...<Widget>[
          ...acf.weakTopics.map((WeakTopicModel wt) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: borderColor.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF27272A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: borderColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          wt.dimension.substring(0, 1).toUpperCase() +
                              wt.dimension.substring(1),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (wt.evidence.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4.0),
                    Text(
                      wt.evidence,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],

        // Module Recommendations (Clean Ledger rows with Practice link)
        if (acf.recommendations.isNotEmpty) ...<Widget>[
          ...acf.recommendations.map((ModuleRecommendationModel rec) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 11.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: borderColor.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/modules/${rec.moduleId}');
                          },
                          child: Text(
                            rec.moduleTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2.5),
                        Text(
                          rec.rationale,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            color: textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/modules/${rec.moduleId}');
                    },
                    borderRadius: BorderRadius.circular(4.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Practice',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 3.0),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13.0,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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
                    borderRadius: BorderRadius.circular(8.0),
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
                    borderRadius: BorderRadius.circular(8.0),
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
