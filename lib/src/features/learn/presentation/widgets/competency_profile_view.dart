import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../domain/learn_dashboard_data.dart';

class _MetricRowData {
  const _MetricRowData({required this.label, required this.value});
  final String label;
  final int value;
}

/// Represents a validated learner tier aligned with Web:
/// "Competition Ready" (>=85), "Nearly Competition Ready" (>=70), "Developing" (>=50), "Beginner" (<50), or "Uncalibrated".
class LearnerTierData {
  const LearnerTierData({
    required this.label,
    required this.badgeColor,
    required this.badgeBg,
    required this.badgeBorder,
    this.range = '',
    this.description = '',
  });

  final String label;
  final Color badgeColor;
  final Color badgeBg;
  final Color badgeBorder;
  final String range;
  final String description;

  static const List<LearnerTierData> allTiers = <LearnerTierData>[
    LearnerTierData(
      label: 'Competition Ready',
      badgeColor: Color(0xFF10B981),
      badgeBg: Color(0x1F10B981),
      badgeBorder: Color(0x3310B981),
      range: '85% – 100%',
      description: 'Mastered production algorithmic logic, exceptional readability, and clean maintainability.',
    ),
    LearnerTierData(
      label: 'Nearly Competition Ready',
      badgeColor: Color(0xFF0EA5E9),
      badgeBg: Color(0x1F0EA5E9),
      badgeBorder: Color(0x330EA5E9),
      range: '70% – 84%',
      description: 'Solid algorithmic foundations with minor opportunities for style or runtime optimization.',
    ),
    LearnerTierData(
      label: 'Developing',
      badgeColor: Color(0xFFF59E0B),
      badgeBg: Color(0x1FF59E0B),
      badgeBorder: Color(0x33F59E0B),
      range: '50% – 69%',
      description: 'Working grasp of core problem solving; active review recommended on complexity and edge cases.',
    ),
    LearnerTierData(
      label: 'Beginner',
      badgeColor: Color(0xFFF43F5E),
      badgeBg: Color(0x1FF43F5E),
      badgeBorder: Color(0x33F43F5E),
      range: '0% – 49%',
      description: 'Initial calibration tier focusing on fundamentals, syntax accuracy, and basic test coverage.',
    ),
  ];

  static LearnerTierData forScore(int? score) {
    if (score == null) {
      return const LearnerTierData(
        label: 'Uncalibrated',
        badgeColor: Color(0xFF94A3B8),
        badgeBg: Color(0x1F94A3B8),
        badgeBorder: Color(0x3394A3B8),
        range: 'No data',
        description: 'Complete timed challenges or practice modules to establish your benchmark calibration.',
      );
    }
    if (score >= 85) return allTiers[0];
    if (score >= 70) return allTiers[1];
    if (score >= 50) return allTiers[2];
    return allTiers[3];
  }
}

/// ACF practice metrics computed deterministically from submission AI audits.
class AcfAnalysisResult {
  const AcfAnalysisResult({
    required this.hasData,
    required this.correctness,
    required this.readability,
    required this.maintainability,
    required this.efficiency,
    required this.compositeScore,
  });

  final bool hasData;
  final int correctness;
  final int readability;
  final int maintainability;
  final int efficiency;
  final int compositeScore;

  static AcfAnalysisResult fromSubmissions(List<DashboardSubmission> submissions) {
    int corrSum = 0;
    int readSum = 0;
    int maintSum = 0;
    int effSum = 0;
    int count = 0;

    for (final DashboardSubmission s in submissions) {
      final Map<String, dynamic>? f = s.findings;
      if (f != null) {
        final dynamic c = f['correctness'] is Map ? (f['correctness'] as Map)['score'] : null;
        final dynamic r = f['readability'] is Map ? (f['readability'] as Map)['score'] : null;
        final dynamic m = f['maintainability'] is Map ? (f['maintainability'] as Map)['score'] : null;
        final dynamic e = f['efficiency'] is Map ? (f['efficiency'] as Map)['score'] : null;

        if (c is num && r is num && m is num && e is num) {
          corrSum += c.toInt();
          readSum += r.toInt();
          maintSum += m.toInt();
          effSum += e.toInt();
          count++;
          continue;
        }
      }

      // If specific dimension findings not present, check if submission has an overall score
      final int? sc = s.score;
      if (sc != null && sc > 0) {
        corrSum += sc;
        readSum += sc;
        maintSum += sc;
        effSum += sc;
        count++;
      }
    }

    if (count > 0) {
      final int correctness = (corrSum / count).round();
      final int readability = (readSum / count).round();
      final int maintainability = (maintSum / count).round();
      final int efficiency = (effSum / count).round();
      final int composite = (correctness * 0.2484 +
              readability * 0.2453 +
              maintainability * 0.2516 +
              efficiency * 0.2547)
          .round();

      return AcfAnalysisResult(
        hasData: true,
        correctness: correctness,
        readability: readability,
        maintainability: maintainability,
        efficiency: efficiency,
        compositeScore: composite,
      );
    }

    final int total = submissions.length;
    final int passed = submissions.where((DashboardSubmission s) => s.isPassed).length;
    if (total > 0) {
      final int passRate = ((passed / total) * 100).round();
      final int estimatedScore = min(95, max(50, passRate));
      return AcfAnalysisResult(
        hasData: false,
        correctness: estimatedScore,
        readability: max(50, estimatedScore - 4),
        maintainability: max(50, estimatedScore - 2),
        efficiency: max(50, estimatedScore - 6),
        compositeScore: estimatedScore,
      );
    }

    return const AcfAnalysisResult(
      hasData: false,
      correctness: 50,
      readability: 50,
      maintainability: 50,
      efficiency: 50,
      compositeScore: 50,
    );
  }
}

