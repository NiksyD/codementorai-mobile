import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/module_detail_model.dart';
import '../domain/module_review_model.dart';
import '../domain/pathway_model.dart';
import 'widgets/module_detail_skeleton.dart';
import 'widgets/module_preview_sheet.dart';
import 'widgets/module_review_modal.dart';

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
  String _selectedTab = 'practice'; // 'practice' or 'challenges'
  String _challengeFilter = 'all'; // 'all', 'easy', 'medium', 'hard'
  final Set<String> _expandedTopicIds = <String>{};
  List<ModuleReviewModel> _reviews = <ModuleReviewModel>[];
  bool _isLoadingReviews = false;

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

  Future<void> _loadModuleData() async {
    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
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
    );

    await ModulePreviewSheet.show(
      context,
      module: tempPathway,
      onEnroll: (String tier) async {
        final bool ok = await widget.pathwayRepository.enrollModule(
          user.id,
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
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
      user.id,
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

  Color _getDifficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return const Color(0xFF3ECF8E);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return AppColors.primary;
    }
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
    final List<ModuleActivityModel> allChallenges = mod.allChallenges;
    final List<ModuleActivityModel> filteredChallenges = allChallenges.where((
      ModuleActivityModel ch,
    ) {
      if (_challengeFilter == 'easy') return ch.difficulty.toLowerCase() == 'easy';
      if (_challengeFilter == 'medium') return ch.difficulty.toLowerCase() == 'medium';
      if (_challengeFilter == 'hard') return ch.difficulty.toLowerCase() == 'hard';
      return true;
    }).toList();

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
            onPressed: _handleToggleBookmark,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // ── SEGMENTED SUB-NAV 2-TAB CONTROL (1:1 Web Parity) ──
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: <Widget>[
                // Tab 1: Practice
                _buildSubNavTab(
                  id: 'practice',
                  label: 'Practice',
                  count: mod.topics.length,
                  isSelected: _selectedTab == 'practice',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(width: 16.0),
                // Tab 2: Challenges
                _buildSubNavTab(
                  id: 'challenges',
                  label: 'Challenges',
                  count: allChallenges.length,
                  isSelected: _selectedTab == 'challenges',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),
          ),

          // ── MAIN TAB VIEW CONTENT ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              physics: const BouncingScrollPhysics(),
              child: _selectedTab == 'practice'
                  ? _buildPracticeView(
                      mod: mod,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    )
                  : _buildChallengesView(
                      challenges: filteredChallenges,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      cardBg: cardBg,
                      borderColor: borderColor,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavTab({
    required String id,
    required String label,
    required int count,
    required bool isSelected,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTab = id;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : textSecondary,
              ),
            ),
            const SizedBox(width: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primary : textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. PRACTICE VIEW (Milestone Topics + Exercises)
  // ===========================================================================
  Widget _buildPracticeView({
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
        // Hero Module Banner
        Container(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  LanguageAvatarStack(
                    languages:
                        mod.stack.isNotEmpty ? mod.stack : <String>['python'],
                    size: 30.0,
                  ),
                  if (mod.isEnrolled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${mod.completion}% Complete',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        'Not Enrolled',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                mod.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5.0),
              Text(
                mod.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14.0),

              if (mod.isEnrolled) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: (mod.completion / 100.0).clamp(0.0, 1.0),
                    minHeight: 5.0,
                    backgroundColor: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 13.0,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: mod.coachAvatar != null
                            ? NetworkImage(mod.coachAvatar!)
                            : NetworkImage(
                                'https://api.dicebear.com/7.x/avataaars/png?seed=${mod.coachName}',
                              ) as ImageProvider,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'by ${mod.coachName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.star_rounded,
                        size: 15.0,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 2.0),
                      Text(
                        '5.0',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (!mod.isEnrolled) ...<Widget>[
                const SizedBox(height: 16.0),
                SizedBox(
                  width: double.infinity,
                  height: 44.0,
                  child: ElevatedButton(
                    onPressed: _handleEnroll,
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
                        Text(
                          'Enroll to Start Learning',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20.0),

        // Section Title: Topic Pathways
        Text(
          'Topic Pathways',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15.0,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12.0),

        // Topics Accordion List
        if (mod.topics.isEmpty)
          Container(
            padding: const EdgeInsets.all(22.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              'Topics are being prepared by mentor.',
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
                            Container(
                              width: 28.0,
                              height: 28.0,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                orderStr,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
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
                          const Divider(height: 1.0),
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
                              separatorBuilder:
                                  (BuildContext context, int i) =>
                                      const SizedBox(height: 8.0),
                              itemBuilder: (BuildContext context, int i) {
                                final ModuleActivityModel act =
                                    topic.practiceActivities[i];
                                return InkWell(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    await context.push(
                                      '/modules/${widget.moduleId}/practice/${act.id}',
                                    );
                                    if (mounted) {
                                      _loadModuleData();
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
                                          ? const Color(0xFF161E2E)
                                          : AppColors.lightSurfaceCard,
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          act.isCompleted
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked_rounded,
                                          size: 16.0,
                                          color: act.isCompleted
                                              ? const Color(0xFF3ECF8E)
                                              : textSecondary
                                                  .withValues(alpha: 0.4),
                                        ),
                                        const SizedBox(width: 12.0),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                act.title,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 13.0,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2.0),
                                              Text(
                                                'GUIDED PRACTICE · CODE SANDBOX',
                                                style:
                                                    GoogleFonts.jetBrainsMono(
                                                  fontSize: 9.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 12.0,
                                          color: textSecondary
                                              .withValues(alpha: 0.5),
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
          ),
        _buildReviewsSection(
          mod: mod,
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
          borderColor: borderColor,
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. CHALLENGES VIEW (Algorithmic Benchmarks + SLA Targets)
  // ===========================================================================
  Widget _buildChallengesView({
    required List<ModuleActivityModel> challenges,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Difficulty Filter Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: <Widget>[
              _buildChallengeFilterPill('all', 'All', isDark, textSecondary),
              const SizedBox(width: 8.0),
              _buildChallengeFilterPill('easy', 'Easy', isDark, textSecondary),
              const SizedBox(width: 8.0),
              _buildChallengeFilterPill('medium', 'Medium', isDark, textSecondary),
              const SizedBox(width: 8.0),
              _buildChallengeFilterPill('hard', 'Hard', isDark, textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        if (challenges.isEmpty)
          Container(
            padding: const EdgeInsets.all(28.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              'No challenges found matching filter.',
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
            itemCount: challenges.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12.0),
            itemBuilder: (BuildContext context, int index) {
              final ModuleActivityModel ch = challenges[index];
              final Color diffColor = _getDifficultyColor(ch.difficulty);

              return Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            ch.difficulty,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w700,
                              color: diffColor,
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            Text(
                              'Target: ${ch.timeSla} time · ${ch.spaceSla} space',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
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
                      height: 42.0,
                      child: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await context.push(
                            '/modules/${widget.moduleId}/challenges/${ch.id}',
                          );
                          if (mounted) {
                            _loadModuleData();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          foregroundColor: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            side: BorderSide(color: borderColor),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.code_rounded,
                              size: 16.0,
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              'Solve Challenge',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
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

  Widget _buildChallengeFilterPill(
    String id,
    String label,
    bool isDark,
    Color textSecondary,
  ) {
    final bool isSelected = _challengeFilter == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _challengeFilter = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? AppColors.onPrimaryDark : Colors.white)
                : textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    final double avgRating = _reviews.isNotEmpty
        ? _reviews.map((ModuleReviewModel r) => r.rating).reduce((int a, int b) => a + b) / _reviews.length
        : mod.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24.0),
        Divider(color: borderColor, height: 1.0),
        const SizedBox(height: 20.0),

        // Reviews Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Learner Reviews',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                if (_reviews.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.star_rounded, size: 13.0, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 3.0),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            TextButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  AppToast.showError(context, 'Please log in to write a review');
                  return;
                }
                final bool? submitted = await ModuleReviewModal.show(
                  context,
                  moduleTitle: mod.title,
                  onSubmitReview: (int rating, String comment) async {
                    return await widget.pathwayRepository.submitModuleReview(
                      moduleId: widget.moduleId,
                      userId: user.id,
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
              icon: const Icon(Icons.rate_review_outlined, size: 15.0, color: AppColors.primary),
              label: Text(
                'Write a Review',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14.0),

        if (_isLoadingReviews)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            ),
          )
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.star_outline_rounded,
                  size: 28.0,
                  color: textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  'Be the first learner to complete this module and leave feedback!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: textSecondary,
                    height: 1.35,
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
            separatorBuilder: (BuildContext context, int i) => const SizedBox(height: 10.0),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 28.0,
                              height: 28.0,
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
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Text(
                              rev.userName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            for (int s = 1; s <= 5; s++)
                              Icon(
                                s <= rev.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 14.0,
                                color: s <= rev.rating ? const Color(0xFFFBBF24) : borderColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '“${rev.comment}”',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      rev.createdAt,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.0,
                        color: textSecondary.withValues(alpha: 0.6),
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
}
