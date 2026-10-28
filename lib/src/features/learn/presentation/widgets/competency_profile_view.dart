import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../domain/learn_dashboard_data.dart';

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
        // CARD 1: PROGRAMMING COMPETENCY (ACF)
        _buildCard(
          context: context,
          icon: Icons.menu_book_rounded,
          title: 'Programming Competency',
          scoreText: '${acf.compositeScore}%',
          subtitle: '· Based on ${submissions.length} ${submissions.length == 1 ? "submission" : "submissions"}',
          tier: practiceTier,
          acf: acf,
          scoreValue: acf.compositeScore,
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

  Widget _buildPipMeter({required int? value}) {
    final bool isUncalibrated = value == null;
    final int safeValue = isUncalibrated ? 0 : value.clamp(0, 100);
    final int activeCount = (isUncalibrated || safeValue == 0)
        ? 0
        : (safeValue / 10).round().clamp(1, 10);

    Color activeColor;
    if (safeValue >= 80) {
      activeColor = const Color(0xFF34D399);
    } else if (safeValue >= 70) {
      activeColor = const Color(0xFF38BDF8);
    } else if (safeValue >= 50) {
      activeColor = const Color(0xFFFBBF24);
    } else {
      activeColor = const Color(0xFFFB7185);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(10, (int index) {
        final bool isActive = !isUncalibrated && index < activeCount;
        return Container(
          margin: EdgeInsets.only(right: index < 9 ? 2.5 : 0.0),
          width: 6.5,
          height: 8.5,
          decoration: BoxDecoration(
            color: isUncalibrated
                ? Colors.transparent
                : isActive
                    ? activeColor
                    : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(2.0),
            border: Border.all(
              color: isUncalibrated
                  ? borderColor.withValues(alpha: 0.7)
                  : isActive
                      ? activeColor.withValues(alpha: 0.8)
                      : borderColor.withValues(alpha: 0.45),
              width: 0.8,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMiniRadialGauge({required int? value, double size = 42.0}) {
    final bool isUncalibrated = value == null;
    final double progress = isUncalibrated ? 0.0 : (value.clamp(0, 100) / 100.0);
    Color progressColor = const Color(0xFF34D399);
    if (!isUncalibrated) {
      if (value >= 80) {
        progressColor = const Color(0xFF34D399);
      } else if (value >= 70) {
        progressColor = const Color(0xFF38BDF8);
      } else if (value >= 50) {
        progressColor = const Color(0xFFFBBF24);
      } else {
        progressColor = const Color(0xFFFB7185);
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: isUncalibrated ? 0.0 : progress,
        strokeWidth: 3.5,
        strokeCap: StrokeCap.round,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        valueColor: AlwaysStoppedAnimation<Color>(
          isUncalibrated ? textSecondary.withValues(alpha: 0.25) : progressColor,
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String scoreText,
    required String subtitle,
    required LearnerTierData tier,
    required AcfAnalysisResult acf,
    required int scoreValue,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 28.0,
                    height: 28.0,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                    ),
                    child: Icon(icon, size: 15.0, color: textSecondary),
                  ),
                  const SizedBox(width: 8.0),
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
              _buildTierBadge(context, tier, profileType: 'Practice'),
            ],
          ),
          const SizedBox(height: 14.0),

          // Hero Score Row with Mini Radial Gauge
          Row(
            children: <Widget>[
              _buildMiniRadialGauge(value: scoreValue),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      scoreText,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 28.0,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Horizontal Tier Spectrum Rail
          _buildTierSpectrumRail(
            value: scoreValue,
            onTap: () => _showTierBenchmarksSheet(context, tier, 'Practice'),
          ),
          const SizedBox(height: 16.0),

          // 2x2 Partitioned Bento Quadrant Grid
          _buildBentoGrid(
            q1: _buildBentoQuadrant(
              icon: Icons.check_circle_rounded,
              label: 'Correctness',
              sublabel: 'Edge cases & functional specs',
              value: acf.correctness,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
            q2: _buildBentoQuadrant(
              icon: Icons.visibility_rounded,
              label: 'Readability',
              sublabel: 'Idiomatic layout & naming',
              value: acf.readability,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
            q3: _buildBentoQuadrant(
              icon: Icons.build_rounded,
              label: 'Maintainability',
              sublabel: 'Modular architecture & logic',
              value: acf.maintainability,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
            q4: _buildBentoQuadrant(
              icon: Icons.bolt_rounded,
              label: 'Efficiency',
              sublabel: 'Optimal runtime & memory',
              value: acf.efficiency,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: 14.0),
          Divider(height: 1.0, color: borderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 10.0),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Derived from automated reviews',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.0,
                  color: textSecondary,
                ),
              ),
              Text(
                'ACF Evaluation',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.0,
                  color: textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 28.0,
                    height: 28.0,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                    ),
                    child: Icon(Icons.emoji_events_outlined, size: 15.0, color: textSecondary),
                  ),
                  const SizedBox(width: 8.0),
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
              _buildTierBadge(context, tier, profileType: 'Competition'),
            ],
          ),
          const SizedBox(height: 14.0),

          // Hero Score Row with Mini Radial Gauge
          Row(
            children: <Widget>[
              _buildMiniRadialGauge(value: hasExams ? cra.readinessIndex : null),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hasExams ? '${cra.readinessIndex}%' : '--%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 28.0,
                        fontWeight: FontWeight.w800,
                        color: hasExams ? textPrimary : textSecondary.withValues(alpha: 0.5),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      hasExams
                          ? '· Based on ${assessmentAttempts.length} ${assessmentAttempts.length == 1 ? "assessment" : "assessments"}'
                          : 'Complete a timed challenge to calibrate',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Horizontal Tier Spectrum Rail
          _buildTierSpectrumRail(
            value: hasExams ? cra.readinessIndex : null,
            onTap: () => _showTierBenchmarksSheet(context, tier, 'Competition'),
          ),
          const SizedBox(height: 16.0),

          // 2x2 Partitioned Bento Quadrant Grid (Always visible for exact 1:1 symmetry!)
          _buildBentoGrid(
            q1: _buildBentoQuadrant(
              icon: Icons.track_changes_rounded,
              label: 'Accuracy',
              sublabel: 'Passing rate in timed runs',
              value: hasExams ? cra.accuracy : null,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
            q2: _buildBentoQuadrant(
              icon: Icons.speed_rounded,
              label: 'Efficiency',
              sublabel: 'Average pacing score',
              value: hasExams ? cra.efficiency : null,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
            q3: _buildBentoQuadrant(
              icon: Icons.explore_rounded,
              label: 'Problem Breadth',
              sublabel: 'Multi-domain problem variety',
              value: hasExams ? cra.problemBreadth : null,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
            q4: _buildBentoQuadrant(
              icon: Icons.trending_up_rounded,
              label: 'Consistency',
              sublabel: 'Low variance across tests',
              value: hasExams ? cra.consistency : null,
              iconColor: textSecondary.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: 14.0),
          Divider(height: 1.0, color: borderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 10.0),

          // Footer with CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                hasExams ? 'CRA Standard Benchmark' : 'Awaiting calibration',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.0,
                  color: textSecondary,
                ),
              ),
              if (onExploreAssessments != null)
                GestureDetector(
                  onTap: onExploreAssessments,
                  child: Row(
                    children: <Widget>[
                      Text(
                        hasExams ? 'New Challenge' : 'Explore Challenges',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 3.0),
                      const Icon(Icons.arrow_outward_rounded, size: 13.0, color: AppColors.primary),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierSpectrumRail({required int? value, required VoidCallback onTap}) {
    final bool isUncalibrated = value == null;
    final double safeValue = isUncalibrated ? 0.0 : value.clamp(0, 100).toDouble();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: <Widget>[
          // Segmented Bar
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double totalWidth = constraints.maxWidth;
              final double indicatorLeft = (safeValue / 100.0) * totalWidth;

              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    height: 7.0,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999.0),
                      border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 50,
                          child: Container(
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                          ),
                        ),
                        Container(width: 1.0, color: borderColor.withValues(alpha: 0.5)),
                        Expanded(
                          flex: 20,
                          child: Container(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          ),
                        ),
                        Container(width: 1.0, color: borderColor.withValues(alpha: 0.5)),
                        Expanded(
                          flex: 15,
                          child: Container(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          ),
                        ),
                        Container(width: 1.0, color: borderColor.withValues(alpha: 0.5)),
                        Expanded(
                          flex: 15,
                          child: Container(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isUncalibrated)
                    Positioned(
                      left: (indicatorLeft - 4.0).clamp(0.0, totalWidth - 8.0),
                      top: 0.0,
                      bottom: 0.0,
                      child: Container(
                        width: 8.0,
                        decoration: BoxDecoration(
                          color: textPrimary,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: textPrimary.withValues(alpha: 0.5),
                              blurRadius: 4.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 4.0),
          // Benchmark Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '0% Beginner',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.0,
                  fontWeight: safeValue < 50 && !isUncalibrated ? FontWeight.w700 : FontWeight.w500,
                  color: safeValue < 50 && !isUncalibrated ? const Color(0xFFF43F5E) : textSecondary.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '50%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.0,
                  fontWeight: safeValue >= 50 && safeValue < 70 && !isUncalibrated ? FontWeight.w700 : FontWeight.w500,
                  color: safeValue >= 50 && safeValue < 70 && !isUncalibrated ? const Color(0xFFF59E0B) : textSecondary.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '70%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.0,
                  fontWeight: safeValue >= 70 && safeValue < 85 && !isUncalibrated ? FontWeight.w700 : FontWeight.w500,
                  color: safeValue >= 70 && safeValue < 85 && !isUncalibrated ? const Color(0xFF0EA5E9) : textSecondary.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '85%+ Expert',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.0,
                  fontWeight: safeValue >= 85 && !isUncalibrated ? FontWeight.w700 : FontWeight.w500,
                  color: safeValue >= 85 && !isUncalibrated ? const Color(0xFF10B981) : textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoQuadrant({
    required IconData icon,
    required String label,
    required String sublabel,
    required int? value,
    required Color iconColor,
  }) {
    final bool isUncalibrated = value == null;
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1F).withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Top row: Icon + Label + Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 12.0, color: iconColor),
                  const SizedBox(width: 4.0),
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                !isUncalibrated ? '$value%' : '—',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w800,
                  color: !isUncalibrated ? textPrimary : textSecondary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          // Diagnostic caption
          Text(
            sublabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: textSecondary.withValues(alpha: 0.8),
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6.0),
          // Pip meter
          Align(
            alignment: Alignment.centerRight,
            child: _buildPipMeter(value: value),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid({
    required Widget q1,
    required Widget q2,
    required Widget q3,
    required Widget q4,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
        color: borderColor.withValues(alpha: 0.7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: q1),
                Container(width: 1.0, color: borderColor.withValues(alpha: 0.7)),
                Expanded(child: q2),
              ],
            ),
          ),
          Container(height: 1.0, color: borderColor.withValues(alpha: 0.7)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: q3),
                Container(width: 1.0, color: borderColor.withValues(alpha: 0.7)),
                Expanded(child: q4),
              ],
            ),
          ),
        ],
      ),
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
                const SizedBox(height: 16.0),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      profileType == 'Practice'
                          ? 'Programming Competency Standards'
                          : 'Competition Readiness Standards',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.0,
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
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: LearnerTierData.allTiers.length,
                      separatorBuilder: (BuildContext _, int _) => Divider(height: 1.0, color: borderColor.withValues(alpha: 0.6)),
                      itemBuilder: (BuildContext _, int index) {
                        final LearnerTierData t = LearnerTierData.allTiers[index];
                        final bool isCurrent = t.label == currentTier.label;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : (isDark ? AppColors.darkSurfaceCard : Colors.white),
                            border: isCurrent
                                ? const Border(left: BorderSide(color: AppColors.primary, width: 2.5))
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        t.label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      if (isCurrent) ...<Widget>[
                                        const SizedBox(width: 6.0),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4.0),
                                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 0.8),
                                          ),
                                          child: Text(
                                            'ACTIVE',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    t.range,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                t.description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: textSecondary,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
