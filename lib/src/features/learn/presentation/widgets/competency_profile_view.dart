import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../common_widgets/shimmer_skeleton.dart';
import '../../../../constants/app_colors.dart';
import '../../domain/cra.dart';
import '../../domain/learn_dashboard_data.dart';
import 'growth_chart.dart';

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

  // ── Practice / Programming Competency Benchmarks (1:1 with Web) ──
  static const List<LearnerTierData> practiceTiers = <LearnerTierData>[
    LearnerTierData(
      label: 'Expert',
      badgeColor: Color(0xFF10B981),
      badgeBg: Color(0x1F10B981),
      badgeBorder: Color(0x3310B981),
      range: '85% – 100%',
      description:
          'Production-ready algorithmic mastery, clean architecture, and optimal runtime bounds.',
    ),
    LearnerTierData(
      label: 'Proficient',
      badgeColor: Color(0xFF0EA5E9),
      badgeBg: Color(0x1F0EA5E9),
      badgeBorder: Color(0x330EA5E9),
      range: '70% – 84%',
      description:
          'Strong problem solving with minor opportunities for style, maintainability, or efficiency improvements.',
    ),
    LearnerTierData(
      label: 'Competent',
      badgeColor: Color(0xFFF59E0B),
      badgeBg: Color(0x1FF59E0B),
      badgeBorder: Color(0x33F59E0B),
      range: '50% – 69%',
      description:
          'Working grasp of core problem solving; active review recommended on edge cases and complexity.',
    ),
    LearnerTierData(
      label: 'Beginner',
      badgeColor: Color(0xFFF43F5E),
      badgeBg: Color(0x1FF43F5E),
      badgeBorder: Color(0x33F43F5E),
      range: '0% – 49%',
      description:
          'Initial calibration tier focusing on fundamentals, syntax accuracy, and basic test coverage.',
    ),
  ];

  // ── Competition Readiness Benchmarks (1:1 with Web) ──
  static const List<LearnerTierData> competitionTiers = <LearnerTierData>[
    LearnerTierData(
      label: 'Competition Ready',
      badgeColor: Color(0xFF10B981),
      badgeBg: Color(0x1F10B981),
      badgeBorder: Color(0x3310B981),
      range: '85% – 100%',
      description:
          'Consistently solves timed algorithmic challenges with optimal complexity and steady pacing.',
    ),
    LearnerTierData(
      label: 'Nearly Competition Ready',
      badgeColor: Color(0xFF0EA5E9),
      badgeBg: Color(0x1F0EA5E9),
      badgeBorder: Color(0x330EA5E9),
      range: '70% – 84%',
      description:
          'Solid performance under time constraints; approaching competitive speed and low variance.',
    ),
    LearnerTierData(
      label: 'Developing',
      badgeColor: Color(0xFFF59E0B),
      badgeBg: Color(0x1FF59E0B),
      badgeBorder: Color(0x33F59E0B),
      range: '50% – 69%',
      description:
          'Progressing in timed execution; additional attempts across varied problem archetypes recommended.',
    ),
    LearnerTierData(
      label: 'Beginner',
      badgeColor: Color(0xFFF43F5E),
      badgeBg: Color(0x1FF43F5E),
      badgeBorder: Color(0x33F43F5E),
      range: '0% – 49%',
      description:
          'Initial calibration baseline; building speed and stamina through structured practice challenges.',
    ),
  ];

  static const LearnerTierData uncalibrated = LearnerTierData(
    label: 'Uncalibrated',
    badgeColor: Color(0xFF94A3B8),
    badgeBg: Color(0x1F94A3B8),
    badgeBorder: Color(0x3394A3B8),
    range: 'No data',
    description:
        'Complete timed challenges or practice modules to establish your benchmark calibration.',
  );

  static List<LearnerTierData> get allTiers => competitionTiers;

  static LearnerTierData forPracticeScore(int? score) {
    if (score == null) return uncalibrated;
    if (score >= 85) return practiceTiers[0];
    if (score >= 70) return practiceTiers[1];
    if (score >= 50) return practiceTiers[2];
    return practiceTiers[3];
  }

  static LearnerTierData forCompetitionScore(int? score) {
    if (score == null || score == 0) return uncalibrated;
    if (score >= 85) return competitionTiers[0];
    if (score >= 70) return competitionTiers[1];
    if (score >= 50) return competitionTiers[2];
    return competitionTiers[3];
  }

  static LearnerTierData forScore(int? score) => forCompetitionScore(score);
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

  static AcfAnalysisResult fromSubmissions(
    List<DashboardSubmission> submissions,
  ) {
    double corrSum = 0;
    double readSum = 0;
    double maintSum = 0;
    double effSum = 0;
    int count = 0;

    for (final DashboardSubmission s in submissions) {
      final Map<String, dynamic>? f = s.findings;
      if (f != null) {
        final dynamic c = f['correctness'] is Map
            ? (f['correctness'] as Map)['score']
            : null;
        final dynamic r = f['readability'] is Map
            ? (f['readability'] as Map)['score']
            : null;
        final dynamic m = f['maintainability'] is Map
            ? (f['maintainability'] as Map)['score']
            : null;
        final dynamic e = f['efficiency'] is Map
            ? (f['efficiency'] as Map)['score']
            : null;

        if (c is num && r is num && m is num && e is num) {
          corrSum += c.toDouble();
          readSum += r.toDouble();
          maintSum += m.toDouble();
          effSum += e.toDouble();
          count++;
        }
      }
    }

    if (count > 0) {
      final int correctness = (corrSum / count).round();
      final int readability = (readSum / count).round();
      final int maintainability = (maintSum / count).round();
      final int efficiency = (effSum / count).round();
      final int composite =
          (correctness * 0.2484 +
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

    // Nothing has been reviewed yet: no numbers are invented.
    return const AcfAnalysisResult(
      hasData: false,
      correctness: 0,
      readability: 0,
      maintainability: 0,
      efficiency: 0,
      compositeScore: 0,
    );
  }
}

/// The choices above the readiness chart.
const List<ChartView> readinessViews = <ChartView>[
  ChartView('overall', 'Overall'),
  ChartView('accuracy', 'Accuracy'),
  ChartView('efficiency', 'Efficiency'),
  ChartView('problemBreadth', 'Problem breadth'),
  ChartView('consistency', 'Consistency'),
];

/// The overall readiness line starts once Consistency can be measured.
const int _readinessMinAssessments = craConsistencyMinAssessments;

/// The readiness figures after each timed assessment attempt, oldest first.
/// Uses the same calculation as the web (see cra.dart), so both show the same line.
List<ChartPoint> readinessChartPoints(List<CraAttempt> attempts) {
  final List<CraGrowthPoint> growth = computeCraGrowth(attempts);
  return <ChartPoint>[
    for (int i = 0; i < growth.length; i++)
      ChartPoint(
        index: i + 1,
        date: growth[i].timestamp,
        title: 'Timed assessment attempt',
        noun: 'Assessment',
        running: <String, int>{
          for (final MapEntry<String, int?> e in growth[i].criteria.entries)
            if (e.value != null) e.key: e.value!,
          if (growth[i].readinessIndex != null)
            'overall': growth[i].readinessIndex!,
        },
      ),
  ];
}

/// Mobile counterpart to the web Competency tab: one switch, one measure at a time.
class CompetencyProfileView extends StatefulWidget {
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
    this.onOpenSubmission,
  });

  final ValueChanged<DashboardSubmission>? onOpenSubmission;
  final List<DashboardSubmission> submissions;
  final List<Map<String, dynamic>> assessmentAttempts;
  final bool isLoading;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderColor;
  final VoidCallback? onExploreAssessments;

  @override
  State<CompetencyProfileView> createState() => _CompetencyProfileViewState();
}

