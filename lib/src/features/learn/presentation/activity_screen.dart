import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/filter_tab_bar.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../common_widgets/language_icon.dart';
import '../../../common_widgets/select_filter.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/assessment_repository.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_assessment_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/assessment_model.dart';
import '../domain/history_items.dart';
import '../domain/learn_dashboard_data.dart';
import '../domain/pathway_model.dart';
import 'widgets/assessment_preview_sheet.dart';
import 'widgets/competency_profile_view.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.showBackButton = false,
    this.pathwayRepository = const SupabasePathwayRepository(),
    this.assessmentRepository = const SupabaseAssessmentRepository(),
  });

  final bool showBackButton;
  final PathwayRepository pathwayRepository;
  final AssessmentRepository assessmentRepository;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _activeSegment =
      1; // 0 = Active Learning, 1 = History, 2 = Competency Profile
  List<PathwayModel> _enrolledModules = <PathwayModel>[];
  List<AssessmentModel> _activeAssessments = <AssessmentModel>[];
  String _activeLearningFilter = 'all'; // 'all', 'in-progress', 'completed'
  String _activeLearningSearch = '';
  final TextEditingController _activeLearningSearchController =
      TextEditingController();

  List<DashboardSubmission> _submissions = <DashboardSubmission>[];
  List<Map<String, dynamic>> _assessmentAttempts = <Map<String, dynamic>>[];
  bool _isLoading = true;

  String _statusFilter = 'all'; // 'all', 'passed', 'needs-review', 'pending'
  String _langFilter = 'all';
  final Set<String> _expandedAttempts = <String>{};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    if (SupabasePathwayRepository.cachedData != null) {
      if (SupabasePathwayRepository.cachedData!.submissions.isNotEmpty) {
        _submissions = SupabasePathwayRepository.cachedData!.submissions;
      }
      if (SupabasePathwayRepository.cachedData!.enrolledPathways.isNotEmpty) {
        _enrolledModules = SupabasePathwayRepository
            .cachedData!
            .enrolledPathways
            .where((PathwayModel p) => p.completion > 0)
            .toList();
      }
      if (_enrolledModules.isNotEmpty) {
        _activeSegment = 0;
      } else if (_submissions.isNotEmpty) {
        _activeSegment = 1;
      }
      if (_submissions.isNotEmpty || _enrolledModules.isNotEmpty) {
        _isLoading = false;
      }
    }
    _fetchSubmissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _activeLearningSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubmissions({bool force = false}) async {
    if (_submissions.isEmpty && _enrolledModules.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      String userId = '';
      try {
        userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      } catch (_) {
        // Fallback for tests or unauthenticated session
      }

      final LearnDashboardData dashData = await widget.pathwayRepository
          .getLearnDashboardData(userId);
      final List<DashboardSubmission> subs = dashData.submissions.isNotEmpty
          ? dashData.submissions
          : await widget.pathwayRepository.getUserSubmissions(userId);
      final List<PathwayModel> enrolled = dashData.enrolledPathways
          .where(
            (PathwayModel p) =>
                p.completion > 0 ||
                subs.any(
                  (DashboardSubmission s) =>
                      s.moduleId == p.id || s.module == p.title,
                ),
          )
          .toList();

      List<Map<String, dynamic>> attempts = <Map<String, dynamic>>[];
      List<AssessmentModel> publishedAssessments = <AssessmentModel>[];
      if (userId.isNotEmpty) {
        try {
          attempts = await widget.assessmentRepository
              .getUserAssessmentAttempts(userId);
        } catch (_) {
          attempts = <Map<String, dynamic>>[];
        }
        try {
          publishedAssessments = await widget.assessmentRepository
              .getPublishedAssessments(userId);
        } catch (_) {
          publishedAssessments = <AssessmentModel>[];
        }
      }

      // Filter active assessments (only attempted ones appear in active learning desk)
      final List<AssessmentModel> activeAssts = publishedAssessments.where((
        AssessmentModel a,
      ) {
        return attempts.any(
          (Map<String, dynamic> att) => att['assessment_id'] == a.id,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _submissions = subs;
          _enrolledModules = enrolled;
          _activeAssessments = activeAssts;
          _assessmentAttempts = attempts;
          if ((_enrolledModules.isNotEmpty || _activeAssessments.isNotEmpty) &&
              _activeSegment == 1 &&
              _submissions.isEmpty) {
            _activeSegment = 0;
          } else if (_enrolledModules.isEmpty &&
              _activeAssessments.isEmpty &&
              _submissions.isNotEmpty) {
            _activeSegment = 1;
          }
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

  int get _totalActiveCount =>
      _enrolledModules.length + _activeAssessments.length;

  int get _completedModulesCount =>
      _enrolledModules.where((PathwayModel p) => p.completion >= 100).length;

  int get _inProgressModulesCount => _enrolledModules
      .where((PathwayModel p) => p.completion > 0 && p.completion < 100)
      .length;

  int get _inProgressAssessmentsCount =>
      _activeAssessments.where((AssessmentModel a) {
        final Map<String, dynamic>? att = _getAttemptForAssessment(a.id);
        return att != null && att['status'] == 'in_progress';
      }).length;

  int get _completedAssessmentsCount =>
      _activeAssessments.where((AssessmentModel a) {
        final Map<String, dynamic>? att = _getAttemptForAssessment(a.id);
        return att != null &&
            att['score'] != null &&
            (att['score'] as num) >= a.passingScore;
      }).length;

  int get _avgCompletion {
    if (_enrolledModules.isEmpty) return 0;
    final int sum = _enrolledModules.fold<int>(
      0,
      (int acc, PathwayModel p) => acc + p.completion,
    );
    return (sum / _enrolledModules.length).round();
  }

  List<FilterTabItem> get _activeLearningFilterTabs => <FilterTabItem>[
    FilterTabItem(id: 'all', label: 'All Progress', count: _totalActiveCount),
    FilterTabItem(
      id: 'in-progress',
      label: 'In Progress',
      count: _inProgressModulesCount + _inProgressAssessmentsCount,
    ),
    FilterTabItem(
      id: 'completed',
      label: 'Mastered',
      count: _completedModulesCount + _completedAssessmentsCount,
    ),
  ];

  List<PathwayModel> get _filteredEnrolledModules {
    return _enrolledModules.where((PathwayModel p) {
      if (_activeLearningFilter == 'in-progress' &&
          (p.completion <= 0 || p.completion >= 100)) {
        return false;
      }
      if (_activeLearningFilter == 'completed' && p.completion < 100) {
        return false;
      }
      if (_activeLearningSearch.trim().isNotEmpty) {
        final String q = _activeLearningSearch.trim().toLowerCase();
        if (!p.title.toLowerCase().contains(q) &&
            !p.description.toLowerCase().contains(q) &&
            !p.stack.any((String s) => s.toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<AssessmentModel> get _filteredAssessments {
    return _activeAssessments.where((AssessmentModel a) {
      final Map<String, dynamic>? att = _getAttemptForAssessment(a.id);
      final bool isPassed =
          att != null &&
          att['score'] != null &&
          (att['score'] as num) >= a.passingScore;
      final bool isInProgress = att != null && att['status'] == 'in_progress';

      if (_activeLearningFilter == 'completed' && !isPassed) return false;
      if (_activeLearningFilter == 'in-progress' && !isInProgress) return false;
      if (_activeLearningSearch.trim().isNotEmpty) {
        final String q = _activeLearningSearch.trim().toLowerCase();
        if (!a.title.toLowerCase().contains(q) &&
            !a.description.toLowerCase().contains(q) &&
            !a.stack.any((String s) => s.toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Map<String, dynamic>? _getAttemptForAssessment(String assessmentId) {
    for (final Map<String, dynamic> att in _assessmentAttempts) {
      if (att['assessment_id'] == assessmentId) {
        return att;
      }
    }
    return null;
  }

  /// The history as the list shows it: assessment attempts are one entry each.
  List<HistoryItem> get _historyItems =>
      buildHistoryItems(_submissions, _assessmentAttempts);

  int get _passedCount =>
      _historyItems.where((HistoryItem i) => i.status == 'Passed').length;

  int get _needsReviewCount =>
      _historyItems.where((HistoryItem i) => i.status == 'Needs Review').length;

  int get _pendingCount =>
      _historyItems.where((HistoryItem i) => i.status == 'Pending').length;

  int get _streak => DashboardSubmission.computeStreak(_submissions);

  int get _passRate {
    final int total = _historyItems.length;
    if (total == 0) return 0;
    return ((_passedCount / total) * 100).round();
  }

  List<FilterTabItem> get _filterTabs => <FilterTabItem>[
    FilterTabItem(id: 'all', label: 'All', count: _historyItems.length),
    FilterTabItem(id: 'passed', label: 'Passed', count: _passedCount),
    FilterTabItem(
      id: 'needs-review',
      label: 'Needs Review',
      count: _needsReviewCount,
    ),
    if (_pendingCount > 0)
      FilterTabItem(id: 'pending', label: 'Pending', count: _pendingCount),
  ];

  Map<String, int> get _languageCounts {
    final Map<String, int> counts = <String, int>{};
    for (final HistoryItem i in _historyItems) {
      final String lang = i.language.toLowerCase();
      if (lang.isEmpty) continue;
      counts[lang] = (counts[lang] ?? 0) + 1;
    }
    return counts;
  }

  List<HistoryItem> get _filteredHistory {
    return _historyItems.where((HistoryItem i) {
      if (_statusFilter == 'passed' && i.status != 'Passed') return false;
      if (_statusFilter == 'needs-review' && i.status != 'Needs Review') {
        return false;
      }
      if (_statusFilter == 'pending' && i.status != 'Pending') return false;
      if (_langFilter != 'all' &&
          i.language.toLowerCase() != _langFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final String q = _searchQuery.trim().toLowerCase();
        final bool inTitle = i.title.toLowerCase().contains(q);
        final bool inLang = i.language.toLowerCase().contains(q);
        final bool inParent = switch (i) {
          SubmissionHistoryItem(:final DashboardSubmission sub) =>
            sub.module.toLowerCase().contains(q),
          AssessmentHistoryItem() => 'assessment'.contains(q),
        };
        if (!inTitle && !inLang && !inParent) return false;
      }
      return true;
    }).toList();
  }

  int get _totalPages =>
      max(1, (_filteredHistory.length / _itemsPerPage).ceil());
  int get _startIndex => (_currentPage - 1) * _itemsPerPage;
  int get _endIndex =>
      min(_startIndex + _itemsPerPage, _filteredHistory.length);

  List<HistoryItem> get _visibleHistory {
    if (_filteredHistory.isEmpty) return const <HistoryItem>[];
    return _filteredHistory.sublist(
      _startIndex,
      min(_endIndex, _filteredHistory.length),
    );
  }

  /// Plain text with an icon. The meaning is in the word and the icon, not the colour.
  Widget _buildStatusBadge(String status, Color textSecondary) {
    final String s = DashboardSubmission.normalizeStatus(status);
    final IconData icon = s == 'Passed'
        ? Icons.check_rounded
        : s == 'Pending'
        ? Icons.hourglass_empty_rounded
        : Icons.access_time_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15.0, color: textSecondary),
        const SizedBox(width: 4.0),
        Text(
          s,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _fetchSubmissions(force: true),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 104.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Optional Back button
                if (widget.showBackButton) ...<Widget>[
                  IconButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/learn');
                      }
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(
                      minWidth: 36.0,
                      minHeight: 36.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                ],

                // Screen Title & Subtitle (Cross-platform parity with Web /learn/activity)
                Text(
                  'My Activity',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22.0,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  'Submissions history, code reviews, and accuracy logs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Segmented Switcher (Active Learning vs History vs Competency Profile)
                _buildSegmentSwitcher(
                  isDark: isDark,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 16.0),

                if (_activeSegment == 0)
                  _buildActiveLearningDesk(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  )
                else if (_activeSegment == 1)
                  _buildSubmissionsLog(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  )
                else
                  CompetencyProfileView(
                    submissions: _submissions,
                    assessmentAttempts: _assessmentAttempts,
                    isLoading: _isLoading,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                    onExploreAssessments: () =>
                        context.push('/learn/assessments'),
                    onOpenSubmission: _openSubmissionReview,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentSwitcher({
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final List<(String, int?)> items = <(String, int?)>[
      ('Active', _totalActiveCount),
      ('History', _historyItems.length),
      ('Competency', null),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 24.0),
            Semantics(
              button: true,
              selected: _activeSegment == i,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _activeSegment = i;
                  });
                },
                child: Container(
                  height: 48.0,
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _activeSegment == i
                            ? textPrimary
                            : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        items[i].$1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.0,
                          fontWeight: _activeSegment == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _activeSegment == i
                              ? textPrimary
                              : textSecondary,
                        ),
                      ),
                      if (items[i].$2 != null) ...<Widget>[
                        const SizedBox(width: 6.0),
                        Text(
                          '${items[i].$2}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveLearningDesk({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final List<PathwayModel> modules = _filteredEnrolledModules;
    final List<AssessmentModel> assessments = _filteredAssessments;
    final bool isEmpty = modules.isEmpty && assessments.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Hollow Metrics Overview Row
        Row(
          children: <Widget>[
            Expanded(
              child: _buildMetricBox(
                label: 'Active',
                value: '$_totalActiveCount',
                icon: Icons.menu_book_rounded,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMetricBox(
                label: 'Streak',
                value: '${_streak}d',
                icon: Icons.local_fire_department_rounded,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMetricBox(
                label: 'Avg Progress',
                value: '$_avgCompletion%',
                icon: Icons.insights_rounded,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18.0),

        // Search Input & Progress Filter Dropdown
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 44.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _activeLearningSearchController,
                  onChanged: (String val) {
                    setState(() {
                      _activeLearningSearch = val;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 9.0,
                    ),
                    hintText: 'Search active modules & assessments...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 17.0,
                      color: textSecondary,
                    ),
                    suffixIcon: _activeLearningSearch.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 15.0,
                              color: textSecondary,
                            ),
                            onPressed: () {
                              _activeLearningSearchController.clear();
                              setState(() {
                                _activeLearningSearch = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            _buildActiveLearningProgressDropdown(
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 16.0),

        // Active Learning Desk: Hollow Divided List | Empty State | Skeleton
        if (_isLoading &&
            _enrolledModules.isEmpty &&
            _activeAssessments.isEmpty)
          _buildLoadingSkeleton(isDark)
        else if (isEmpty)
          _buildEmptyActiveLearningState(
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          )
        else
          // Hollow Divided Table/List (Web 1:1 Parity)
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: borderColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Column(
              children: <Widget>[
                // 1. Module Rows
                ...modules.asMap().entries.map((
                  MapEntry<int, PathwayModel> entry,
                ) {
                  final int index = entry.key;
                  final PathwayModel mod = entry.value;
                  return Column(
                    children: <Widget>[
                      if (index > 0)
                        Divider(
                          height: 1.0,
                          thickness: 1.0,
                          color: borderColor.withValues(alpha: 0.35),
                        ),
                      _buildHollowModuleRow(
                        module: mod,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                    ],
                  );
                }),

                // 2. Assessment Rows
                ...assessments.asMap().entries.map((
                  MapEntry<int, AssessmentModel> entry,
                ) {
                  final int index = entry.key;
                  final AssessmentModel asst = entry.value;
                  final bool needDivider = modules.isNotEmpty || index > 0;
                  return Column(
                    children: <Widget>[
                      if (needDivider)
                        Divider(
                          height: 1.0,
                          thickness: 1.0,
                          color: borderColor.withValues(alpha: 0.35),
                        ),
                      _buildHollowAssessmentRow(
                        asst: asst,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyActiveLearningState({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool hasNoTotal = _totalActiveCount == 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              hasNoTotal
                  ? 'No Active Learning Yet'
                  : 'No items match your filters',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            Text(
              hasNoTotal
                  ? 'Explore curated modules to start learning and tracking your coding progress.'
                  : 'Try adjusting the filters or clearing your search.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            if (hasNoTotal)
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.go('/learn/modules');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14.0),
                label: Text(
                  'Explore Modules',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: isDark
                      ? AppColors.onPrimaryDark
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0,
                ),
              )
            else
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _activeLearningFilter = 'all';
                    _activeLearningSearch = '';
                    _activeLearningSearchController.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  'Clear Filters',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLearningProgressDropdown({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return SelectFilter(
      title: 'Progress',
      options: <SelectOption>[
        for (final FilterTabItem t in _activeLearningFilterTabs)
          SelectOption(id: t.id, label: t.label, count: t.count),
      ],
      selectedId: _activeLearningFilter,
      onSelected: (String id) => setState(() => _activeLearningFilter = id),
    );
  }

  Widget _buildHollowModuleRow({
    required PathwayModel module,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isMastered = module.completion >= 100;
    final bool isStarted = module.completion > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/learn/modules/${module.id}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Row 1: LanguageAvatarStack + Title & Description + Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: LanguageAvatarStack(
                      languages: module.stack,
                      size: 26.0,
                      maxVisible: 2,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                module.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMastered) ...<Widget>[
                              const SizedBox(width: 8.0),
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.check_rounded,
                                      size: 15.0,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 3.0),
                                    Text(
                                      'Completed',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.0,
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
                        if (module.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4.0),
                          Text(
                            module.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                              height: 1.35,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // Row 2: Strict Progress Bar (No clamping per AGENTS.md)
              ClipRRect(
                borderRadius: BorderRadius.circular(999.0),
                child: LinearProgressIndicator(
                  value: module.completion / 100.0,
                  minHeight: 4.0,
                  backgroundColor: isDark
                      ? AppColors.darkBorder.withValues(alpha: 0.6)
                      : AppColors.lightBorder.withValues(alpha: 0.8),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),

              // Row 3: Progress Meta & Action
              Row(
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '${module.completion}%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' complete',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (!isMastered) ...<Widget>[
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 16.0,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4.0),
                        ],
                        Text(
                          isMastered
                              ? 'Review'
                              : isStarted
                              ? 'Continue Learning'
                              : 'Start Learning',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHollowAssessmentRow({
    required AssessmentModel asst,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final Map<String, dynamic>? attempt = _getAttemptForAssessment(asst.id);
    final bool hasAttempt = attempt != null;
    final int? attemptScore = attempt?['score'] as int?;
    final bool isPassed =
        attemptScore != null && attemptScore >= asst.passingScore;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          AssessmentPreviewSheet.show(
            context,
            assessment: asst,
            onStart: () {
              context.push('/learn/assessments/${asst.id}/take');
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Row 1: LanguageAvatarStack + Title & Description + Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: LanguageAvatarStack(
                      languages: asst.stack,
                      size: 26.0,
                      maxVisible: 2,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                asst.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPassed) ...<Widget>[
                              const SizedBox(width: 8.0),
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.check_rounded,
                                      size: 15.0,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 3.0),
                                    Text(
                                      'Passed',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.0,
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
                        if (asst.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4.0),
                          Text(
                            asst.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                              height: 1.35,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // Row 2: Duration & Attempt Score + Action
              Row(
                children: <Widget>[
                  Text(
                    '${asst.durationMins}m',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                  if (hasAttempt && attemptScore != null) ...<Widget>[
                    Text(
                      '  ·  ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Score ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: '$attemptScore%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          hasAttempt
                              ? Icons.assignment_turned_in_outlined
                              : Icons.timer_outlined,
                          size: 15.0,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          hasAttempt ? 'Review Test' : 'Take Assessment',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionsLog({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Hollow Metrics Overview Row
        Row(
          children: <Widget>[
            Expanded(
              child: _buildMetricBox(
                label: 'Submissions',
                value: '${_historyItems.length}',
                icon: Icons.layers_outlined,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMetricBox(
                label: 'Pass Rate',
                value: '$_passRate%',
                icon: Icons.check_circle_outline_rounded,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMetricBox(
                label: 'Review',
                value: '$_needsReviewCount',
                icon: Icons.access_time_rounded,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18.0),

        // Filter Tabs (Standard 36.0 Height)
        FilterTabBar(
          tabs: _filterTabs,
          selectedId: _statusFilter,
          onTabSelected: (String tabId) {
            setState(() {
              _statusFilter = tabId;
              _currentPage = 1;
            });
          },
        ),
        const SizedBox(height: 12.0),

        // Search & Language Dropdown Controls Row
        Row(
          children: <Widget>[
            // Search Input
            Expanded(
              child: Container(
                height: 44.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 9.0,
                    ),
                    hintText: 'Search submissions...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 17.0,
                      color: textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 15.0,
                              color: textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _currentPage = 1;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),

            // Language Filter Dropdown
            _buildLanguageDropdown(
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 16.0),

        // Content Section: Skeleton | Empty | Hollow Submissions List
        if (_isLoading && _submissions.isEmpty)
          _buildLoadingSkeleton(isDark)
        else if (_filteredHistory.isEmpty)
          _buildEmptyState(
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          )
        else ...<Widget>[
          // Hollow Submissions Table/List (Web 1:1 Parity)
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: borderColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Column(
              children: _visibleHistory.asMap().entries.map((
                MapEntry<int, HistoryItem> entry,
              ) {
                final int index = entry.key;
                final HistoryItem item = entry.value;
                return Column(
                  children: <Widget>[
                    if (index > 0)
                      Divider(
                        height: 1.0,
                        thickness: 1.0,
                        color: borderColor.withValues(alpha: 0.35),
                      ),
                    switch (item) {
                      SubmissionHistoryItem(:final DashboardSubmission sub) =>
                        _buildHollowSubmissionRow(
                          sub: sub,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        ),
                      AssessmentHistoryItem() => _buildAssessmentAttemptRow(
                        item: item,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                    },
                  ],
                );
              }).toList(),
            ),
          ),

          // Pagination Footer (Jakob's Law Pattern)
          _buildPaginationBar(
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
        ],
      ],
    );
  }

  /// A label over a number. No box, no colour; a figure is just a figure.
  Widget _buildMetricBox({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            color: textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final Map<String, int> counts = _languageCounts;
    String cap(String l) {
      const Map<String, String> names = <String, String>{
        'javascript': 'JavaScript',
        'typescript': 'TypeScript',
        'cpp': 'C++',
        'csharp': 'C#',
        'php': 'PHP',
        'sql': 'SQL',
      };
      return names[l] ??
          (l.isNotEmpty ? '${l[0].toUpperCase()}${l.substring(1)}' : l);
    }

    return SelectFilter(
      title: 'Language',
      options: <SelectOption>[
        SelectOption(
          id: 'all',
          label: 'All Languages',
          count: _historyItems.length,
        ),
        for (final MapEntry<String, int> e in counts.entries)
          SelectOption(
            id: e.key,
            label: cap(e.key),
            count: e.value,
            leading: LanguageIcon(language: e.key, size: 18.0),
          ),
      ],
      selectedId: _langFilter,
      onSelected: (String id) => setState(() {
        _langFilter = id;
        _currentPage = 1;
      }),
    );
  }

  Widget _buildHollowSubmissionRow({
    required DashboardSubmission sub,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSubmissionReview(sub),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Row 1: Status Badge, Score, and Relative Timestamp
              Row(
                children: <Widget>[
                  _buildStatusBadge(sub.status, textSecondary),
                  const SizedBox(width: 8.0),
                  if (sub.score != null)
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${sub.score}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
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
                    )
                  else
                    Text(
                      '—',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    sub.timeAgoFormatted,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7.0),

              // Row 2: Challenge Title & Module Name
              Text(
                sub.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2.5),
              Text(
                sub.module,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8.0),

              // Row 3: Language Icon + Name, Difficulty Badge, Review CTA
              Row(
                children: <Widget>[
                  LanguageIcon(language: sub.language, size: 15.0),
                  const SizedBox(width: 6.0),
                  Text(
                    sub.language.isNotEmpty
                        ? '${sub.language[0].toUpperCase()}${sub.language.substring(1)}'
                        : sub.language,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.rate_review_outlined,
                        size: 15.0,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Review',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One assessment attempt as a single row. Tapping it opens the challenges
  /// that were part of the attempt; each one opens its own code review.
  Widget _buildAssessmentAttemptRow({
    required AssessmentHistoryItem item,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool expanded = _expandedAttempts.contains(item.key);
    final bool hasChallenges = item.challenges.isNotEmpty;

    final List<InlineSpan> summary = <InlineSpan>[
      TextSpan(
        text: 'Assessment',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.0,
          color: textSecondary,
        ),
      ),
      if (hasChallenges) ...<InlineSpan>[
        TextSpan(
          text: '  ·  ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            color: textSecondary,
          ),
        ),
        TextSpan(
          text: '${item.passedCount} of ${item.challenges.length}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.0,
            color: textSecondary,
          ),
        ),
        TextSpan(
          text: ' challenges passed',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            color: textSecondary,
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: hasChallenges
              ? () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (expanded) {
                      _expandedAttempts.remove(item.key);
                    } else {
                      _expandedAttempts.add(item.key);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 4.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _buildStatusBadge(item.status, textSecondary),
                    const SizedBox(width: 8.0),
                    if (item.score != null)
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${item.score}%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _timeAgo(item.date),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7.0),
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.5),
                Row(
                  children: <Widget>[
                    Expanded(child: Text.rich(TextSpan(children: summary))),
                    if (hasChallenges)
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 22.0,
                        color: textSecondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.only(left: 12.0, bottom: 8.0),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor, width: 1.0)),
            ),
            child: Column(
              children: item.challenges.map((DashboardSubmission c) {
                return InkWell(
                  onTap: () => _openSubmissionReview(c),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  c.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2.0),
                                _buildStatusBadge(c.status, textSecondary),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          if (c.score != null)
                            Text(
                              '${c.score}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          const SizedBox(width: 4.0),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20.0,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _timeAgo(DateTime at) {
    final Duration diff = DateTime.now().toUtc().difference(at.toUtc());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.month}/${at.day}/${at.year}';
  }

  void _openSubmissionReview(DashboardSubmission sub) {
    HapticFeedback.selectionClick();
    context.push('/learn/activity/${sub.id}', extra: sub);
  }

  Widget _buildPaginationBar({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    if (_filteredHistory.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14.0, bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Showing ${_filteredHistory.isEmpty ? 0 : _startIndex + 1}–$_endIndex of ${_filteredHistory.length}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.0,
              color: textSecondary,
            ),
          ),
          if (_totalPages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  onPressed: _currentPage > 1
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _currentPage--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  iconSize: 20.0,
                  color: textPrimary,
                  disabledColor: textSecondary.withValues(alpha: 0.7),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48.0,
                    minHeight: 48.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _currentPage < _totalPages
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  iconSize: 20.0,
                  color: textPrimary,
                  disabledColor: textSecondary.withValues(alpha: 0.7),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48.0,
                    minHeight: 48.0,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool hasNoTotal = _historyItems.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              hasNoTotal
                  ? 'No submissions yet'
                  : 'No submissions match your filters',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            Text(
              hasNoTotal
                  ? 'Complete challenges inside any active module to see your submission history here.'
                  : 'Try adjusting the filters or clearing your search.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            if (hasNoTotal)
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push('/modules');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14.0),
                label: Text(
                  'Browse Modules',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: isDark
                      ? AppColors.onPrimaryDark
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0,
                ),
              )
            else
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _statusFilter = 'all';
                    _langFilter = 'all';
                    _searchQuery = '';
                    _searchController.clear();
                    _currentPage = 1;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  'Clear Filters',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Skeleton metrics
          const Row(
            children: <Widget>[
              Expanded(child: SkeletonBox(height: 54.0, borderRadius: 12.0)),
              SizedBox(width: 8.0),
              Expanded(child: SkeletonBox(height: 54.0, borderRadius: 12.0)),
              SizedBox(width: 8.0),
              Expanded(child: SkeletonBox(height: 54.0, borderRadius: 12.0)),
              SizedBox(width: 8.0),
              Expanded(child: SkeletonBox(height: 54.0, borderRadius: 12.0)),
            ],
          ),
          const SizedBox(height: 16.0),
          // Skeleton filter tabs
          const Row(
            children: <Widget>[
              SkeletonBox(width: 60.0, height: 32.0, borderRadius: 10.0),
              SizedBox(width: 8.0),
              SkeletonBox(width: 80.0, height: 32.0, borderRadius: 10.0),
              SizedBox(width: 8.0),
              SkeletonBox(width: 100.0, height: 32.0, borderRadius: 10.0),
            ],
          ),
          const SizedBox(height: 12.0),
          // Skeleton search
          const SkeletonBox(
            width: double.infinity,
            height: 38.0,
            borderRadius: 10.0,
          ),
          const SizedBox(height: 16.0),
          // Skeleton hollow rows
          ...List<Widget>.generate(
            4,
            (int index) => const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: SkeletonBox(
                width: double.infinity,
                height: 72.0,
                borderRadius: 8.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
