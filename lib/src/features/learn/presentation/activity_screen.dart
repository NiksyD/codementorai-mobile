import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/filter_tab_bar.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../common_widgets/language_icon.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/assessment_repository.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_assessment_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/assessment_model.dart';
import '../domain/learn_dashboard_data.dart';
import '../domain/pathway_model.dart';
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
  int _activeSegment = 1; // 0 = Active Learning, 1 = Submissions Log, 2 = Competency Profile
  List<PathwayModel> _enrolledModules = <PathwayModel>[];
  List<AssessmentModel> _activeAssessments = <AssessmentModel>[];
  String _activeLearningFilter = 'all'; // 'all', 'in-progress', 'completed', 'assessments'
  String _activeLearningSearch = '';
  final TextEditingController _activeLearningSearchController = TextEditingController();

  List<DashboardSubmission> _submissions = <DashboardSubmission>[];
  List<Map<String, dynamic>> _assessmentAttempts = <Map<String, dynamic>>[];
  bool _isLoading = true;

  String _statusFilter = 'all'; // 'all', 'passed', 'needs-review', 'pending'
  String _langFilter = 'all';
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
        _enrolledModules = SupabasePathwayRepository.cachedData!.enrolledPathways
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

      final LearnDashboardData dashData =
          await widget.pathwayRepository.getLearnDashboardData(userId);
      final List<DashboardSubmission> subs = dashData.submissions.isNotEmpty
          ? dashData.submissions
          : await widget.pathwayRepository.getUserSubmissions(userId);
      final List<PathwayModel> enrolled = dashData.enrolledPathways
          .where((PathwayModel p) =>
              p.completion > 0 ||
              subs.any((DashboardSubmission s) => s.moduleId == p.id || s.module == p.title))
          .toList();

      List<Map<String, dynamic>> attempts = <Map<String, dynamic>>[];
      List<AssessmentModel> publishedAssessments = <AssessmentModel>[];
      if (userId.isNotEmpty) {
        try {
          attempts = await widget.assessmentRepository.getUserAssessmentAttempts(userId);
        } catch (_) {
          attempts = <Map<String, dynamic>>[];
        }
        try {
          publishedAssessments = await widget.assessmentRepository.getPublishedAssessments(userId);
        } catch (_) {
          publishedAssessments = <AssessmentModel>[];
        }
      }

      // Filter active assessments (only attempted ones appear in active learning desk)
      final List<AssessmentModel> activeAssts = publishedAssessments.where((AssessmentModel a) {
        return attempts.any((Map<String, dynamic> att) => att['assessment_id'] == a.id);
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
          } else if (_enrolledModules.isEmpty && _activeAssessments.isEmpty && _submissions.isNotEmpty) {
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

  int get _totalActiveCount => _enrolledModules.length + _activeAssessments.length;

  int get _completedModulesCount =>
      _enrolledModules.where((PathwayModel p) => p.completion >= 100).length;

  int get _inProgressModulesCount =>
      _enrolledModules.where((PathwayModel p) => p.completion > 0 && p.completion < 100).length;

  int get _avgCompletion {
    if (_enrolledModules.isEmpty) return 0;
    final int sum = _enrolledModules.fold<int>(0, (int acc, PathwayModel p) => acc + p.completion);
    return (sum / _enrolledModules.length).round();
  }

  List<FilterTabItem> get _activeLearningFilterTabs => <FilterTabItem>[
    FilterTabItem(id: 'all', label: 'All', count: _totalActiveCount),
    FilterTabItem(id: 'in-progress', label: 'In Progress', count: _inProgressModulesCount),
    FilterTabItem(id: 'completed', label: 'Mastered', count: _completedModulesCount),
    if (_activeAssessments.isNotEmpty)
      FilterTabItem(id: 'assessments', label: 'Assessments', count: _activeAssessments.length),
  ];

  List<PathwayModel> get _filteredEnrolledModules {
    if (_activeLearningFilter == 'assessments') return const <PathwayModel>[];
    return _enrolledModules.where((PathwayModel p) {
      if (_activeLearningFilter == 'in-progress' && (p.completion <= 0 || p.completion >= 100)) return false;
      if (_activeLearningFilter == 'completed' && p.completion < 100) return false;
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
      final bool isPassed = att != null &&
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

  int get _passedCount =>
      _submissions.where((DashboardSubmission s) => s.isPassed).length;

  int get _needsReviewCount =>
      _submissions.where((DashboardSubmission s) => s.isNeedsReview).length;

  int get _pendingCount =>
      _submissions.where((DashboardSubmission s) => s.isPending).length;

  int get _streak => DashboardSubmission.computeStreak(_submissions);

  int get _passRate {
    if (_submissions.isEmpty) return 0;
    return ((_passedCount / _submissions.length) * 100).round();
  }

  List<FilterTabItem> get _filterTabs => <FilterTabItem>[
        FilterTabItem(id: 'all', label: 'All', count: _submissions.length),
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
    for (final DashboardSubmission s in _submissions) {
      final String lang = s.language.toLowerCase();
      counts[lang] = (counts[lang] ?? 0) + 1;
    }
    return counts;
  }

  List<DashboardSubmission> get _filteredSubmissions {
    return _submissions.where((DashboardSubmission s) {
      if (_statusFilter == 'passed' && !s.isPassed) return false;
      if (_statusFilter == 'needs-review' && !s.isNeedsReview) return false;
      if (_statusFilter == 'pending' && !s.isPending) return false;
      if (_langFilter != 'all' &&
          s.language.toLowerCase() != _langFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final String q = _searchQuery.trim().toLowerCase();
        final bool matchesTitle = s.title.toLowerCase().contains(q);
        final bool matchesModule = s.module.toLowerCase().contains(q);
        final bool matchesLang = s.language.toLowerCase().contains(q);
        if (!matchesTitle && !matchesModule && !matchesLang) return false;
      }
      return true;
    }).toList();
  }

  int get _totalPages =>
      max(1, (_filteredSubmissions.length / _itemsPerPage).ceil());
  int get _startIndex => (_currentPage - 1) * _itemsPerPage;
  int get _endIndex =>
      min(_startIndex + _itemsPerPage, _filteredSubmissions.length);

  List<DashboardSubmission> get _visibleSubmissions {
    if (_filteredSubmissions.isEmpty) return const <DashboardSubmission>[];
    return _filteredSubmissions.sublist(
      _startIndex,
      min(_endIndex, _filteredSubmissions.length),
    );
  }

  Widget _buildStatusBadge(String status) {
    final String s = DashboardSubmission.normalizeStatus(status);
    final bool isPassed = s == 'Passed';
    final bool isPending = s == 'Pending';

    final Color badgeColor = isPassed
        ? const Color(0xFF10B981)
        : isPending
            ? const Color(0xFF94A3B8)
            : const Color(0xFFF59E0B);

    final IconData icon = isPassed
        ? Icons.check_circle_rounded
        : isPending
            ? Icons.hourglass_empty_rounded
            : Icons.access_time_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11.5, color: badgeColor),
          const SizedBox(width: 4.0),
          Text(
            s,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 104.0),
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
                    constraints: const BoxConstraints(minWidth: 36.0, minHeight: 36.0),
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

                // Segmented Switcher (Active Learning vs Submissions Log vs Competency Profile)
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
                    onExploreAssessments: () => context.push('/learn/assessments'),
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
    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _buildSegmentButton(
              index: 0,
              icon: Icons.menu_book_rounded,
              label: 'Active',
              count: _totalActiveCount,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ),
          const SizedBox(width: 3.0),
          Expanded(
            child: _buildSegmentButton(
              index: 1,
              icon: Icons.code_rounded,
              label: 'Submissions',
              count: _submissions.length,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ),
          const SizedBox(width: 3.0),
          Expanded(
            child: _buildSegmentButton(
              index: 2,
              icon: Icons.insights_rounded,
              label: 'Competency',
              count: null,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required IconData icon,
    required String label,
    required int? count,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isSelected = _activeSegment == index;
    final Color selectedBg =
        isDark ? AppColors.darkSurface : Colors.white;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeSegment = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9.0),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 14.0,
              color: isSelected ? AppColors.primary : textSecondary,
            ),
            const SizedBox(width: 4.0),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? textPrimary : textSecondary,
                ),
              ),
            ),
            if (count != null) ...<Widget>[
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(999.0),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
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
                accentColor: const Color(0xFFF59E0B),
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

        // Filter Tabs (Showing: All | In Progress | Mastered)
        Row(
          children: <Widget>[
            Text(
              'Showing:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: FilterTabBar(
                height: 34.0,
                tabs: _activeLearningFilterTabs,
                selectedId: _activeLearningFilter,
                onTabSelected: (String tabId) {
                  setState(() {
                    _activeLearningFilter = tabId;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        // Search Input
        Container(
          height: 38.0,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
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
            style: GoogleFonts.plusJakartaSans(fontSize: 12.0, color: textPrimary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
              hintText: 'Search active modules & assessments...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.0, color: textSecondary),
              prefixIcon: Icon(Icons.search_rounded, size: 17.0, color: textSecondary),
              suffixIcon: _activeLearningSearch.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 15.0, color: textSecondary),
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
        const SizedBox(height: 16.0),

        // Active Learning Desk: Hollow Divided List | Empty State | Skeleton
        if (_isLoading && _enrolledModules.isEmpty && _activeAssessments.isEmpty)
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
                horizontal: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              children: <Widget>[
                // 1. Module Rows
                ...modules.asMap().entries.map((MapEntry<int, PathwayModel> entry) {
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
                ...assessments.asMap().entries.map((MapEntry<int, AssessmentModel> entry) {
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
            Container(
              width: 56.0,
              height: 56.0,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard
                    : AppColors.lightSurfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Icon(
                hasNoTotal ? Icons.menu_book_rounded : Icons.filter_alt_off_rounded,
                size: 26.0,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 16.0),
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
                fontSize: 12.5,
                color: textSecondary,
                height: 1.4,
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
                  foregroundColor:
                      isDark ? AppColors.onPrimaryDark : Colors.white,
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
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Row 1: LanguageAvatarStack + Title + Type badge + Mastered badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LanguageAvatarStack(
                    languages: module.stack,
                    size: 24.0,
                    maxVisible: 2,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                module.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                'MODULE',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            if (isMastered) ...<Widget>[
                              const SizedBox(width: 5.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.check_circle_rounded, size: 10.0, color: Color(0xFF10B981)),
                                    const SizedBox(width: 3.0),
                                    Text(
                                      'Mastered',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (module.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3.0),
                          Text(
                            module.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: textSecondary,
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
              const SizedBox(height: 8.0),

              // Row 2: Strict Progress Bar (No clamping per AGENTS.md)
              ClipRRect(
                borderRadius: BorderRadius.circular(999.0),
                child: LinearProgressIndicator(
                  value: module.completion / 100.0,
                  minHeight: 4.5,
                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMastered ? const Color(0xFF10B981) : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8.0),

              // Row 3: Meta & CTA Button
              Row(
                children: <Widget>[
                  Text(
                    '${module.completion}% complete',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: isStarted ? FontWeight.w700 : FontWeight.w500,
                      color: isStarted ? AppColors.primary : textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        isMastered
                            ? Icons.check_circle_outline_rounded
                            : Icons.play_arrow_rounded,
                        size: 14.0,
                        color: isMastered ? const Color(0xFF10B981) : AppColors.primary,
                      ),
                      const SizedBox(width: 3.0),
                      Text(
                        isMastered
                            ? 'Review'
                            : isStarted
                                ? 'Continue Learning'
                                : 'Start Learning',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isMastered ? const Color(0xFF10B981) : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2.0),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 11.0,
                        color: isMastered ? const Color(0xFF10B981) : AppColors.primary,
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
    final bool isPassed = attemptScore != null && attemptScore >= asst.passingScore;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/learn/assessments/${asst.id}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Row 1: LanguageAvatarStack + Title + Type badge + Passed badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LanguageAvatarStack(
                    languages: asst.stack,
                    size: 24.0,
                    maxVisible: 2,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                asst.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                'ASSESSMENT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            if (isPassed) ...<Widget>[
                              const SizedBox(width: 5.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.check_circle_rounded, size: 10.0, color: Color(0xFF10B981)),
                                    const SizedBox(width: 3.0),
                                    Text(
                                      'Passed',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (asst.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3.0),
                          Text(
                            asst.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: textSecondary,
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
              const SizedBox(height: 8.0),

              // Row 2: Duration, Passing Score & Attempt Score
              Row(
                children: <Widget>[
                  Text(
                    '${asst.durationMins}m · Pass ${asst.passingScore}%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      color: textSecondary,
                    ),
                  ),
                  if (hasAttempt && attemptScore != null) ...<Widget>[
                    const SizedBox(width: 6.0),
                    Text('·', style: GoogleFonts.jetBrainsMono(color: textSecondary.withValues(alpha: 0.4))),
                    const SizedBox(width: 6.0),
                    Text(
                      'Score: $attemptScore%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        color: isPassed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        hasAttempt ? 'Review Test' : 'Take Assessment',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 2.0),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 11.0,
                        color: Color(0xFFF59E0B),
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
                value: '${_submissions.length}',
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
                accentColor: _passRate >= 70
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
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
                accentColor: const Color(0xFFF59E0B),
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
          height: 36.0,
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
                height: 38.0,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceCard
                      : AppColors.lightSurfaceCard,
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
        else if (_filteredSubmissions.isEmpty)
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
                horizontal: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              children: _visibleSubmissions.asMap().entries.map((MapEntry<int, DashboardSubmission> entry) {
                final int index = entry.key;
                final DashboardSubmission sub = entry.value;
                return Column(
                  children: <Widget>[
                    if (index > 0)
                      Divider(
                        height: 1.0,
                        thickness: 1.0,
                        color: borderColor.withValues(alpha: 0.35),
                      ),
                    _buildHollowSubmissionRow(
                      sub: sub,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      borderColor: borderColor,
                    ),
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

  Widget _buildMetricBox({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 9.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 13.0,
                color: accentColor ?? textSecondary,
              ),
              const SizedBox(width: 4.0),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: accentColor ?? textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final Map<String, int> counts = _languageCounts;
    final String currentLabel = _langFilter == 'all'
        ? 'All Languages'
        : '${_langFilter[0].toUpperCase()}${_langFilter.substring(1)} (${counts[_langFilter] ?? 0})';

    return PopupMenuButton<String>(
      onSelected: (String val) {
        HapticFeedback.selectionClick();
        setState(() {
          _langFilter = val;
          _currentPage = 1;
        });
      },
      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'all',
          child: Text(
            'All Languages',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight:
                  _langFilter == 'all' ? FontWeight.w700 : FontWeight.w500,
              color: _langFilter == 'all' ? AppColors.primary : textPrimary,
            ),
          ),
        ),
        ...counts.entries.map((MapEntry<String, int> entry) {
          final String lang = entry.key;
          final int count = entry.value;
          final String capLang =
              lang.isNotEmpty ? '${lang[0].toUpperCase()}${lang.substring(1)}' : lang;

          return PopupMenuItem<String>(
            value: lang,
            child: Row(
              children: <Widget>[
                LanguageIcon(language: lang, size: 14.0),
                const SizedBox(width: 8.0),
                Text(
                  '$capLang ($count)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    fontWeight:
                        _langFilter == lang ? FontWeight.w700 : FontWeight.w500,
                    color: _langFilter == lang ? AppColors.primary : textPrimary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
      child: Container(
        height: 38.0,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              currentLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16.0,
              color: textSecondary,
            ),
          ],
        ),
      ),
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
                  _buildStatusBadge(sub.status),
                  const SizedBox(width: 8.0),
                  if (sub.score != null)
                    RichText(
                      text: TextSpan(
                        children: <TextSpan>[
                          TextSpan(
                            text: '${sub.score}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: sub.score! >= 85
                                  ? const Color(0xFF10B981)
                                  : sub.score! >= 70
                                      ? const Color(0xFF2DD4BF)
                                      : sub.score! >= 50
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFF43F5E),
                            ),
                          ),
                          TextSpan(
                            text: ' / 100',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              color: textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '—',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        color: textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    sub.timeAgoFormatted,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
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
                  fontSize: 11.5,
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
                  const SizedBox(width: 5.0),
                  Text(
                    sub.language.isNotEmpty
                        ? '${sub.language[0].toUpperCase()}${sub.language.substring(1)}'
                        : sub.language,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Review',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2.0),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 12.0,
                        color: AppColors.primary,
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
    if (_filteredSubmissions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14.0, bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Showing ${_filteredSubmissions.isEmpty ? 0 : _startIndex + 1}–$_endIndex of ${_filteredSubmissions.length}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
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
                  disabledColor: textSecondary.withValues(alpha: 0.3),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceCard
                        : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: borderColor),
                  ),
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
                  disabledColor: textSecondary.withValues(alpha: 0.3),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
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
    final bool hasNoTotal = _submissions.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 56.0,
              height: 56.0,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard
                    : AppColors.lightSurfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Icon(
                hasNoTotal ? Icons.code_rounded : Icons.filter_alt_off_rounded,
                size: 26.0,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 16.0),
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
                fontSize: 12.5,
                color: textSecondary,
                height: 1.4,
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
                  foregroundColor:
                      isDark ? AppColors.onPrimaryDark : Colors.white,
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