class _Metric {
  const _Metric(this.label, this.hint, this.value, {this.series, this.view});
  final String label;
  final String hint;
  final int? value;

  /// Running average after each reviewed submission, oldest first.
  final List<int>? series;

  /// Which growth-chart criterion this row controls.
  final String? view;
}

class _CompetencyProfileViewState extends State<CompetencyProfileView> {
  bool _showReadiness = false;
  String _growthView = GrowthView.overall.name;
  String _readinessView = 'overall';

  Color get _text => widget.textPrimary;
  Color get _muted => widget.textSecondary;

  Widget _switch(String label, int? score, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48.0),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _text : _muted,
                      decoration: selected ? TextDecoration.underline : null,
                      decorationColor: _text,
                    ),
                  ),
                  TextSpan(
                    text: score == null ? '  —' : '  $score%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: selected ? _text : _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricRow(_Metric m) {
    final int? v = m.value;
    final List<int>? series = m.series;
    final String? view = m.view;

    // Criteria with history show a trend line and pick that criterion in the chart below.
    if (series != null && view != null) {
      final bool selected =
          (_showReadiness ? _readinessView : _growthView) == view;
      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: widget.borderColor)),
        ),
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_showReadiness) {
                  _readinessView = view;
                } else {
                  _growthView = view;
                }
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            m.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _text,
                              decoration: selected
                                  ? TextDecoration.underline
                                  : null,
                              decorationColor: _text,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            m.hint,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    GrowthSparkline(values: series, color: _muted),
                    const SizedBox(width: 12.0),
                    SizedBox(
                      width: 44.0,
                      child: Text(
                        v == null ? '—' : '$v%',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: widget.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      m.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      m.hint,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Text(
                v == null ? '—' : '$v%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.0),
            child: SizedBox(
              height: 4.0,
              child: LinearProgressIndicator(
                // Exactly empty with no data or 0% (AGENTS.md 2.3).
                value: v == null ? 0.0 : (v / 100.0).clamp(0.0, 1.0),
                backgroundColor: widget.isDark
                    ? AppColors.darkSurfaceHighest
                    : AppColors.lightBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiers(List<LearnerTierData> tiers, String? current) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'How tiers work',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: _muted,
            decoration: TextDecoration.underline,
            decorationColor: _muted,
          ),
        ),
        children: <Widget>[
          for (final LearnerTierData t in tiers)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: widget.borderColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          t.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: t.label == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: t.label == current ? _text : _muted,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          t.description,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            color: _muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    t.range,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _measure({
    required int? score,
    required String? tierLabel,
    required String summary,
    required List<_Metric> metrics,
    required List<LearnerTierData> tiers,
    String? emptyLabel,
    VoidCallback? onEmpty,
  }) {
    final List<_Metric> scored = metrics
        .where((_Metric m) => m.value != null)
        .toList();
    _Metric? weakest;
    if (score != null && scored.isNotEmpty) {
      weakest = scored.reduce(
        (_Metric a, _Metric b) => a.value! <= b.value! ? a : b,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          tierLabel ?? 'Not rated yet',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.0, color: _muted),
        ),
        const SizedBox(height: 4.0),
        Text(
          score == null ? '—' : '$score%',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 44.0,
            fontWeight: FontWeight.w600,
            color: score == null ? _muted : _text,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          summary,
          style: GoogleFonts.plusJakartaSans(fontSize: 13.0, color: _muted),
        ),
        if (score == null && onEmpty != null && emptyLabel != null)
          InkWell(
            onTap: onEmpty,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    emptyLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Icon(Icons.arrow_forward_rounded, size: 14.0, color: _text),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20.0),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: widget.borderColor)),
          ),
          child: Column(children: metrics.map(_metricRow).toList()),
        ),
        if (weakest != null) ...<Widget>[
          const SizedBox(height: 14.0),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: 'Focus next: ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: _muted,
                  ),
                ),
                TextSpan(
                  text: weakest.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                TextSpan(
                  text: ' is your lowest at ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: _muted,
                  ),
                ),
                TextSpan(
                  text: '${weakest.value}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13.0,
                    color: _text,
                  ),
                ),
                TextSpan(
                  text: '.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6.0),
        _tiers(tiers, tierLabel),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildSkeleton(context);
    }

    final AcfAnalysisResult acf = AcfAnalysisResult.fromSubmissions(
      widget.submissions,
    );
    final List<CraAttempt> craAttempts = craAttemptsFromRows(
      widget.assessmentAttempts,
    );
    final CraAnalysis cra = computeCra(craAttempts);

    final int? practiceScore = acf.hasData ? acf.compositeScore : null;
    final int? readinessScore = cra.readinessIndex;
    final List<GrowthPoint> growth = computeGrowth(widget.submissions);
    final List<ChartPoint> readinessGrowth = readinessChartPoints(craAttempts);
    List<int> seriesOf(String key) => <int>[
      for (final ChartPoint p in readinessGrowth)
        if (p.running[key] != null) p.running[key]!,
    ];
    final int reviewed = widget.submissions
        .where((DashboardSubmission s) => s.findings != null)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 24.0,
          children: <Widget>[
            _switch(
              'Programming competency',
              practiceScore,
              !_showReadiness,
              () {
                setState(() => _showReadiness = false);
              },
            ),
            _switch(
              'Competition readiness',
              readinessScore,
              _showReadiness,
              () {
                setState(() => _showReadiness = true);
              },
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        if (!_showReadiness)
          _measure(
            score: practiceScore,
            tierLabel: practiceScore == null
                ? null
                : LearnerTierData.forPracticeScore(practiceScore).label,
            summary: practiceScore == null
                ? 'Submit code to get your first review.'
                : 'From $reviewed reviewed ${reviewed == 1 ? "submission" : "submissions"}',
            metrics: <_Metric>[
              _Metric(
                'Correctness',
                'Whether your code does what the problem asks, including unusual inputs and edge cases.',
                acf.hasData ? acf.correctness : null,
                series: <int>[
                  for (final GrowthPoint p in growth)
                    p.running[GrowthView.correctness]!,
                ],
                view: GrowthView.correctness.name,
              ),
              _Metric(
                'Readability',
                'How easy your code is to read: clear names, consistent layout and a sensible structure.',
                acf.hasData ? acf.readability : null,
                series: <int>[
                  for (final GrowthPoint p in growth)
                    p.running[GrowthView.readability]!,
                ],
                view: GrowthView.readability.name,
              ),
              _Metric(
                'Maintainability',
                'How easy your code would be to change later: small focused pieces, low complexity and little repetition.',
                acf.hasData ? acf.maintainability : null,
                series: <int>[
                  for (final GrowthPoint p in growth)
                    p.running[GrowthView.maintainability]!,
                ],
                view: GrowthView.maintainability.name,
              ),
              _Metric(
                'Efficiency',
                'How sensibly your code uses time and memory for the problem.',
                acf.hasData ? acf.efficiency : null,
                series: <int>[
                  for (final GrowthPoint p in growth)
                    p.running[GrowthView.efficiency]!,
                ],
                view: GrowthView.efficiency.name,
              ),
            ],
            tiers: LearnerTierData.practiceTiers,
          ),
        if (!_showReadiness) ...<Widget>[
          const SizedBox(height: 20.0),
          Container(
            padding: const EdgeInsets.only(top: 20.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: widget.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Growth over time',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4.0),
                GrowthChart(
                  points: growthChartPoints(growth, widget.onOpenSubmission),
                  views: growthViews,
                  view: _growthView,
                  onViewChanged: (String v) => setState(() => _growthView = v),
                  textPrimary: _text,
                  textSecondary: _muted,
                  borderColor: widget.borderColor,
                  backgroundColor: widget.isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground,
                  ownLabel: 'This submission',
                  emptyNone: growth.isEmpty
                      ? 'Your growth chart appears once a submission has been reviewed.'
                      : 'Your growth chart appears after your second reviewed submission.',
                  footnote:
                      'Each point is your average after that submission. Tap the chart to pick one, then open it. Only submissions with an AI code review are included.',
                ),
              ],
            ),
          ),
        ],
        if (_showReadiness)
          _measure(
            score: readinessScore,
            tierLabel: readinessScore == null
                ? null
                : LearnerTierData.forCompetitionScore(readinessScore).label,
            summary: readinessScore == null
                ? 'Complete a timed assessment to get rated.'
                : 'From ${cra.assessmentCount} timed ${cra.assessmentCount == 1 ? "assessment" : "assessments"}${cra.pendingCount > 0 ? ", ${cra.pendingCount} awaiting AI review" : ""}',
            metrics: <_Metric>[
              _Metric(
                'Accuracy',
                'How many of the problems you attempt you actually solve. A problem counts as solved when it passes every test and the AI review rates its correctness at 80% or higher.',
                cra.accuracy,
                series: seriesOf('accuracy'),
                view: 'accuracy',
              ),
              _Metric(
                'Efficiency',
                'How well your solutions use time and memory, as rated by the AI review. Only problems you solved are rated.',
                cra.efficiency,
                series: seriesOf('efficiency'),
                view: 'efficiency',
              ),
              _Metric(
                'Problem Breadth',
                'How many different programming concepts you have shown you can use, out of the concepts the problems you have taken cover. A concept counts once you solve a problem that needs it.',
                cra.problemBreadth,
                series: seriesOf('problemBreadth'),
                view: 'problemBreadth',
              ),
              _Metric(
                'Consistency',
                'How steady your results are from one assessment to the next. Steady scores rate higher than big swings between good and bad runs. It tracks steadiness, not improvement.',
                cra.consistency,
                series: seriesOf('consistency'),
                view: 'consistency',
              ),
            ],
            tiers: LearnerTierData.competitionTiers,
            emptyLabel: 'Explore assessments',
            onEmpty: widget.onExploreAssessments,
          ),
        if (_showReadiness) ...<Widget>[
          const SizedBox(height: 20.0),
          Container(
            padding: const EdgeInsets.only(top: 20.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: widget.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Growth over time',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4.0),
                GrowthChart(
                  points: readinessGrowth,
                  views: readinessViews,
                  view: _readinessView,
                  onViewChanged: (String v) =>
                      setState(() => _readinessView = v),
                  textPrimary: _text,
                  textSecondary: _muted,
                  borderColor: widget.borderColor,
                  backgroundColor: widget.isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground,
                  emptyNone:
                      'The overall readiness chart appears after $_readinessMinAssessments timed assessments, when all its measures can first be worked out.',
                  emptyFor: (String id) => switch (id) {
                    'overall' => null,
                    'problemBreadth' =>
                      'Problem breadth needs results from at least two timed assessments.',
                    _ =>
                      'This measure needs results from at least two timed assessments.',
                  },
                  footnote:
                      'Each point is your figure after a timed assessment attempt. Tap the chart to see it. The overall line starts once you have taken $_readinessMinAssessments different assessments.',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return const ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(width: 220.0, height: 20.0, borderRadius: 4.0),
          SizedBox(height: 20.0),
          SkeletonBox(width: 120.0, height: 44.0, borderRadius: 6.0),
          SizedBox(height: 20.0),
          SkeletonBox(width: double.infinity, height: 56.0, borderRadius: 6.0),
          SizedBox(height: 12.0),
          SkeletonBox(width: double.infinity, height: 56.0, borderRadius: 6.0),
          SizedBox(height: 12.0),
          SkeletonBox(width: double.infinity, height: 56.0, borderRadius: 6.0),
        ],
      ),
    );
  }
}