/// CRA competition readiness metrics derived from timed assessment attempts.
class CraAnalysisResult {
  const CraAnalysisResult({
    required this.hasData,
    required this.accuracy,
    required this.efficiency,
    required this.problemBreadth,
    required this.consistency,
    required this.readinessIndex,
  });

  final bool hasData;
  final int accuracy;
  final int efficiency;
  final int problemBreadth;
  final int consistency;
  final int readinessIndex;

  static CraAnalysisResult fromAttempts(List<Map<String, dynamic>> attempts) {
    final List<int> scores = <int>[];
    final Set<String> uniqueExams = <String>{};

    for (final Map<String, dynamic> a in attempts) {
      final dynamic rawScore = a['score'];
      if (rawScore is num) {
        scores.add(rawScore.round());
        if (a['assessment_id'] != null) {
          uniqueExams.add(a['assessment_id'].toString());
        }
      }
    }

    if (scores.isEmpty) {
      return const CraAnalysisResult(
        hasData: false,
        accuracy: 0,
        efficiency: 0,
        problemBreadth: 0,
        consistency: 0,
        readinessIndex: 0,
      );
    }

    final int avgScore = (scores.reduce((a, b) => a + b) / scores.length).round();
    final int passed = scores.where((s) => s >= 70).length;
    final int accuracy = ((passed / scores.length) * 100).round();
    final int efficiency = avgScore;
    final int problemBreadth = min(100, ((uniqueExams.length / 3) * 100).round());

    double variance = 0.0;
    for (final int s in scores) {
      variance += pow(s - avgScore, 2);
    }
    variance /= scores.length;
    final double stdDev = sqrt(variance);
    final int consistency = max(0, min(100, (100 - stdDev * 1.5).round()));

    final int readinessIndex = (accuracy * 0.3 +
            efficiency * 0.3 +
            problemBreadth * 0.2 +
            consistency * 0.2)
        .round();

    return CraAnalysisResult(
      hasData: true,
      accuracy: accuracy,
      efficiency: efficiency,
      problemBreadth: problemBreadth,
      consistency: consistency,
      readinessIndex: readinessIndex,
    );
  }
}

/// Sleek 1:1 mobile counterpart to Web's LearnerCompetencyProfile.tsx
class CompetencyProfileView extends StatelessWidget {
  const CompetencyProfileView({
    super.key,
    required this.submissions,
    required this.assessmentAttempts,
    required this.isLoading,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    this.onExploreAssessments,
  });

