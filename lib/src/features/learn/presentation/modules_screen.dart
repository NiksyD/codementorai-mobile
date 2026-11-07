import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/filter_tab_bar.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/assessment_repository.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_assessment_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/assessment_model.dart';
import '../domain/pathway_model.dart';
import 'widgets/assessment_preview_sheet.dart';

enum ExploreTab { modules, assessments }

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    super.key,
    this.pathwayRepository = const SupabasePathwayRepository(),
    this.assessmentRepository = const SupabaseAssessmentRepository(),
    this.initialTab = ExploreTab.modules,
  });

  final PathwayRepository pathwayRepository;
  final AssessmentRepository assessmentRepository;
  final ExploreTab initialTab;

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  late ExploreTab _selectedTab;

  // Modules State
  String _selectedCategory = 'all';
  String _searchQuery = '';
  List<PathwayModel> _modules = <PathwayModel>[];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Assessments State
  String _selectedFilter = 'all';
  String _assessmentSearchQuery = '';
  List<AssessmentModel> _assessments = <AssessmentModel>[];
  bool _isAssessmentsLoading = true;
  final TextEditingController _assessmentSearchController =
      TextEditingController();

  static const List<Map<String, String>> _categories = <Map<String, String>>[
    <String, String>{'id': 'all', 'label': 'All'},
    <String, String>{'id': 'in-progress', 'label': 'In Progress'},
    <String, String>{'id': 'bookmarked', 'label': 'Saved'},
    <String, String>{'id': 'completed', 'label': 'Completed'},
  ];

  static const List<Map<String, String>> _assessmentFilters =
      <Map<String, String>>[
        <String, String>{'id': 'all', 'label': 'All'},
        <String, String>{'id': 'saved', 'label': 'Saved'},
      ];

  static const Map<String, List<String>> _searchAliases =
      <String, List<String>>{
        'cpp': <String>['c++', 'cpp'],
        'c++': <String>['c++', 'cpp'],
        'csharp': <String>['c#', 'csharp'],
        'c#': <String>['c#', 'csharp'],
        'js': <String>['javascript', 'js'],
        'javascript': <String>['javascript', 'js'],
        'php': <String>['php'],
        'py': <String>['python', 'py'],
        'python': <String>['python', 'py'],
        'react': <String>['react', 'js-react'],
        'spring': <String>['spring', 'java-spring'],
      };

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    SupabasePathwayRepository.bookmarkedIdsNotifier.addListener(
      _onBookmarksChanged,
    );
    SupabasePathwayRepository.catalogRefreshNotifier.addListener(
      _onCatalogRefresh,
    );
    SupabaseAssessmentRepository.bookmarkedAssessmentIdsNotifier.addListener(
      _onAssessmentBookmarksChanged,
    );
    _loadModules();
    _loadAssessments();
  }

  @override
  void dispose() {
    SupabasePathwayRepository.bookmarkedIdsNotifier.removeListener(
      _onBookmarksChanged,
    );
    SupabasePathwayRepository.catalogRefreshNotifier.removeListener(
      _onCatalogRefresh,
    );
    SupabaseAssessmentRepository.bookmarkedAssessmentIdsNotifier.removeListener(
      _onAssessmentBookmarksChanged,
    );
    _searchController.dispose();
    _assessmentSearchController.dispose();
    super.dispose();
  }

  void _onCatalogRefresh() {
    _loadModules();
    _loadAssessments();
  }

  void _onBookmarksChanged() {
    final Set<String> bookmarkedIds =
        SupabasePathwayRepository.bookmarkedIdsNotifier.value;
    if (mounted) {
      setState(() {
        _modules = _modules
            .map(
              (PathwayModel p) =>
                  p.copyWith(isBookmarked: bookmarkedIds.contains(p.id)),
            )
            .toList();
      });
    }
  }

  void _onAssessmentBookmarksChanged() {
    final Set<String> bookmarkedIds =
        SupabaseAssessmentRepository.bookmarkedAssessmentIdsNotifier.value;
    if (mounted) {
      setState(() {
        _assessments = _assessments
            .map(
              (AssessmentModel a) =>
                  a.copyWith(isInLibrary: bookmarkedIds.contains(a.id)),
            )
            .toList();
      });
    }
  }

  Future<void> _loadAssessments() async {
    String userId = '';
    try {
      userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {}
    final List<AssessmentModel> data = await widget.assessmentRepository
        .getPublishedAssessments(userId);
    if (mounted) {
      setState(() {
        _assessments = data;
        _isAssessmentsLoading = false;
      });
    }
  }

  List<AssessmentModel> get _filteredAssessments {
    return _assessments.where((AssessmentModel a) {
      final bool matchesFilter =
          _selectedFilter == 'all' ||
          (_selectedFilter == 'saved' && a.isInLibrary);

      final bool matchesSearch =
          _assessmentSearchQuery.isEmpty ||
          a.title.toLowerCase().contains(
            _assessmentSearchQuery.toLowerCase(),
          ) ||
          a.description.toLowerCase().contains(
            _assessmentSearchQuery.toLowerCase(),
          ) ||
          a.stack.any(
            (String s) =>
                s.toLowerCase().contains(_assessmentSearchQuery.toLowerCase()),
          ) ||
          a.mentorName.toLowerCase().contains(
            _assessmentSearchQuery.toLowerCase(),
          );

      return matchesFilter && matchesSearch;
    }).toList();
  }

  int _getAssessmentCount(String filterId) {
    if (filterId == 'all') return _assessments.length;
    if (filterId == 'saved') {
      return _assessments.where((AssessmentModel a) => a.isInLibrary).length;
    }
    return 0;
  }

  Future<void> _loadModules() async {
    String userId = '';
    try {
      userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {}
    final List<PathwayModel> data = await widget.pathwayRepository
        .getAllModules(userId);
    if (mounted) {
      setState(() {
        _modules = data;
        _isLoading = false;
      });
    }
  }

  // Filter and Priority Sort: 1. Completed (100%), 2. Enrolled, 3. Explore
  List<PathwayModel> get _processedModules {
    final List<PathwayModel> filtered = _modules.where((PathwayModel p) {
      // Category filter
      if (_selectedCategory == 'in-progress' &&
          (!p.isEnrolled || p.completion >= 100)) {
        return false;
      }
      if (_selectedCategory == 'completed' &&
          (!p.isEnrolled || p.completion < 100)) {
        return false;
      }
      if (_selectedCategory == 'bookmarked' && !p.isBookmarked) {
        return false;
      }

      // Multi-token AND search with alias matching (matching Web 1:1)
      if (_searchQuery.trim().isNotEmpty) {
        final List<String> rawTokens = _searchQuery
            .trim()
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((String s) => s.isNotEmpty)
            .toList();

        final String title = p.title.toLowerCase();
        final String desc = p.description.toLowerCase();
        final String id = p.id.toLowerCase();
        final List<String> stack = p.stack
            .map((String s) => s.toLowerCase())
            .toList();

        return rawTokens.every((String token) {
          final List<String> terms = _searchAliases[token] ?? <String>[token];

          return terms.any((String term) {
            if (term == 'c') {
              final bool isC =
                  id == 'c' ||
                  stack.contains('c') ||
                  RegExp(r'\bc\b', caseSensitive: false).hasMatch(p.title);
              if (isC) return true;
            }

            return title.contains(term) ||
                desc.contains(term) ||
                id.contains(term) ||
                stack.any((String s) => s.contains(term));
          });
        });
      }

      return true;
    }).toList();

    // Priority Sort: 1. Completed (100%), 2. Enrolled, 3. Explore
    return filtered..sort((PathwayModel a, PathwayModel b) {
      final int aCompleted = (a.isEnrolled && a.completion >= 100) ? 1 : 0;
      final int bCompleted = (b.isEnrolled && b.completion >= 100) ? 1 : 0;
      if (aCompleted != bCompleted) return bCompleted - aCompleted;

      final int aEnrolled = a.isEnrolled ? 1 : 0;
      final int bEnrolled = b.isEnrolled ? 1 : 0;
      if (aEnrolled != bEnrolled) return bEnrolled - aEnrolled;

      return 0;
    });
  }

  int _getCategoryCount(String categoryId) {
    switch (categoryId) {
      case 'in-progress':
        return _modules
            .where((PathwayModel p) => p.isEnrolled && p.completion < 100)
            .length;
      case 'bookmarked':
        return _modules.where((PathwayModel p) => p.isBookmarked).length;
      case 'completed':
        return _modules
            .where((PathwayModel p) => p.isEnrolled && p.completion >= 100)
            .length;
      case 'all':
      default:
        return _modules.length;
    }
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

    final List<PathwayModel> displayModules = _processedModules;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            if (_selectedTab == ExploreTab.modules) {
              await _loadModules();
            } else {
              await _loadAssessments();
            }
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              // ── Header & Search Controls (Matching Web 1:1) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Screen Title & Caption per AGENTS.md rule 1.3
                      Text(
                        'Explore',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22.0,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Browse coding modules and practice challenges.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // Primary Scope Switcher (Modules vs Assessments, matching Web 1:1)
                      _buildScopeSwitcher(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 12.0),

                      // Context-aware Search Input
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _selectedTab == ExploreTab.modules
                              ? _searchController
                              : _assessmentSearchController,
                          onChanged: (String val) {
                            setState(() {
                              if (_selectedTab == ExploreTab.modules) {
                                _searchQuery = val;
                              } else {
                                _assessmentSearchQuery = val;
                              }
                            });
                          },
                          textAlignVertical: TextAlignVertical.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: _selectedTab == ExploreTab.modules
                                ? 'Search modules...'
                                : 'Search assessments by stack or topic...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w400,
                              color: textSecondary.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 19.0,
                              color: textSecondary,
                            ),
                            suffixIcon:
                                (_selectedTab == ExploreTab.modules
                                    ? _searchQuery.isNotEmpty
                                    : _assessmentSearchQuery.isNotEmpty)
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 17.0,
                                      color: textSecondary,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      if (_selectedTab == ExploreTab.modules) {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      } else {
                                        _assessmentSearchController.clear();
                                        setState(() {
                                          _assessmentSearchQuery = '';
                                        });
                                      }
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 10.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.0),

                      // Context-aware Filter Tabs with Dynamic Count Badges
                      if (_selectedTab == ExploreTab.modules)
                        FilterTabBar(
                          tabs: _categories.map((Map<String, String> cat) {
                            final String catId = cat['id']!;
                            return FilterTabItem(
                              id: catId,
                              label: cat['label']!,
                              count: _getCategoryCount(catId),
                            );
                          }).toList(),
                          selectedId: _selectedCategory,
                          onTabSelected: (String catId) {
                            setState(() {
                              _selectedCategory = catId;
                            });
                          },
                        )
                      else
                        FilterTabBar(
                          tabs: _assessmentFilters.map((
                            Map<String, String> cat,
                          ) {
                            final String catId = cat['id']!;
                            return FilterTabItem(
                              id: catId,
                              label: cat['label']!,
                              count: _getAssessmentCount(catId),
                            );
                          }).toList(),
                          selectedId: _selectedFilter,
                          onTabSelected: (String catId) {
                            setState(() {
                              _selectedFilter = catId;
                            });
                          },
                        ),
                      const SizedBox(height: 10.0),

                      // Summary Counter Header (Matching Web 1:1)
                      if (_selectedTab == ExploreTab.modules &&
                          !_isLoading &&
                          displayModules.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text: '${displayModules.length}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' module${displayModules.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_selectedTab == ExploreTab.assessments &&
                          !_isAssessmentsLoading &&
                          _filteredAssessments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text: '${_filteredAssessments.length}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' assessment${_filteredAssessments.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Tab 0: Modules Content ──
              if (_selectedTab == ExploreTab.modules) ...<Widget>[
                if (_isLoading)
                  _buildSkeletonList(isDark: isDark)
                else if (displayModules.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20.0,
                        12.0,
                        20.0,
                        96.0,
                      ),
                      child: _buildEmptyState(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 96.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((
                        BuildContext context,
                        int index,
                      ) {
                        final PathwayModel module = displayModules[index];
                        return _buildModuleCard(
                          module: module,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      }, childCount: displayModules.length),
                    ),
                  ),
              ]
              // ── Tab 1: Assessments Content ──
              else ...<Widget>[
                if (_isAssessmentsLoading)
                  _buildSkeletonList(isDark: isDark)
                else if (_filteredAssessments.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20.0,
                        12.0,
                        20.0,
                        96.0,
                      ),
                      child: _buildAssessmentEmptyState(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 96.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((
                        BuildContext context,
                        int index,
                      ) {
                        final AssessmentModel assessment =
                            _filteredAssessments[index];
                        return _buildAssessmentCard(
                          context,
                          assessment: assessment,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      }, childCount: _filteredAssessments.length),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MODULE CARD (Matching Web Shadcn Card 1:1)
  // ===========================================================================
  Widget _buildModuleCard({
    required PathwayModel module,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isEnrolled = module.isEnrolled;
    final bool isCompleted = isEnrolled && module.completion >= 100;

    // CTA Label strictly following AGENTS.md rule 1.2
    final String ctaLabel = !isEnrolled
        ? 'Start Learning'
        : isCompleted
        ? 'Review'
        : 'Continue Learning';

    // Strict 0% Handling per AGENTS.md rule 2.3
    final double progressValue = module.completion <= 0
        ? 0.0
        : (module.completion / 100.0).clamp(0.0, 1.0);

    Future<void> handleCardAction() async {
      HapticFeedback.lightImpact();
      await context.push('/modules/${module.id}');
      if (mounted) {
        _loadModules();
      }
    }

    Future<void> handleToggleBookmark() async {
      String userId = '';
      try {
        userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      } catch (_) {}
      if (userId.isEmpty) {
        AppToast.showError(context, 'Please log in to save bookmarks');
        return;
      }
      HapticFeedback.selectionClick();
      final bool nextState = !module.isBookmarked;
      setState(() {
        _modules = _modules
            .map(
              (PathwayModel p) =>
                  p.id == module.id ? p.copyWith(isBookmarked: nextState) : p,
            )
            .toList();
      });
      final bool ok = await widget.pathwayRepository.toggleBookmark(
        userId,
        module.id,
        nextState,
      );
      if (!ok && mounted) {
        setState(() {
          _modules = _modules
              .map(
                (PathwayModel p) => p.id == module.id
                    ? p.copyWith(isBookmarked: !nextState)
                    : p,
              )
              .toList();
        });
        AppToast.showError(context, 'Failed to update bookmark');
      }
    }

    final Widget bookmark = Semantics(
      button: true,
      label: module.isBookmarked ? 'Remove bookmark' : 'Save module',
      child: InkWell(
        onTap: handleToggleBookmark,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48.0,
          height: 48.0,
          child: Icon(
            module.isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 22.0,
            color: module.isBookmarked ? textPrimary : textSecondary,
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
      ),
      child: InkWell(
        onTap: handleCardAction,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  LanguageAvatarStack(
                    languages: module.stack.isNotEmpty
                        ? module.stack
                        : <String>[module.language],
                    maxVisible: 3,
                    size: 24.0,
                    borderColor: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isCompleted) ...<Widget>[
                        Icon(
                          Icons.check_rounded,
                          size: 16.0,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          'Completed',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                      Transform.translate(
                        offset: const Offset(12.0, 0.0),
                        child: bookmark,
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                module.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6.0),
              Text(
                module.description.isNotEmpty
                    ? module.description
                    : 'Master core programming concepts and hands-on challenges.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10.0),
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      module.coachName ?? 'AI Mentor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                  Icon(Icons.star_rounded, size: 14.0, color: textSecondary),
                  const SizedBox(width: 3.0),
                  Text(
                    module.rating.toStringAsFixed(1),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
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
                          text: '${module.totalModules}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: module.totalModules == 1 ? ' topic' : ' topics',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (isEnrolled) ...<Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999.0),
                              child: SizedBox(
                                height: 4.0,
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  backgroundColor: isDark
                                      ? AppColors.darkSurfaceHighest
                                      : AppColors.lightBorder,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Text(
                            '${module.completion}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16.0),
                  ] else
                    const Spacer(),
                  _buildCompactModuleActionButton(
                    label: ctaLabel,
                    isCompleted: isCompleted,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    onPressed: handleCardAction,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactModuleActionButton({
    required String label,
    required bool isCompleted,
    required bool isDark,
    required Color textPrimary,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 44.0,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(
            color: isDark ? AppColors.darkBorderVariant : AppColors.lightBorder,
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!isCompleted) ...<Widget>[
              const Icon(
                Icons.play_arrow_rounded,
                size: 16.0,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4.0),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4.0),
            const Icon(Icons.arrow_forward_rounded, size: 14.0),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE (Matching Web Shadcn Empty Card 1:1)
  // ===========================================================================
  Widget _buildEmptyState({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final String title = _searchQuery.trim().isNotEmpty
        ? 'No modules matching "$_searchQuery"'
        : _selectedCategory == 'bookmarked'
        ? 'No saved modules yet'
        : _selectedCategory == 'in-progress'
        ? 'No modules in progress'
        : _selectedCategory == 'completed'
        ? 'No completed modules yet'
        : 'No published modules available';

    final String subtitle = _searchQuery.trim().isNotEmpty
        ? 'Try searching for a different language, keyword, or topic.'
        : _selectedCategory == 'bookmarked'
        ? 'Tap the bookmark icon on any module card to save it for quick access.'
        : _selectedCategory == 'in-progress'
        ? 'Start learning a module to track your progression here.'
        : 'Modules published by mentors will appear here.';

    final bool hasFilterOrSearch =
        _selectedCategory != 'all' || _searchQuery.trim().isNotEmpty;

    final IconData emptyIcon = _selectedCategory == 'bookmarked'
        ? Icons.bookmark_border_rounded
        : _selectedCategory == 'completed'
        ? Icons.check_circle_outline_rounded
        : _selectedCategory == 'in-progress'
        ? Icons.timelapse_rounded
        : _searchQuery.trim().isNotEmpty
        ? Icons.filter_alt_off_rounded
        : Icons.layers_clear_outlined;

    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

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
              child: Icon(emptyIcon, size: 26.0, color: textSecondary),
            ),
            const SizedBox(height: 16.0),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilterOrSearch) ...<Widget>[
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
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
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SKELETON LOADING STATE (Matching Web Shadcn Skeleton 1:1)
  // ===========================================================================
  Widget _buildSkeletonList({required bool isDark}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 32.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          return _buildSkeletonCard(isDark: isDark);
        }, childCount: 4),
      ),
    );
  }

  Widget _buildSkeletonCard({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
      ),
      child: const ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonBox(width: 56.0, height: 24.0, borderRadius: 12.0),
            SizedBox(height: 14.0),
            SkeletonBox(width: 200.0, height: 18.0, borderRadius: 4.0),
            SizedBox(height: 8.0),
            SkeletonBox(
              width: double.infinity,
              height: 12.0,
              borderRadius: 4.0,
            ),
            SizedBox(height: 6.0),
            SkeletonBox(width: 220.0, height: 12.0, borderRadius: 4.0),
            SizedBox(height: 16.0),
            SkeletonBox(
              width: double.infinity,
              height: 44.0,
              borderRadius: 10.0,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PRIMARY SCOPE SWITCHER: two text tabs with a hairline underneath
  // ===========================================================================
  Widget _buildScopeSwitcher({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          _buildScopeTabItem(
            tab: ExploreTab.modules,
            label: 'Modules',
            count: _modules.length,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(width: 24.0),
          _buildScopeTabItem(
            tab: ExploreTab.assessments,
            label: 'Assessments',
            count: _assessments.length,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTabItem({
    required ExploreTab tab,
    required String label,
    required int count,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isSelected = _selectedTab == tab;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = tab);
        },
        child: Container(
          height: 48.0,
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? textPrimary : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? textPrimary : textSecondary,
                ),
              ),
              if (count > 0) ...<Widget>[
                const SizedBox(width: 6.0),
                Text(
                  '$count',
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
    );
  }

  // ===========================================================================
  // ASSESSMENTS EMPTY STATE
  // ===========================================================================
  Widget _buildAssessmentEmptyState({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final String title = _selectedFilter == 'saved'
        ? 'No saved assessments yet'
        : 'No assessments found';

    final String subtitle = _assessmentSearchQuery.trim().isNotEmpty
        ? 'Try refining your search keyword or filters.'
        : _selectedFilter == 'saved'
        ? 'Tap the bookmark icon on any assessment card to save it for quick access.'
        : 'Check back soon for new competition benchmarks.';

    final bool hasFilterOrSearch =
        _selectedFilter != 'all' || _assessmentSearchQuery.trim().isNotEmpty;

    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

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
                Icons.emoji_events_outlined,
                size: 26.0,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6.0),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilterOrSearch) ...<Widget>[
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _assessmentSearchController.clear();
                  setState(() {
                    _assessmentSearchQuery = '';
                    _selectedFilter = 'all';
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
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ASSESSMENT CARD (Matching Web 1:1)
  // ===========================================================================
  Widget _buildAssessmentCard(
    BuildContext context, {
    required AssessmentModel assessment,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    Future<void> handleCardTap() async {
      HapticFeedback.lightImpact();
      await AssessmentPreviewSheet.show(
        context,
        assessment: assessment,
        assessmentRepository: widget.assessmentRepository,
        onUnlocked: () {
          if (!mounted) return;
          setState(() {
            _assessments = _assessments
                .map(
                  (AssessmentModel a) =>
                      a.id == assessment.id ? a.copyWith(isUnlocked: true) : a,
                )
                .toList();
          });
        },
        onStart: () {
          context.push('/assessments/${assessment.id}/take');
        },
      );
    }

    Future<void> handleToggleBookmark() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        AppToast.showError(context, 'Please log in to save assessments');
        return;
      }
      HapticFeedback.selectionClick();
      final bool nextState = !assessment.isInLibrary;

      setState(() {
        _assessments = _assessments
            .map(
              (AssessmentModel a) => a.id == assessment.id
                  ? a.copyWith(isInLibrary: nextState)
                  : a,
            )
            .toList();
      });

      final bool ok = await widget.assessmentRepository
          .toggleAssessmentBookmark(user.id, assessment.id, nextState);

      if (!ok && mounted) {
        setState(() {
          _assessments = _assessments
              .map(
                (AssessmentModel a) => a.id == assessment.id
                    ? a.copyWith(isInLibrary: !nextState)
                    : a,
              )
              .toList();
        });
        if (context.mounted) {
          AppToast.showError(context, 'Failed to update saved assessment');
        }
      }
    }

    final Widget bookmark = Semantics(
      button: true,
      label: assessment.isInLibrary
          ? 'Remove saved assessment'
          : 'Save assessment',
      child: InkWell(
        onTap: handleToggleBookmark,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48.0,
          height: 48.0,
          child: Icon(
            assessment.isInLibrary
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 22.0,
            color: assessment.isInLibrary ? textPrimary : textSecondary,
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
      ),
      child: InkWell(
        onTap: handleCardTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  LanguageAvatarStack(
                    languages: assessment.stack,
                    size: 24.0,
                    borderColor: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        assessment.isUnlocked
                            ? Icons.lock_open_outlined
                            : Icons.monetization_on_outlined,
                        size: 16.0,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        assessment.isUnlocked
                            ? 'Unlocked'
                            : '${assessment.costCoins}',
                        style: assessment.isUnlocked
                            ? GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              )
                            : GoogleFonts.jetBrainsMono(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                      ),
                      Transform.translate(
                        offset: const Offset(12.0, 0.0),
                        child: bookmark,
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                assessment.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6.0),
              Text(
                assessment.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10.0),
              Row(
                children: <Widget>[
                  _buildMicroSpec(
                    icon: Icons.timer_outlined,
                    label: '${assessment.durationMins}m',
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 16.0),
                  _buildMicroSpec(
                    icon: Icons.code_rounded,
                    label: '${assessment.challengeCount} Tasks',
                    textSecondary: textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      assessment.mentorName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  SizedBox(
                    height: 44.0,
                    child: OutlinedButton(
                      onPressed: handleCardTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorderVariant
                              : AppColors.lightBorder,
                          width: 1.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'View',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          const Icon(Icons.arrow_forward_rounded, size: 14.0),
                        ],
                      ),
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

  Widget _buildMicroSpec({
    required IconData icon,
    required String label,
    required Color textSecondary,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14.0, color: textSecondary),
        const SizedBox(width: 4.0),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.0,
            color: textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
