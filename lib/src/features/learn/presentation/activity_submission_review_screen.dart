import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../common_widgets/language_icon.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/code_diff_helper.dart';
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
  String _activeCodeTab = 'submission'; // 'submission' | 'refinement'

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

  void _handleCopyCode(String code, {required String label}) {
    if (code.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label copied to clipboard',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color surface =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color cardBg =
        isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (_isLoading && _review == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/learn/activity');
              }
            },
          ),
          title: Text(
            'Submission Review',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12.0),
              Text(
                'Loading submission review...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.0,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ActivitySubmissionReviewModel review = _review!;
    final AcfEvaluationModel? acf = review.acfEvaluation;
    final String currentCode = _activeCodeTab == 'refinement' &&
            acf?.recommendedRefactoring != null
        ? acf!.recommendedRefactoring!.refactoredCode
        : review.submittedCode;
    final int lineCount = currentCode.trim().isNotEmpty
        ? currentCode.trimRight().split('\n').length
        : 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20.0),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/learn/activity');
            }
          },
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
            color: borderColor,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── 1. HERO ASSESSMENT CARD ────────────────────────────────────
              _buildHeroAssessmentCard(
                review: review,
                acf: acf,
                isDark: isDark,
                surface: surface,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 16.0),

              // ── 2. ACF 4 CRITERIA DIAGNOSTICS ─────────────────────────────
              if (acf != null) ...<Widget>[
                _buildAcfDiagnosticsSection(
                  acf: acf,
                  isDark: isDark,
                  surface: surface,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 16.0),
              ],

              // ── 3. VERIFIED MENTOR FEEDBACK (If Present) ──────────────────
              if (review.mentorFeedback != null &&
                  review.mentorFeedback!.feedbackText.trim().isNotEmpty) ...<Widget>[
                _buildMentorFeedbackCard(
                  feedback: review.mentorFeedback!,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 16.0),
              ],

              // ── 4. CODE REVIEW SECTION ─────────────────────────────────────
              _buildCodeReviewSection(
                review: review,
                acf: acf,
                currentCode: currentCode,
                lineCount: lineCount,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 24.0),

              // ── 5. BOTTOM ACTIONS ──────────────────────────────────────────
              _buildBottomActionDock(
                review: review,
                isDark: isDark,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 28.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Hero Assessment Card ────────────────────────────────────────────────
  Widget _buildHeroAssessmentCard({
    required ActivitySubmissionReviewModel review,
    required AcfEvaluationModel? acf,
    required bool isDark,
    required Color surface,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Metadata Chips Row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6.0,
            runSpacing: 6.0,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14.0,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    'Verified Submission',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              Text('·', style: TextStyle(color: textSecondary, fontSize: 12.0)),
              Text(
                'All Tests Passed',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              Text('·', style: TextStyle(color: textSecondary, fontSize: 12.0)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.schedule_rounded,
                    size: 12.0,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 3.0),
                  Text(
                    review.targetTime,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Text('·', style: TextStyle(color: textSecondary, fontSize: 12.0)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.storage_rounded,
                    size: 12.0,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 3.0),
                  Text(
                    review.targetSpace,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Challenge Title (Full width for natural typography & breathing room)
          Text(
            review.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12.0),

          // Overall Score Banner (Option 1: Wide, balanced, and uncompressed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 9.0,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 7.0,
                      height: 7.0,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Overall Score',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
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
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),

          // Executive Summary
          Text(
            acf?.executiveSummary ??
                'Solution verified and execution passed against all problem constraints.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.45,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. ACF Diagnostics ─────────────────────────────────────────────────────
  Widget _buildAcfDiagnosticsSection({
    required AcfEvaluationModel acf,
    required bool isDark,
    required Color surface,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final List<AcfCriterionModel> criteria = acf.allCriteria;
    final AcfCriterionModel selectedCriterion = criteria.firstWhere(
      (AcfCriterionModel c) => c.id == _selectedCriterionId,
      orElse: () => criteria.first,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header kicker
          Text(
            'AUTOMATED CODE FEEDBACK (ACF)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 10.0),

          // 4 Criteria Tabs Grid (2x2)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            childAspectRatio: 2.3,
            children: criteria.map((AcfCriterionModel c) {
              final bool isSelected = _selectedCriterionId == c.id;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedCriterionId = c.id;
                  });
                },
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0))
                        : cardBg,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : borderColor,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              c.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1.0),
                            Text(
                              c.weight,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : borderColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          '${c.score}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.primary : textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12.0),

          // Selected Criterion Details Output
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header with contextual badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${selectedCriterion.label} Analysis',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          if (selectedCriterion.id == 'efficiency' &&
                              selectedCriterion.detectedTime != null) ...<Widget>[
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                '${selectedCriterion.detectedTime} time · ${selectedCriterion.detectedSpace ?? 'O(1)'} space',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                          if (selectedCriterion.id == 'maintainability' &&
                              selectedCriterion.modularityRating != null) ...<Widget>[
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                'Modularity: ${selectedCriterion.modularityRating}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                          if (selectedCriterion.id == 'correctness' &&
                              selectedCriterion.edgeCaseStatus != null &&
                              selectedCriterion.edgeCaseStatus!.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.verified_outlined,
                                    size: 11.0,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    selectedCriterion.edgeCaseStatus!.length <= 30
                                        ? selectedCriterion.edgeCaseStatus!
                                        : (selectedCriterion.score >= 90
                                            ? 'Verified Edge Cases'
                                            : 'Edge Cases Checked'),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '${selectedCriterion.score} / 100',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // Chain-of-Thought Reasoning
                Text(
                  selectedCriterion.cotReasoning,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    height: 1.45,
                    color: textPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12.0),

                // Strengths Box
                if (selectedCriterion.strengths.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'STRENGTHS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        ...selectedCriterion.strengths.map((String s) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  '✓ ',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.0,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: textPrimary,
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

                // Improvements Box
                if (selectedCriterion.improvements.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'AREAS FOR IMPROVEMENT',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        ...selectedCriterion.improvements.map((String imp) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 13.0,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 5.0),
                                Expanded(
                                  child: Text(
                                    imp,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: textPrimary,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Mentor Feedback Card ────────────────────────────────────────────────
  Widget _buildMentorFeedbackCard({
    required MentorFeedbackModel feedback,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 14.0,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  (feedback.mentorName != null &&
                          feedback.mentorName!.isNotEmpty)
                      ? feedback.mentorName![0].toUpperCase()
                      : 'M',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    feedback.mentorName ?? 'Mentor Review',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Verified Mentor Feedback',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (feedback.gradeOverride != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    feedback.gradeOverride!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            '“${feedback.feedbackText}”',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Code Review Section ─────────────────────────────────────────────────
  Widget _buildCodeReviewSection({
    required ActivitySubmissionReviewModel review,
    required AcfEvaluationModel? acf,
    required String currentCode,
    required int lineCount,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool hasRefactoring = acf?.recommendedRefactoring != null &&
        acf!.recommendedRefactoring!.refactoredCode.trim().isNotEmpty;

    final String refactoredCode =
        hasRefactoring ? acf.recommendedRefactoring!.refactoredCode : '';

    final List<DiffLine>? diffLines =
        _activeCodeTab == 'refinement' && hasRefactoring
            ? CodeDiffHelper.computeLineDiff(
                review.submittedCode,
                refactoredCode,
              )
            : null;

    final int addedCount = diffLines != null
        ? diffLines.where((DiffLine l) => l.type == DiffLineType.added).length
        : 0;
    final int removedCount = diffLines != null
        ? diffLines.where((DiffLine l) => l.type == DiffLineType.removed).length
        : 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? borderColor : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 1. Code Tabs Bar (Underlined tabs with horizontal scroll, matching Web)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: <Widget>[
                  // "Your Submission" Tab
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _activeCodeTab = 'submission';
                      });
                    },
                    borderRadius: BorderRadius.circular(6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeCodeTab == 'submission'
                                ? const Color(0xFFF1F5F9)
                                : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                      ),
                      child: Text(
                        'Your Submission',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: _activeCodeTab == 'submission'
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _activeCodeTab == 'submission'
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),

                  if (hasRefactoring) ...<Widget>[
                    const SizedBox(width: 16.0),
                    // "Mentor Refinement" Tab
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _activeCodeTab = 'refinement';
                        });
                      },
                      borderRadius: BorderRadius.circular(6.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _activeCodeTab == 'refinement'
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
                              width: 2.0,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 6.0,
                              height: 6.0,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              'Mentor Refinement',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: _activeCodeTab == 'refinement'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _activeCodeTab == 'refinement'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 2. Editor File Header (Filename badge, line count, and diff pills)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 8.0,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Row(
              children: <Widget>[
                // Filename badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LanguageIcon(
                        language: review.language,
                        size: 13.0,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        _getCodeFilename(
                          _activeCodeTab == 'refinement'
                              ? 'Refactored'
                              : 'Solution',
                          review.language,
                        ),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  diffLines != null
                      ? '${diffLines.length} lines'
                      : '$lineCount lines',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (diffLines != null) ...<Widget>[
                  const SizedBox(width: 8.0),
                  Text(
                    '+$addedCount',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(width: 5.0),
                  Text(
                    '-$removedCount',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF43F5E),
                    ),
                  ),
                ],
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleCopyCode(
                      currentCode,
                      label: _activeCodeTab == 'refinement'
                          ? 'Mentor refinement'
                          : 'Submission code',
                    ),
                    borderRadius: BorderRadius.circular(6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.copy_rounded,
                            size: 12.0,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            'Copy',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code View With Line Numbers & Diff Highlighting
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: diffLines != null
                  ? _buildDiffCodeView(diffLines)
                  : _buildCodeWithLineNumbers(
                      currentCode.isNotEmpty
                          ? currentCode
                          : '// No code recorded for this submission.',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffCodeView(List<DiffLine> diffLines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(diffLines.length, (int index) {
        final DiffLine line = diffLines[index];
        final bool isAdded = line.type == DiffLineType.added;
        final bool isRemoved = line.type == DiffLineType.removed;

        final Color rowBg = isAdded
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : isRemoved
                ? const Color(0xFFF43F5E).withValues(alpha: 0.12)
                : Colors.transparent;

        final Color gutterTextColor = isAdded
            ? const Color(0xFF34D399)
            : isRemoved
                ? const Color(0xFFF43F5E)
                : const Color(0xFF475569);

        final Color dividerColor = isAdded
            ? const Color(0xFF10B981).withValues(alpha: 0.35)
            : isRemoved
                ? const Color(0xFFF43F5E).withValues(alpha: 0.35)
                : const Color(0xFF1E293B);

        final int? lineNum = isRemoved ? line.oldLineNumber : line.newLineNumber;

        return Container(
          color: rowBg,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Diff symbol (+ / - / space)
              SizedBox(
                width: 14.0,
                child: Text(
                  isAdded ? '+' : (isRemoved ? '-' : ' '),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: gutterTextColor,
                  ),
                ),
              ),

              // Line number gutter with right divider
              Container(
                width: 34.0,
                padding: const EdgeInsets.only(right: 8.0),
                margin: const EdgeInsets.only(right: 10.0),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: dividerColor,
                      width: 1.0,
                    ),
                  ),
                ),
                child: Text(
                  lineNum != null ? '$lineNum' : ' ',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.0,
                    height: 1.45,
                    color: gutterTextColor,
                  ),
                ),
              ),

              // Code content
              SelectableText(
                line.content.isNotEmpty ? line.content : ' ',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  height: 1.45,
                  decoration:
                      isRemoved ? TextDecoration.lineThrough : null,
                  decorationColor:
                      isRemoved ? const Color(0xFFF43F5E) : null,
                  color: isRemoved
                      ? const Color(0xFFFDA4AF)
                      : (isAdded
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFE2E8F0)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCodeWithLineNumbers(String code) {
    final List<String> rawLines = code.split('\n');
    final List<String> lines =
        rawLines.isNotEmpty && rawLines.last == ''
            ? rawLines.sublist(0, rawLines.length - 1)
            : rawLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(lines.length, (int index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Gutter spacer matching diff view
              const SizedBox(width: 14.0),

              // Line number gutter with right divider
              Container(
                width: 34.0,
                padding: const EdgeInsets.only(right: 8.0),
                margin: const EdgeInsets.only(right: 10.0),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Color(0xFF1E293B),
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
                    color: const Color(0xFF475569),
                  ),
                ),
              ),

              // Code content
              SelectableText(
                lines[index].isNotEmpty ? lines[index] : ' ',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  height: 1.45,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── 5. Bottom Action Dock ──────────────────────────────────────────────────
  Widget _buildBottomActionDock({
    required ActivitySubmissionReviewModel review,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool hasModule = review.moduleId.isNotEmpty;

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/learn/activity');
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              side: BorderSide(color: borderColor),
            ),
            child: Text(
              'Back to Activity',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
        ),
        if (hasModule) ...<Widget>[
          const SizedBox(width: 12.0),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/modules/${review.moduleId}');
              },
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 15.0,
                color: Color(0xFF121316),
              ),
              label: Text(
                'Open Module',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF121316),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
