import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/filter_tab_bar.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../common_widgets/language_icon.dart';
import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/dashboard_submission.dart';
import '../domain/module_detail_model.dart';
import '../domain/module_review_model.dart';
import '../domain/pathway_model.dart';
import 'widgets/mentor_profile_sheet.dart';
import 'widgets/module_detail_skeleton.dart';
import 'widgets/module_preview_sheet.dart';
import 'widgets/module_review_modal.dart';
import 'widgets/report_module_sheet.dart';

class ModuleDetailScreen extends StatefulWidget {
  const ModuleDetailScreen({
    super.key,
    required this.moduleId,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final String moduleId;
  final PathwayRepository pathwayRepository;

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  ModuleDetailModel? _module;
  bool _isLoading = true;

  // 4 Main Tabs matching Web 1:1 ('practice', 'challenges', 'overview', 'reviews')
  String _selectedTab = 'practice';

  // Sub-filter for Tab 2 (Challenges)
  String _challengeFilter = 'all'; // 'all', 'easy', 'medium', 'hard', 'unsolved', 'submissions'
  String _challengeSearchQuery = '';
  final TextEditingController _challengeSearchController = TextEditingController();

  final Set<String> _expandedTopicIds = <String>{};
  List<ModuleReviewModel> _reviews = <ModuleReviewModel>[];
  bool _isLoadingReviews = false;
  List<DashboardSubmission> _userSubmissions = <DashboardSubmission>[];

  @override
  void initState() {
    super.initState();
    final ModuleDetailModel? cached =
        widget.pathwayRepository.getCachedModuleDetails(widget.moduleId);
    if (cached != null) {
      _module = cached;
      _isLoading = false;
      if (cached.topics.isNotEmpty) {
        _expandedTopicIds.add(cached.topics.first.id);
      }
    }
    _loadModuleData();
    _loadReviews();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _challengeSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    final List<ModuleReviewModel> revs =
        await widget.pathwayRepository.getModuleReviews(widget.moduleId);
    if (mounted) {
      setState(() {
        _reviews = revs;
        _isLoadingReviews = false;
      });
    }
  }

  String _getUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadSubmissions() async {
    try {
      final String userId = _getUserId();
      final List<DashboardSubmission> subs =
          await widget.pathwayRepository.getUserSubmissions(userId);
      if (mounted) {
        setState(() {
          _userSubmissions = subs;
        });
      }
    } catch (_) {
      // Submissions fallback silently
    }
  }

  Future<void> _loadModuleData() async {
    final String userId = _getUserId();

    final ModuleDetailModel? data = await widget.pathwayRepository
        .getModuleDetails(widget.moduleId, userId);

    if (mounted) {
      setState(() {
        _module = data;
        _isLoading = false;
        if (data != null &&
            _expandedTopicIds.isEmpty &&
            data.topics.isNotEmpty) {
          _expandedTopicIds.add(data.topics.first.id);
        }
      });
    }
  }

  Future<void> _handleEnroll() async {
    final String userId = _getUserId();
    if (userId.isEmpty) {
      AppToast.showError(context, 'Please log in to enroll');
      return;
    }

    if (_module == null) return;

    final PathwayModel tempPathway = PathwayModel(
      id: _module!.id,
      title: _module!.title,
      description: _module!.description,
      language: _module!.stack.isNotEmpty ? _module!.stack.first : 'python',
      stack: _module!.stack,
      status: 'Not Started',
      completion: 0,
      totalModules: _module!.topics.length,
      currentModule:
          _module!.topics.isNotEmpty ? _module!.topics.first.title : '',
      coachName: _module!.coachName,
      coachAvatar: _module!.coachAvatar,
      price: _module!.price,
    );

    await ModulePreviewSheet.show(
      context,
      module: tempPathway,
      onEnroll: (String tier) async {
        final bool ok = await widget.pathwayRepository.enrollModule(
          userId,
          widget.moduleId,
        );
        if (ok) {
          await _loadModuleData();
          if (mounted) {
            AppToast.showSuccess(context, 'Successfully enrolled in module!');
          }
        } else {
          if (mounted) {
            AppToast.showError(context, 'Enrollment failed. Please try again.');
          }
        }
      },
    );
  }

  Future<void> _handleToggleBookmark() async {
    final String userId = _getUserId();
    if (userId.isEmpty) {
      AppToast.showError(context, 'Please log in to save bookmarks');
      return;
    }
    if (_module == null) return;

    HapticFeedback.selectionClick();
    final bool nextState = !_module!.isBookmarked;
    setState(() {
      _module = _module!.copyWith(isBookmarked: nextState);
    });

    final bool ok = await widget.pathwayRepository.toggleBookmark(
      userId,
      _module!.id,
      nextState,
    );

    if (!ok && mounted) {
      setState(() {
        _module = _module!.copyWith(isBookmarked: !nextState);
      });
      AppToast.showError(context, 'Failed to update bookmark');
    }
  }

  Future<void> _handleOpenReportSheet() async {
    final String userId = _getUserId();
    if (userId.isEmpty) {
      AppToast.showError(context, 'Please log in to report this module');
      return;
    }

    if (_module == null) return;

    await ReportModuleSheet.show(
      context,
      moduleId: _module!.id,
      moduleTitle: _module!.title,
      pathwayRepository: widget.pathwayRepository,
    );
  }

  void _handleOpenMentorProfile() {
    if (_module == null) return;
    HapticFeedback.lightImpact();
    MentorProfileSheet.show(
      context,
      coachName: _module!.coachName,
      coachAvatar: _module!.coachAvatar,
      rating: _effectiveRating,
    );
  }

  Future<void> _handlePrimaryCta() async {
    HapticFeedback.mediumImpact();
    if (_module == null) return;

    if (!_module!.isEnrolled) {
      await _handleEnroll();
      return;
    }

    // Find first unsolved practice exercise
    final ModuleActivityModel? firstUnsolved = _module!
        .allPracticeActivities
        .cast<ModuleActivityModel?>()
        .firstWhere(
          (ModuleActivityModel? a) => a != null && !a.isCompleted,
          orElse: () => _module!.allPracticeActivities.isNotEmpty
              ? _module!.allPracticeActivities.first
              : null,
        );

    if (firstUnsolved != null) {
      await context.push(
        '/modules/${widget.moduleId}/practice/${firstUnsolved.id}',
      );
      if (mounted) {
        _loadModuleData();
      }
    } else if (_module!.allChallenges.isNotEmpty) {
      final ModuleActivityModel firstCh = _module!.allChallenges.first;
      await context.push(
        '/modules/${widget.moduleId}/challenges/${firstCh.id}',
      );
      if (mounted) {
        _loadModuleData();
      }
    }
  }

  double get _effectiveRating {
    if (_reviews.isNotEmpty) {
      final double total = _reviews
          .map((ModuleReviewModel r) => r.rating)
          .reduce((int a, int b) => a + b)
          .toDouble();
      return total / _reviews.length;
    }
    return _module?.rating ?? 4.9;
  }

  Color _getDifficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildCoachAvatar(String coachName, String? coachAvatar, double radius) {
    if (coachAvatar != null && coachAvatar.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          coachAvatar,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            return _buildInitialsAvatar(coachName, radius);
          },
        ),
      );
    }
    return _buildInitialsAvatar(coachName, radius);
  }

  Widget _buildInitialsAvatar(String coachName, double radius) {
    final String initial = coachName.isNotEmpty ? coachName[0].toUpperCase() : 'M';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _cleanChallengeSummary(String raw) {
    if (raw.isEmpty) {
      return 'Implement optimal algorithmic logic matching SLA bounds.';
    }
    String cleaned = raw
        .replaceAll(RegExp(r'###\s*Problem Statement', caseSensitive: false), '')
        .replaceAll(RegExp(r'###\s*Key Requirements[\s\S]*', caseSensitive: false), '')
        .replaceAll(RegExp(r'###\s*Example[\s\S]*', caseSensitive: false), '')
        .replaceAll(RegExp(r'###\s*Constraints[\s\S]*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[*_#`\->]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'Implement optimal algorithmic logic matching SLA bounds.';
    }
    return cleaned;
  }

  List<DashboardSubmission> get _moduleSubmissions {
    if (_module == null) return const <DashboardSubmission>[];
    return _userSubmissions.where((DashboardSubmission s) {
      return s.moduleId == widget.moduleId ||
          (s.module.isNotEmpty &&
              s.module.toLowerCase() == _module!.title.toLowerCase());
    }).toList();
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
    final Color cardBg =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (_isLoading) {
      return const ModuleDetailSkeleton();
    }

    if (_module == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: textPrimary,
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Module not found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.0,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
      );
    }

    final ModuleDetailModel mod = _module!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          mod.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16.0,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              mod.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: mod.isBookmarked ? AppColors.primary : textSecondary,
            ),
            tooltip: mod.isBookmarked ? 'Remove bookmark' : 'Save module',
            onPressed: _handleToggleBookmark,
          ),
          IconButton(
            icon: Icon(
              Icons.flag_outlined,
              color: textSecondary,
              size: 20.0,
            ),
            tooltip: 'Report Module',
            onPressed: _handleOpenReportSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── HERO BANNER: MODULE IDENTITY & PROGRESS CARD (1:1 Web Parity) ──
            _buildHeroSection(
              mod: mod,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
            const SizedBox(height: 20.0),

            // ── STANDARDIZED 4 TABS NAVIGATION (Guided Practice, Challenges, Overview & Mentor, Reviews) ──
            FilterTabBar(
              height: 36.0,
              selectedId: _selectedTab,
              onTabSelected: (String tabId) {
                setState(() {
                  _selectedTab = tabId;
                });
              },
              tabs: <FilterTabItem>[
                FilterTabItem(
                  id: 'practice',
                  label: 'Guided Practice',
                  count: mod.allPracticeActivities.length,
                ),
                FilterTabItem(
                  id: 'challenges',
                  label: 'Challenges',
                  count: mod.allChallenges.length,
                ),
                const FilterTabItem(
                  id: 'overview',
                  label: 'Overview & Mentor',
                  // No count badge per Web 1:1
                ),
                FilterTabItem(
                  id: 'reviews',
                  label: 'Reviews',
                  count: _reviews.length,
                ),
              ],
            ),
            const SizedBox(height: 18.0),

            // ── TAB CONTENT ──
            if (_selectedTab == 'practice')
              _buildPracticeView(
                mod: mod,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                cardBg: cardBg,
                borderColor: borderColor,
              )
            else if (_selectedTab == 'challenges')
              _buildChallengesView(
                mod: mod,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                cardBg: cardBg,
                borderColor: borderColor,
              )
            else if (_selectedTab == 'overview')
              _buildOverviewView(
                mod: mod,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                cardBg: cardBg,
                borderColor: borderColor,
              )
            else if (_selectedTab == 'reviews')
              _buildReviewsView(
                mod: mod,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                cardBg: cardBg,
                borderColor: borderColor,
              ),

            const SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO SECTION: IDENTITY & EMBEDDED PROGRESS CARD (1:1 Web Parity)
  // ===========================================================================
  Widget _buildHeroSection({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    final int completion = mod.practiceCompletionPercentage;
    final int totalSolved = mod.solvedPracticeCount;
    final int totalExercises = mod.totalPracticeCount;

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Row 1: Language Avatar Stack
          LanguageAvatarStack(
            languages: mod.stack.isNotEmpty ? mod.stack : <String>['python'],
            size: 34.0,
          ),
          const SizedBox(height: 14.0),

          // Title & Description
          Text(
            mod.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            mod.description.trim().isNotEmpty
                ? mod.description.trim()
                : 'Master core concepts and hands-on coding challenges with real-time feedback.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12.0),

          // Author Chip & Star Rating (Tappable Mentor Profile)
          InkWell(
            onTap: _handleOpenMentorProfile,
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: <Widget>[
                  _buildCoachAvatar(mod.coachName, mod.coachAvatar, 11.0),
                  const SizedBox(width: 7.0),
                  Text(
                    'By ${mod.coachName}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    '•',
                    style: TextStyle(color: textSecondary),
                  ),
                  const SizedBox(width: 8.0),
                  const Icon(
                    Icons.star_rounded,
                    size: 15.0,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 3.0),
                  Text(
                    _effectiveRating.toStringAsFixed(1),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    '(${_reviews.length} ${_reviews.length == 1 ? "review" : "reviews"})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // ── PROGRESS & PRIMARY CTA EMBEDDED CARD ──
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Progress Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'MODULE PROGRESS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '$totalSolved/$totalExercises Solved',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Percentage and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      '$completion%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22.0,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      completion == 100
                          ? 'Mastered'
                          : completion > 0
                              ? 'In Progress'
                              : 'Not Started',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: completion == 100
                            ? const Color(0xFF10B981)
                            : textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // Strict 0% progress bar per AGENTS.md rule 2.3
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: completion > 0 ? (completion / 100.0).clamp(0.0, 1.0) : 0.0,
                    minHeight: 6.0,
                    backgroundColor: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completion == 100
                          ? const Color(0xFF10B981)
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Primary CTA button per AGENTS.md rule 1.2
                SizedBox(
                  width: double.infinity,
                  height: 42.0,
                  child: ElevatedButton(
                    onPressed: _handlePrimaryCta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor:
                          isDark ? AppColors.onPrimaryDark : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          completion == 100
                              ? Icons.check_circle_rounded
                              : Icons.play_arrow_rounded,
                          size: 16.0,
                          color: completion == 100
                              ? const Color(0xFF10B981)
                              : null,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          completion == 100
                              ? 'Review Module'
                              : completion > 0
                                  ? 'Continue Learning'
                                  : 'Start Learning',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. GUIDED PRACTICE TAB (Milestone Topics + Exercises)
  // ===========================================================================
  Widget _buildPracticeView({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    if (mod.topics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18.0),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: <Widget>[
            Text(
              'No practice topics found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'This module does not contain any published practice exercises yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                color: textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mod.topics.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12.0),
      itemBuilder: (BuildContext context, int index) {
        final ModuleTopicModel topic = mod.topics[index];
        final bool isExpanded = _expandedTopicIds.contains(topic.id);
        final String orderStr = (index + 1).toString().padLeft(2, '0');

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Topic Header Trigger
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isExpanded) {
                      _expandedTopicIds.remove(topic.id);
                    } else {
                      _expandedTopicIds.add(topic.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(18.0),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    children: <Widget>[
                      // Number Badge
                      Container(
                        width: 32.0,
                        height: 32.0,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          orderStr,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w800,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),

                      // Title & Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              topic.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            if (topic.description.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2.0),
                              Text(
                                topic.description,
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
                      const SizedBox(width: 8.0),

                      // Solved Badge
                      if (topic.totalCount > 0) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: topic.isFullyCompleted
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: topic.isFullyCompleted
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : borderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (topic.isFullyCompleted) ...<Widget>[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 12.0,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  'Completed',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ] else ...<Widget>[
                                Text(
                                  '${topic.solvedCount} / ${topic.totalCount} Solved',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8.0),
                      ],

                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Smooth Accordion Expansion
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0.0),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Divider(height: 1.0, color: borderColor),
                    if (topic.practiceActivities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Text(
                          'Guided practice exercises & code sandbox.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12.0),
                        itemCount: topic.practiceActivities.length,
                        separatorBuilder: (BuildContext context, int i) =>
                            const SizedBox(height: 8.0),
                        itemBuilder: (BuildContext context, int i) {
                          final ModuleActivityModel act =
                              topic.practiceActivities[i];
                          final bool isSolved = act.isCompleted;

                          return InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              if (!mod.isEnrolled) {
                                await _handleEnroll();
                              } else {
                                await context.push(
                                  '/modules/${widget.moduleId}/practice/${act.id}',
                                );
                                if (mounted) {
                                  _loadModuleData();
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(12.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                                vertical: 11.0,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurfaceCard,
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    isSolved
                                        ? Icons.check_circle_rounded
                                        : !mod.isEnrolled
                                            ? Icons.lock_outline_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                    size: 16.0,
                                    color: isSolved
                                        ? const Color(0xFF10B981)
                                        : !mod.isEnrolled
                                            ? textSecondary.withValues(alpha: 0.6)
                                            : textSecondary.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Text(
                                      act.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.0,
                                        fontWeight: isSolved
                                            ? FontWeight.w600
                                            : FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        isSolved ? 'Review' : 'Solve',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w700,
                                          color: isSolved
                                              ? const Color(0xFF10B981)
                                              : AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 3.0),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 13.0,
                                        color: isSolved
                                            ? const Color(0xFF10B981)
                                            : AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 240),
                sizeCurve: Curves.easeInOutCubic,
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 2. CHALLENGES TAB (Algorithmic Benchmarks, SLA Targets & Submissions)
  // ===========================================================================
  Widget _buildChallengesView({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    final List<ModuleActivityModel> allChallenges = mod.allChallenges;
    final List<DashboardSubmission> modSubmissions = _moduleSubmissions;

    final List<ModuleActivityModel> filteredChallenges = allChallenges.where((
      ModuleActivityModel ch,
    ) {
      if (_challengeFilter == 'easy' && ch.difficulty.toLowerCase() != 'easy') {
        return false;
      }
      if (_challengeFilter == 'medium' && ch.difficulty.toLowerCase() != 'medium') {
        return false;
      }
      if (_challengeFilter == 'hard' && ch.difficulty.toLowerCase() != 'hard') {
        return false;
      }
      if (_challengeFilter == 'unsolved' && ch.isCompleted) {
        return false;
      }
      if (_challengeSearchQuery.isNotEmpty) {
        final String q = _challengeSearchQuery.toLowerCase();
        final bool matchesTitle = ch.title.toLowerCase().contains(q);
        final bool matchesDesc = ch.description.toLowerCase().contains(q);
        if (!matchesTitle && !matchesDesc) return false;
      }
      return true;
    }).toList();

    final List<DashboardSubmission> filteredSubmissions = modSubmissions.where((
      DashboardSubmission s,
    ) {
      if (_challengeSearchQuery.isNotEmpty) {
        final String q = _challengeSearchQuery.toLowerCase();
        final bool matchesTitle = s.title.toLowerCase().contains(q);
        final bool matchesLang = s.language.toLowerCase().contains(q);
        if (!matchesTitle && !matchesLang) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Search Box (matching Web)
        Container(
          height: 40.0,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: <Widget>[
              Icon(Icons.search_rounded, size: 18.0, color: textSecondary),
              const SizedBox(width: 8.0),
              Expanded(
                child: TextField(
                  controller: _challengeSearchController,
                  onChanged: (String val) {
                    setState(() {
                      _challengeSearchQuery = val;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: _challengeFilter == 'submissions'
                        ? 'Search submissions...'
                        : 'Search challenges...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: textSecondary.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_challengeSearchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _challengeSearchController.clear();
                    setState(() {
                      _challengeSearchQuery = '';
                    });
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 16.0,
                    color: textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        // Sub-filter tabs (All, Easy, Medium, Hard, Unsolved, My Submissions)
        FilterTabBar(
          height: 36.0,
          selectedId: _challengeFilter,
          onTabSelected: (String id) {
            setState(() {
              _challengeFilter = id;
            });
          },
          tabs: <FilterTabItem>[
            FilterTabItem(
              id: 'all',
              label: 'All Challenges',
              count: allChallenges.length,
            ),
            FilterTabItem(
              id: 'easy',
              label: 'Easy',
              count: allChallenges.where((c) => c.difficulty.toLowerCase() == 'easy').length,
            ),
            FilterTabItem(
              id: 'medium',
              label: 'Medium',
              count: allChallenges.where((c) => c.difficulty.toLowerCase() == 'medium').length,
            ),
            FilterTabItem(
              id: 'hard',
              label: 'Hard',
              count: allChallenges.where((c) => c.difficulty.toLowerCase() == 'hard').length,
            ),
            FilterTabItem(
              id: 'unsolved',
              label: 'Unsolved',
              count: allChallenges.where((c) => !c.isCompleted).length,
            ),
            FilterTabItem(
              id: 'submissions',
              label: 'My Submissions',
              count: modSubmissions.length,
            ),
          ],
        ),
        const SizedBox(height: 16.0),

        // Display Submissions or Challenges List
        if (_challengeFilter == 'submissions')
          if (filteredSubmissions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18.0),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                'No submissions recorded yet.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredSubmissions.length,
              separatorBuilder: (BuildContext context, int i) =>
                  const SizedBox(height: 10.0),
              itemBuilder: (BuildContext context, int i) {
                final DashboardSubmission sub = filteredSubmissions[i];
                return InkWell(
                  onTap: () => _openSubmissionAuditSheet(sub),
                  borderRadius: BorderRadius.circular(14.0),
                  child: Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${i + 1}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                sub.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              Row(
                                children: <Widget>[
                                  LanguageIcon(language: sub.language, size: 14.0),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    sub.language,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.0,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text('·', style: TextStyle(color: textSecondary)),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    sub.timeAgoFormatted,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.0,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 12.0,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                'Accepted',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
        else
          if (filteredChallenges.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18.0),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                'No challenges found matching your filter criteria.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredChallenges.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 12.0),
              itemBuilder: (BuildContext context, int index) {
                final ModuleActivityModel ch = filteredChallenges[index];
                final Color diffColor = _getDifficultyColor(ch.difficulty);

                return Container(
                  padding: const EdgeInsets.all(15.0),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7.0,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: diffColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Text(
                                  ch.difficulty.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    color: diffColor,
                                  ),
                                ),
                              ),
                              if (ch.isCompleted) ...<Widget>[
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7.0,
                                    vertical: 2.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Text(
                                    'Solved',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Time: ${ch.timeSla} · Space: ${ch.spaceSla}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        ch.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        _cleanChallengeSummary(ch.description),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          color: textSecondary,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14.0),
                      SizedBox(
                        width: double.infinity,
                        height: 40.0,
                        child: ElevatedButton(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            if (!mod.isEnrolled) {
                              await _handleEnroll();
                            } else {
                              await context.push(
                                '/modules/${widget.moduleId}/challenges/${ch.id}',
                              );
                              if (mounted) {
                                _loadModuleData();
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF1F5F9),
                            foregroundColor: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              side: BorderSide(color: borderColor),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                ch.isCompleted
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.code_rounded,
                                size: 16.0,
                                color: ch.isCompleted
                                    ? const Color(0xFF10B981)
                                    : null,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                ch.isCompleted
                                    ? 'Review Challenge'
                                    : 'Solve Challenge',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: ch.isCompleted
                                      ? const Color(0xFF10B981)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }

  // ===========================================================================
  // 3. OVERVIEW & MENTOR TAB (About, 2x2 Bento & Instructor Profile)
  // ===========================================================================
  Widget _buildOverviewView({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Card 1: About this Module & 2x2 Bento
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'About this Module',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                mod.description.trim().isNotEmpty
                    ? mod.description.trim()
                    : 'Master core programming concepts, hands-on challenges, and guided exercises with real-time feedback.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16.0),
              Divider(height: 1.0, color: borderColor),
              const SizedBox(height: 16.0),

              Text(
                'WHAT YOU\'LL PRACTICE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12.0),

              // 2x2 Bento Grid
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _buildBentoCard(
                      title: 'In-Browser IDE',
                      desc: 'Live compile, unit tests, and terminal feedback',
                      icon: Icons.code_rounded,
                      isDark: isDark,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: _buildBentoCard(
                      title: 'AI Code Tutor',
                      desc: 'Socratic hints and syntax recommendations',
                      icon: Icons.auto_awesome_rounded,
                      isDark: isDark,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _buildBentoCard(
                      title: 'SLA Benchmarks',
                      desc: 'Time & memory performance constraints',
                      icon: Icons.speed_rounded,
                      isDark: isDark,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: _buildBentoCard(
                      title: 'Progress Tracking',
                      desc: 'Auto-saved code submissions and activity history',
                      icon: Icons.insights_rounded,
                      isDark: isDark,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Card 2: Instructor Profile Card
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildCoachAvatar(mod.coachName, mod.coachAvatar, 24.0),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          mod.coachName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          'Senior Staff Architect & Technical Educator',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.star_rounded,
                              size: 14.0,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 3.0),
                            Text(
                              _effectiveRating.toStringAsFixed(1),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Text('•', style: TextStyle(color: textSecondary)),
                            const SizedBox(width: 6.0),
                            Text(
                              'Verified Mentor',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              Text(
                '10+ years designing fault-tolerant distributed systems and architectures. Mentoring developers worldwide with battle-tested production blueprints.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14.0),

              // Expertise Badges
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: <String>[
                  'Architecture',
                  'Algorithms',
                  'SLA Optimization',
                  'System Design',
                ].map((String skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      skill,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16.0),

              // View Full Profile Button
              SizedBox(
                width: double.infinity,
                height: 40.0,
                child: OutlinedButton(
                  onPressed: _handleOpenMentorProfile,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: Text(
                    'View Full Mentor Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(icon, size: 16.0, color: AppColors.primary),
          ),
          const SizedBox(height: 8.0),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            desc,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. REVIEWS TAB (Overall Metrics, Distribution & Verified Reviews)
  // ===========================================================================
  Widget _buildReviewsView({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    final double avgRating = _effectiveRating;
    final int count = _reviews.length;
    final int positiveCount = _reviews.where((r) => r.rating >= 4).length;
    final int recommendPct = count > 0 ? ((positiveCount / count) * 100).round() : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Overview Header Card (1:1 Web Parity)
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Overall Rating Score
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'OVERALL RATING',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 32.0,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              '/ 5.0',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.0,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: <Widget>[
                            for (int s = 1; s <= 5; s++)
                              Icon(
                                s <= avgRating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 16.0,
                                color: s <= avgRating.round()
                                    ? const Color(0xFFFBBF24)
                                    : textSecondary.withValues(alpha: 0.3),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Based on $count verified ${count == 1 ? "review" : "reviews"}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recommendation %
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          'RECOMMENDED',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '$recommendPct%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 22.0,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Rating Distribution Breakdown (5★ to 1★)
              Column(
                children: <int>[5, 4, 3, 2, 1].map((int stars) {
                  final int starCount =
                      _reviews.where((r) => r.rating == stars).length;
                  final double pct =
                      count > 0 ? (starCount / count).clamp(0.0, 1.0) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 28.0,
                          child: Text(
                            '$stars★',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3.0),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5.0,
                              backgroundColor: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        SizedBox(
                          width: 20.0,
                          child: Text(
                            '$starCount',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.0,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16.0),

              // Write a Review Button
              SizedBox(
                width: double.infinity,
                height: 40.0,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final String userId = _getUserId();
                    if (userId.isEmpty) {
                      AppToast.showError(
                        context,
                        'Please log in to write a review',
                      );
                      return;
                    }
                    final bool? submitted = await ModuleReviewModal.show(
                      context,
                      moduleTitle: mod.title,
                      onSubmitReview: (int rating, String comment) async {
                        return await widget.pathwayRepository.submitModuleReview(
                          moduleId: widget.moduleId,
                          userId: userId,
                          rating: rating,
                          comment: comment,
                        );
                      },
                    );
                    if (submitted == true && mounted) {
                      AppToast.showSuccess(context, 'Review posted!');
                      _loadReviews();
                    }
                  },
                  icon: const Icon(Icons.rate_review_outlined, size: 16.0),
                  label: Text(
                    'Write a Review',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor:
                        isDark ? AppColors.onPrimaryDark : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18.0),

        // Reviews List or Empty State
        if (_isLoadingReviews)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            ),
          )
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 26.0,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Be the first learner to complete this module and share your feedback! Your review helps other developers discover this learning pathway.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    color: textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            separatorBuilder: (BuildContext context, int i) =>
                const SizedBox(height: 10.0),
            itemBuilder: (BuildContext context, int i) {
              final ModuleReviewModel rev = _reviews[i];
              final String initials = rev.userName
                  .split(' ')
                  .where((String p) => p.isNotEmpty)
                  .map((String p) => p[0])
                  .take(2)
                  .join('')
                  .toUpperCase();

              return Container(
                padding: const EdgeInsets.all(15.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 30.0,
                              height: 30.0,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials.isEmpty ? 'U' : initials,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  rev.userName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  rev.createdAt,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.0,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            for (int s = 1; s <= 5; s++)
                              Icon(
                                s <= rev.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 14.0,
                                color: s <= rev.rating
                                    ? const Color(0xFFFBBF24)
                                    : borderColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      '“${rev.comment}”',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ===========================================================================
  // SUBMISSION AUDIT MODAL SHEET (Matching Web Dialog lines 1990-2057)
  // ===========================================================================
  void _openSubmissionAuditSheet(DashboardSubmission sub) {
    HapticFeedback.selectionClick();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color surfaceColor =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
            border: Border.all(color: borderColor),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                    width: 36.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    sub.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7.0,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.0),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 11.0,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 3.0),
                                      Text(
                                        'Accepted',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3.0),
                            Text(
                              '${sub.language} · Submitted ${sub.timeAgoFormatted}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.0,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1.0, color: borderColor),

                // Code and evaluation
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'SUBMITTED CODE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: SelectableText(
                            sub.code.isNotEmpty
                                ? sub.code
                                : '// Optimal algorithmic solution executed successfully\n// Target SLA constraint verified.',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.0,
                              color: const Color(0xFFE2E8F0),
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // Mentor feedback / tips if available
                        if (sub.feedbackTips.isNotEmpty || sub.verdict.isNotEmpty) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.all(14.0),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Padding(
                                  padding: EdgeInsets.only(top: 2.0),
                                  child: Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 16.0,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Mentor Evaluation',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3.0),
                                      Text(
                                        sub.verdict.isNotEmpty
                                            ? sub.verdict
                                            : sub.feedbackTips.join(' '),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.0,
                                          color: textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18.0),
                        ],

                        // Close button
                        SizedBox(
                          width: double.infinity,
                          height: 42.0,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor:
                                  isDark ? AppColors.onPrimaryDark : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