  final List<DashboardSubmission> submissions;
  final List<Map<String, dynamic>> assessmentAttempts;
  final bool isLoading;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderColor;
  final VoidCallback? onExploreAssessments;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildSkeleton(context);
    }

    final AcfAnalysisResult acf = AcfAnalysisResult.fromSubmissions(submissions);
    final CraAnalysisResult cra = CraAnalysisResult.fromAttempts(assessmentAttempts);

    final LearnerTierData practiceTier = LearnerTierData.forScore(acf.compositeScore);
    final LearnerTierData assessmentTier = cra.readinessIndex > 0
        ? LearnerTierData.forScore(cra.readinessIndex)
        : LearnerTierData.forScore(null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // CARD 1: PRACTICE COMPETENCY (ACF)
        _buildCard(
          context: context,
          icon: Icons.menu_book_rounded,
          title: 'Practice Competency',
          scoreText: '${acf.compositeScore}%',
          subtitle: '· Based on ${submissions.length} ${submissions.length == 1 ? "submission" : "submissions"}',
          tier: practiceTier,
          metrics: <_MetricRowData>[
            _MetricRowData(label: 'Correctness & Logic', value: acf.correctness),
            _MetricRowData(label: 'Readability & Style', value: acf.readability),
            _MetricRowData(label: 'Maintainability & Structure', value: acf.maintainability),
            _MetricRowData(label: 'Algorithmic Efficiency', value: acf.efficiency),
          ],
        ),
        const SizedBox(height: 16.0),

        // CARD 2: COMPETITION READINESS (CRA)
        _buildCraCard(
          context: context,
          cra: cra,
          tier: assessmentTier,
        ),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String scoreText,
    required String subtitle,
    required LearnerTierData tier,
    required List<_MetricRowData> metrics,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(icon, size: 16.0, color: textSecondary),
                        const SizedBox(width: 6.0),
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          scoreText,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 30.0,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Flexible(
                          child: Text(
                            subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildTierBadge(context, tier, profileType: 'Practice'),
            ],
          ),
          const SizedBox(height: 16.0),

          // Divider
          Divider(height: 1.0, color: borderColor.withValues(alpha: 0.6)),
          const SizedBox(height: 14.0),

          // Metric Progress Bars
          for (final _MetricRowData m in metrics) ...<Widget>[
            _buildMetricBar(label: m.label, value: m.value),
            const SizedBox(height: 11.0),
          ],
        ],
      ),
    );
  }

  Widget _buildCraCard({
    required BuildContext context,
    required CraAnalysisResult cra,
    required LearnerTierData tier,
  }) {
    final bool hasExams = cra.readinessIndex > 0;

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.emoji_events_outlined, size: 16.0, color: textSecondary),
                        const SizedBox(width: 6.0),
                        Text(
                          'Competition Readiness',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    if (hasExams)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            '${cra.readinessIndex}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 30.0,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: Text(
                              '· Based on ${assessmentAttempts.length} ${assessmentAttempts.length == 1 ? "assessment" : "assessments"}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Timed challenges & assessment performance.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              _buildTierBadge(context, tier, profileType: 'Competition'),
            ],
          ),
          const SizedBox(height: 16.0),

          // Divider
          Divider(height: 1.0, color: borderColor.withValues(alpha: 0.6)),
          const SizedBox(height: 14.0),

          // Empty state or Pillar metrics
          if (!hasExams)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        size: 22.0,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      'No assessment attempts yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260.0),
                      child: Text(
                        'Take a timed assessment to measure your First-Pass Accuracy, Speed, Breadth, and Consistency.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.0,
                          color: textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (onExploreAssessments != null) ...<Widget>[
                      const SizedBox(height: 12.0),
                      TextButton.icon(
                        onPressed: onExploreAssessments,
                        icon: const Icon(Icons.arrow_outward_rounded, size: 14.0),
                        label: const Text('Explore Assessments'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else ...<Widget>[
            _buildMetricBar(label: 'First-Pass Accuracy', value: cra.accuracy),
            const SizedBox(height: 11.0),
            _buildMetricBar(label: 'Speed & Runtime Execution', value: cra.efficiency),
            const SizedBox(height: 11.0),
            _buildMetricBar(label: 'Problem Breadth', value: cra.problemBreadth),
            const SizedBox(height: 11.0),
            _buildMetricBar(label: 'Score Consistency', value: cra.consistency),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBar({required String label, required int value}) {
    final double pct = (value / 100.0).clamp(0.0, 1.0);

    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8.0),
        SizedBox(
          width: 38.0,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999.0),
            child: SizedBox(
              height: 5.5,
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  value >= 70
                      ? AppColors.primary
                      : (value >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTierBadge(BuildContext context, LearnerTierData tier, {required String profileType}) {
    return GestureDetector(
      onTap: () => _showTierBenchmarksSheet(context, tier, profileType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: tier.badgeBg,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: tier.badgeBorder, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              tier.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.0,
                fontWeight: FontWeight.w700,
                color: tier.badgeColor,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.info_outline_rounded,
              size: 11.0,
              color: tier.badgeColor.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  void _showTierBenchmarksSheet(BuildContext context, LearnerTierData currentTier, String profileType) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Handle bar
                Center(
                  child: Container(
                    width: 36.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999.0),
                    ),
                  ),
                ),
                const SizedBox(height: 18.0),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Competency Benchmarks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17.0,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20.0, color: textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),

                // List of tiers
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: LearnerTierData.allTiers.length,
                    separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 10.0),
                    itemBuilder: (BuildContext _, int index) {
                      final LearnerTierData t = LearnerTierData.allTiers[index];
                      final bool isCurrent = t.label == currentTier.label;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? t.badgeBg.withValues(alpha: 0.25)
                              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: isCurrent ? t.badgeColor : borderColor,
                            width: isCurrent ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
                              decoration: BoxDecoration(
                                color: t.badgeBg,
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(color: t.badgeBorder, width: 0.8),
                              ),
                              child: Text(
                                t.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  color: t.badgeColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              t.range,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isCurrent ? t.badgeColor : textPrimary,
                              ),
                            ),
                            if (isCurrent) ...<Widget>[
                              const SizedBox(width: 8.0),
                              Icon(Icons.check_circle_rounded, size: 15.0, color: t.badgeColor),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16.0),

                // Formula context note
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    'Composite scores are calculated from Correctness (24.8%), Readability (24.5%), Maintainability (25.2%), and Efficiency (25.5%).',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.0,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < 2; i++) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(18.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Container(
                      width: 120.0,
                      height: 16.0,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                    Container(
                      width: 80.0,
                      height: 16.0,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),
                Container(
                  width: 80.0,
                  height: 28.0,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
                const SizedBox(height: 18.0),
                Divider(height: 1.0, color: borderColor),
                const SizedBox(height: 14.0),
                for (int j = 0; j < 4; j++) ...<Widget>[
                  Container(
                    width: double.infinity,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (i == 0) const SizedBox(height: 16.0),
        ],
      ],
    );
  }
}
