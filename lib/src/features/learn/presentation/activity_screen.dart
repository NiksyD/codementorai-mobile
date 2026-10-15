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
  int _activeSegment = 1; // 0 = Enrolled & Active, 1 = Submissions
  List<PathwayModel> _enrolledModules = <PathwayModel>[];
  String _curriculumFilter = 'all'; // 'all', 'in-progress', 'completed'
  String _curriculumSearch = '';
  final TextEditingController _curriculumSearchController = TextEditingController();

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
        _enrolledModules = SupabasePathwayRepository.cachedData!.enrolledPathways;
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
    _curriculumSearchController.dispose();
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
      final List<PathwayModel> enrolled = dashData.enrolledPathways;

      List<Map<String, dynamic>> attempts = <Map<String, dynamic>>[];
      if (userId.isNotEmpty) {
        try {
          attempts = await widget.assessmentRepository.getUserAssessmentAttempts(userId);
        } catch (_) {
          attempts = <Map<String, dynamic>>[];
        }
      }

      if (mounted) {
        setState(() {
          _submissions = subs;
          _enrolledModules = enrolled;
          _assessmentAttempts = attempts;
          if (_enrolledModules.isNotEmpty && _activeSegment == 1 && _submissions.isEmpty) {
            _activeSegment = 0;
          } else if (_enrolledModules.isEmpty && _submissions.isNotEmpty) {
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

  int get _completedModulesCount =>
      _enrolledModules.where((PathwayModel p) => p.completion >= 100).length;

  int get _inProgressModulesCount =>
      _enrolledModules.where((PathwayModel p) => p.completion > 0 && p.completion < 100).length;

  int get _avgCompletion {
    if (_enrolledModules.isEmpty) return 0;
    final int sum = _enrolledModules.fold<int>(0, (int acc, PathwayModel p) => acc + p.completion);
    return (sum / _enrolledModules.length).round();
  }

  List<FilterTabItem> get _curriculumFilterTabs => <FilterTabItem>[
    FilterTabItem(id: 'all', label: 'All Items', count: _enrolledModules.length),
    FilterTabItem(id: 'in-progress', label: 'In Progress', count: _inProgressModulesCount),
    FilterTabItem(id: 'completed', label: 'Mastered', count: _completedModulesCount),
  ];

  List<PathwayModel> get _filteredEnrolledModules {
    return _enrolledModules.where((PathwayModel p) {
      if (_curriculumFilter == 'in-progress' && (p.completion <= 0 || p.completion >= 100)) return false;
      if (_curriculumFilter == 'completed' && p.completion < 100) return false;
      if (_curriculumSearch.trim().isNotEmpty) {
        final String q = _curriculumSearch.trim().toLowerCase();
        if (!p.title.toLowerCase().contains(q) &&
            !p.description.toLowerCase().contains(q) &&
            !p.stack.any((String s) => s.toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList();
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

  Color _getDifficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return const Color(0xFF10B981);
      case 'hard':
        return const Color(0xFFF43F5E);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _buildDifficultyBadge(String difficulty) {
    final Color color = _getDifficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Text(
        difficulty,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final String s = DashboardSubmission.normalizeStatus(status);
    final bool isPassed = s == 'Passed';
    final bool isPending = s == 'Pending';

    final Color badgeColor = isPassed
        ? const Color(0xFF10B981)
        : isPending
            ? const Color(0xFF64748B)
            : const Color(0xFFF59E0B);

    final IconData icon = isPassed
        ? Icons.check_circle_rounded
        : isPending
            ? Icons.hourglass_empty_rounded
            : Icons.access_time_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12.0, color: badgeColor),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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

                // Screen Title & Subtitle (Cross-platform parity)
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

                // Segmented Switcher (Enrolled vs Submissions vs Competency Profile)
                _buildSegmentSwitcher(
                  isDark: isDark,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 16.0),

                if (_activeSegment == 0)
                  _buildCurriculumDesk(
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
              icon: Icons.school_outlined,
              label: 'Enrolled',
              count: _enrolledModules.length,
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
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
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

  Widget _buildCurriculumDesk({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Metrics Overview Row
        Row(
          children: <Widget>[
            Expanded(
              child: _buildMetricBox(
                label: 'Enrolled',
                value: '${_enrolledModules.length}',
                icon: Icons.school_outlined,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMetricBox(
                label: 'Mastered',
                value: '$_completedModulesCount',
                icon: Icons.check_circle_outline_rounded,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accentColor: const Color(0xFF10B981),
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

        // Filter Tabs
        FilterTabBar(
          height: 36.0,
          tabs: _curriculumFilterTabs,
          selectedId: _curriculumFilter,
          onTabSelected: (String tabId) {
            setState(() {
              _curriculumFilter = tabId;
            });
          },
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
            controller: _curriculumSearchController,
            onChanged: (String val) {
              setState(() {
                _curriculumSearch = val;
              });
            },
            style: GoogleFonts.plusJakartaSans(fontSize: 12.0, color: textPrimary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
              hintText: 'Search enrolled modules...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.0, color: textSecondary),
              prefixIcon: Icon(Icons.search_rounded, size: 17.0, color: textSecondary),
              suffixIcon: _curriculumSearch.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 15.0, color: textSecondary),
                      onPressed: () {
                        _curriculumSearchController.clear();
                        setState(() {
                          _curriculumSearch = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16.0),

        // Enrolled Modules List | Empty State | Skeleton
        if (_isLoading && _enrolledModules.isEmpty)
          _buildLoadingSkeleton(isDark)
        else if (_filteredEnrolledModules.isEmpty)
          _enrolledModules.isEmpty
              ? _buildEmptyCurriculumState(isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      children: <Widget>[
                        Text('No items match your filter', style: GoogleFonts.plusJakartaSans(fontSize: 14.0, fontWeight: FontWeight.w700, color: textPrimary)),
                        const SizedBox(height: 4.0),
                        Text('Try resetting the search or filter options.', style: GoogleFonts.plusJakartaSans(fontSize: 12.0, color: textSecondary)),
                        const SizedBox(height: 12.0),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _curriculumFilter = 'all';
                              _curriculumSearch = '';
                              _curriculumSearchController.clear();
                            });
                          },
                          child: const Text('Reset Filters'),
                        ),
                      ],
                    ),
                  ),
                )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredEnrolledModules.length,
            separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12.0),
            itemBuilder: (BuildContext context, int index) {
              final PathwayModel mod = _filteredEnrolledModules[index];
              return _buildEnrolledModuleCard(
                module: mod,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyCurriculumState({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
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
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.school_outlined, size: 26.0, color: textSecondary),
            ),
            const SizedBox(height: 16.0),
            Text(
              'No Enrolled Modules Yet',
              style: GoogleFonts.plusJakartaSans(fontSize: 16.0, fontWeight: FontWeight.w700, color: textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            Text(
              'Explore curated pathways to start learning and tracking your coding progress.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.go('/learn/modules');
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 14.0),
              label: Text(
                'Explore Modules',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledModuleCard({
    required PathwayModel module,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isMastered = module.completion >= 100;
    final bool isStarted = module.completion > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/learn/modules/${module.id}');
          },
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Row 1: LanguageAvatarStack on left, {completion}% Complete on right (AGENTS.md)
                Row(
                  children: <Widget>[
                    LanguageAvatarStack(
                      languages: module.stack,
                      size: 24.0,
                    ),
                    const Spacer(),
                    Text(
                      '${module.completion}% Complete',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),

                // Row 2: Title & Description
                Text(
                  module.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (module.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3.0),
                  Text(
                    module.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12.0),

                // Row 3: Strict Progress Bar (No clamping per AGENTS.md)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999.0),
                  child: LinearProgressIndicator(
                    value: module.completion / 100.0,
                    minHeight: 5.5,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMastered ? const Color(0xFF10B981) : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),

                // Row 4: Status Badge, Coach, CTA (AGENTS.md Copy Standard)
                Row(
                  children: <Widget>[
                    if (isMastered)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999.0),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.check_circle_rounded, size: 11.0, color: Color(0xFF10B981)),
                            const SizedBox(width: 3.0),
                            Text(
                              'Mastered',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isStarted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999.0),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.access_time_rounded, size: 11.0, color: AppColors.primary),
                            const SizedBox(width: 3.0),
                            Text(
                              'In Progress',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'Not Started',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.play_arrow_rounded, size: 15.0, color: AppColors.primary),
                        const SizedBox(width: 2.0),
                        Text(
                          isStarted ? 'Continue Learning' : 'Start Learning',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2.0),
                        Icon(Icons.arrow_forward_rounded, size: 12.0, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
        // Metrics Overview Row
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

        // Content Section: Skeleton | Empty | Submissions List
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
          // List of Submission Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _visibleSubmissions.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 10.0),
            itemBuilder: (BuildContext context, int index) {
              final DashboardSubmission sub = _visibleSubmissions[index];
              return _buildSubmissionCard(
                sub: sub,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              );
            },
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
      padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(14.0),
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5.0),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15.0,
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

  Widget _buildSubmissionCard({
    required DashboardSubmission sub,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSubmissionReview(sub),
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
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
                                fontSize: 13.0,
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
                                fontSize: 10.5,
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
                          fontSize: 12.0,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      sub.timeAgoFormatted,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),

                // Row 2: Challenge Title & Module Name
                Text(
                  sub.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3.0),
                Text(
                  sub.module,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12.0),

                // Row 3: Language Icon + Name, Difficulty Badge, Review CTA
                Row(
                  children: <Widget>[
                    LanguageIcon(language: sub.language, size: 16.0),
                    const SizedBox(width: 6.0),
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
                    if (sub.difficulty.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 8.0),
                      _buildDifficultyBadge(sub.difficulty),
                    ],
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
                        const SizedBox(width: 3.0),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13.0,
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
      padding: const EdgeInsets.only(top: 12.0, bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Showing ${_filteredSubmissions.isEmpty ? 0 : _startIndex + 1}–$_endIndex of ${_filteredSubmissions.length}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.5,
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
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
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
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
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
                  ? 'Complete challenges inside any enrolled module to see your submission history here.'
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
              Expanded(child: SkeletonBox(height: 58.0, borderRadius: 14.0)),
              SizedBox(width: 8.0),
              Expanded(child: SkeletonBox(height: 58.0, borderRadius: 14.0)),
              SizedBox(width: 8.0),
              Expanded(child: SkeletonBox(height: 58.0, borderRadius: 14.0)),
              SizedBox(width: 8.0),
              Expanded(child: SkeletonBox(height: 58.0, borderRadius: 14.0)),
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
          // Skeleton cards
          ...List<Widget>.generate(
            3,
            (int index) => const Padding(
              padding: EdgeInsets.only(bottom: 10.0),
              child: SkeletonBox(
                width: double.infinity,
                height: 104.0,
                borderRadius: 16.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
