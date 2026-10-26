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
import 'widgets/mentor_profile_sheet.dart';
import 'widgets/module_detail_skeleton.dart';
import 'widgets/module_preview_sheet.dart';
import 'widgets/module_review_modal.dart';

class _DisplayTopic {
  const _DisplayTopic({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.activities,
  });

  final String id;
  final int number;
  final String title;
  final String description;
  final List<ModuleActivityModel> activities;

  int get solvedCount =>
      activities.where((ModuleActivityModel a) => a.isCompleted).length;

  int get totalCount => activities.length;

  bool get isCompleted =>
      totalCount > 0 && solvedCount == totalCount;
}

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

  final Set<String> _expandedTopicIds = <String>{};
  bool _hasInitializedAccordion = false;
  List<ModuleReviewModel> _reviews = <ModuleReviewModel>[];

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final ModuleDetailModel? cached =
        widget.pathwayRepository.getCachedModuleDetails(widget.moduleId);
    if (cached != null) {
      _module = cached;
      _isLoading = false;
      _initializeExpandedTopics(cached);
    }
    _loadModuleData();
    _loadReviews();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeExpandedTopics(ModuleDetailModel mod) {
    if (_hasInitializedAccordion) return;
    final List<_DisplayTopic> topics = _getDisplayTopicsForModule(mod);
    if (topics.isEmpty) return;

    final _DisplayTopic active = topics.firstWhere(
      (_DisplayTopic t) => t.activities.any((ModuleActivityModel a) => !a.isCompleted),
      orElse: () => topics.first,
    );
    _expandedTopicIds.add(active.id);
    _hasInitializedAccordion = true;
  }

  String _getUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadReviews() async {
    final List<ModuleReviewModel> revs =
        await widget.pathwayRepository.getModuleReviews(widget.moduleId);
    if (mounted) {
      setState(() {
        _reviews = revs;
      });
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
        if (data != null) {
          _initializeExpandedTopics(data);
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

  Future<void> _handleOpenReviewModal() async {
    HapticFeedback.lightImpact();
    final String userId = _getUserId();
    if (userId.isEmpty) {
      AppToast.showError(
        context,
        'Please log in to write a review',
      );
      return;
    }
    if (_module == null) return;

    final bool? submitted = await ModuleReviewModal.show(
      context,
      moduleTitle: _module!.title,
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
  }

  void _scrollToReviews() {
    HapticFeedback.selectionClick();
    final BuildContext? targetCtx = _reviewsKey.currentContext;
    if (targetCtx != null) {
      Scrollable.ensureVisible(
        targetCtx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _navigateToActivity(ModuleActivityModel act) async {
    HapticFeedback.lightImpact();
    if (_module == null) return;

    if (!_module!.isEnrolled) {
      await _handleEnroll();
      return;
    }

    if (act.category == 'challenge') {
      await context.push(
        '/modules/${widget.moduleId}/challenges/${act.id}',
      );
    } else {
      await context.push(
        '/modules/${widget.moduleId}/practice/${act.id}',
      );
    }

    if (mounted) {
      _loadModuleData();
    }
  }

  Future<void> _handlePrimaryCta() async {
    HapticFeedback.mediumImpact();
    if (_module == null) return;

    if (!_module!.isEnrolled) {
      await _handleEnroll();
      return;
    }

    // Find first unsolved activity across all display topics
    ModuleActivityModel? firstUnsolved;
    for (final _DisplayTopic t in _displayTopics) {
      for (final ModuleActivityModel a in t.activities) {
        if (!a.isCompleted) {
          firstUnsolved = a;
          break;
        }
      }
      if (firstUnsolved != null) break;
    }

    // Fallback to first activity if all solved
    final ModuleActivityModel? target = firstUnsolved ??
        (_displayTopics.isNotEmpty && _displayTopics.first.activities.isNotEmpty
            ? _displayTopics.first.activities.first
            : null);

    if (target != null) {
      await _navigateToActivity(target);
    }
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/learn/modules');
    }
  }

  List<_DisplayTopic> _getDisplayTopicsForModule(ModuleDetailModel mod) {
    final List<_DisplayTopic> list = <_DisplayTopic>[];
    for (int i = 0; i < mod.topics.length; i++) {
      final ModuleTopicModel topic = mod.topics[i];
      list.add(_DisplayTopic(
        id: topic.id,
        number: i + 1,
        title: topic.title,
        description: topic.description,
        activities: topic.activities,
      ));
    }

    // Include standalone benchmark challenges if they are not in any topic
    final Set<String> existingActIds = <String>{};
    for (final ModuleTopicModel t in mod.topics) {
      for (final ModuleActivityModel a in t.activities) {
        existingActIds.add(a.id);
      }
    }

    final List<ModuleActivityModel> standaloneChallenges = mod.challenges
        .where((ModuleActivityModel c) => !existingActIds.contains(c.id))
        .toList();

    if (standaloneChallenges.isNotEmpty) {
      list.add(_DisplayTopic(
        id: 'topic-benchmark-challenges',
        number: list.length + 1,
        title: 'Benchmark Challenges',
        description: 'Algorithmic benchmark challenges and performance SLAs.',
        activities: standaloneChallenges,
      ));
    }

    return list;
  }

  List<_DisplayTopic> get _displayTopics {
    if (_module == null) return const <_DisplayTopic>[];
    return _getDisplayTopicsForModule(_module!);
  }

  _DisplayTopic? get _activeUnsolvedTopic {
    final List<_DisplayTopic> list = _displayTopics;
    if (list.isEmpty) return null;
    return list.firstWhere(
      (_DisplayTopic t) => t.activities.any((ModuleActivityModel a) => !a.isCompleted),
      orElse: () => list.first,
    );
  }

  int get _totalSolvedExercises {
    int count = 0;
    for (final _DisplayTopic t in _displayTopics) {
      count += t.activities.where((ModuleActivityModel a) => a.isCompleted).length;
    }
    return count;
  }

  int get _totalExercises {
    int count = 0;
    for (final _DisplayTopic t in _displayTopics) {
      count += t.activities.length;
    }
    return count;
  }

  int get _completionPercentage {
    final int total = _totalExercises;
    if (total == 0) return _module?.completion ?? 0;
    return ((_totalSolvedExercises / total) * 100).round();
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

  String _cleanChallengeSummary(String raw) {
    if (raw.isEmpty) {
      return 'Implement optimal algorithmic logic matching SLA bounds.';
    }
    String cleaned = raw
        .replaceAll(RegExp(r'###\s*Problem Statement:?', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'###\s*Key Requirements[\s\S]*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'###\s*Example[\s\S]*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'###\s*Constraints[\s\S]*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[*_#`\->]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'Implement optimal algorithmic logic matching SLA bounds.';
    }
    return cleaned;
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
        color: AppColors.primary.withValues(alpha: 0.18),
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

  void _toggleExpandAll() {
    HapticFeedback.selectionClick();
    setState(() {
      final List<_DisplayTopic> list = _displayTopics;
      if (_expandedTopicIds.length == list.length) {
        _expandedTopicIds.clear();
      } else {
        _expandedTopicIds.clear();
        _expandedTopicIds.addAll(list.map((_DisplayTopic t) => t.id));
      }
    });
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
        isDark ? AppColors.darkSurface : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (_isLoading) {
      return const ModuleDetailSkeleton();
    }

    if (_module == null) {
      return PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            context.go('/learn/modules');
          }
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: textPrimary,
              onPressed: _handleBack,
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
        ),
      );
    }

    final ModuleDetailModel mod = _module!;
    final List<_DisplayTopic> topics = _displayTopics;
    final bool isAllExpanded = topics.isNotEmpty && _expandedTopicIds.length == topics.length;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          context.go('/learn/modules');
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: textPrimary,
            onPressed: _handleBack,
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
            const SizedBox(width: 4.0),
          ],
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── HERO BANNER: SPLIT-BLOCK ARCHETYPE (Matching Web 1:1) ──
              _buildSplitBlockHero(
                mod: mod,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              const SizedBox(height: 24.0),

              // ── MODULE OUTLINE (Unified Hollow Topics & Progression) ──
              _buildModuleOutline(
                topics: topics,
                isAllExpanded: isAllExpanded,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              const SizedBox(height: 28.0),

              // ── MODULE REVIEWS & RATINGS (Matching Web 1:1) ──
              Container(
                key: _reviewsKey,
                child: _buildLearnerReviewsSection(
                  mod: mod,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  cardBg: cardBg,
                  borderColor: borderColor,
                ),
              ),

              const SizedBox(height: 40.0),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. SPLIT-BLOCK HERO BANNER (Left Context + Right Action in Single Card)
  // ===========================================================================
  Widget _buildSplitBlockHero({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    final int completion = _completionPercentage;
    final int totalSolved = _totalSolvedExercises;
    final int totalExercises = _totalExercises;
    final _DisplayTopic? activeTopic = _activeUnsolvedTopic;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(color: borderColor.withValues(alpha: isDark ? 0.35 : 0.6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── UPPER CONTEXT: Identity, Tech Stack, Mentor & Ratings ──
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Row 1: "MODULE" pill + LanguageAvatarStack + Action Utilities
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'MODULE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        LanguageAvatarStack(
                          languages: mod.stack.isNotEmpty
                              ? mod.stack
                              : <String>['python'],
                          size: 26.0,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),

                // Title
                Text(
                  mod.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6.0),

                // Description
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
                const SizedBox(height: 14.0),

                // Meta Row: Mentor Avatar & Name • Rating Chip • Price
                Container(
                  padding: const EdgeInsets.only(top: 12.0),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: borderColor.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8.0,
                    runSpacing: 6.0,
                    children: <Widget>[
                      // Mentor Chip
                      InkWell(
                        onTap: _handleOpenMentorProfile,
                        borderRadius: BorderRadius.circular(6.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _buildCoachAvatar(mod.coachName, mod.coachAvatar, 9.0),
                              const SizedBox(width: 6.0),
                              Text(
                                'By ${mod.coachName}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Text(
                        '•',
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.6),
                          fontSize: 11.0,
                        ),
                      ),

                      // Rating Chip (Scrolls to Reviews Section)
                      InkWell(
                        onTap: _scrollToReviews,
                        borderRadius: BorderRadius.circular(6.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(width: 4.0),
                              Text(
                                _reviews.isNotEmpty
                                    ? '(${_reviews.length} ${_reviews.length == 1 ? "review" : "reviews"})'
                                    : 'New Module · 0 reviews',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.0,
                                  color: textSecondary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: textSecondary.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Price Tag (If Paid & Not Enrolled)
                      if (!mod.isEnrolled && mod.price > 0) ...<Widget>[
                        Text(
                          '•',
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.6),
                            fontSize: 11.0,
                          ),
                        ),
                        InkWell(
                          onTap: _handleEnroll,
                          borderRadius: BorderRadius.circular(6.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7.0,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.0),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 11.0,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  '${(mod.price * 100).toInt()} Coins',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF59E0B),
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
              ],
            ),
          ),

          // Hairline Divider between context and action blocks
          Divider(
            height: 1.0,
            color: borderColor.withValues(alpha: 0.35),
          ),

          // ── LOWER ACTION BLOCK: Active Step, Micro Progress Bar & CTA ──
          Container(
            padding: const EdgeInsets.all(18.0),
            color: isDark
                ? AppColors.darkSurfaceCard.withValues(alpha: 0.5)
                : AppColors.lightSurfaceCard.withValues(alpha: 0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Target Step + Progress Text Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            completion >= 100
                                ? 'COMPLETED'
                                : activeTopic != null
                                    ? 'TOPIC ${activeTopic.number}'
                                    : 'TOPIC 1',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            completion >= 100
                                ? 'Module Mastered'
                                : activeTopic?.title ?? 'Topic 1',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Progress ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              '$completion% Complete',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: completion > 0
                                    ? (completion >= 100
                                        ? const Color(0xFF10B981)
                                        : AppColors.primary)
                                    : textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),

                // Strict 0% handling per AGENTS.md rule 2.3
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.5),
                  child: LinearProgressIndicator(
                    value: completion > 0
                        ? (completion / 100.0).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 5.0,
                    backgroundColor: borderColor.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completion >= 100
                          ? const Color(0xFF10B981)
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Action Row: Completed count subtitle + Primary CTA Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      completion >= 100
                          ? 'All challenges passed'
                          : activeTopic != null && activeTopic.totalCount > 0
                              ? '${activeTopic.solvedCount} of ${activeTopic.totalCount} exercises completed'
                              : '$totalSolved of $totalExercises solved',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: textSecondary,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _handlePrimaryCta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor:
                            isDark ? AppColors.onPrimaryDark : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 9.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            completion >= 100
                                ? Icons.check_circle_rounded
                                : Icons.play_arrow_rounded,
                            size: 15.0,
                            color: completion >= 100
                                ? const Color(0xFF10B981)
                                : null,
                          ),
                          const SizedBox(width: 5.0),
                          Text(
                            completion >= 100
                                ? 'Review Module'
                                : completion > 0
                                    ? 'Continue Learning'
                                    : 'Start Learning',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. MODULE OUTLINE (Unified Hollow Topics & Activities, NO Nested Cards)
  // ===========================================================================
  Widget _buildModuleOutline({
    required List<_DisplayTopic> topics,
    required bool isAllExpanded,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header Row: "Module Outline" + "Expand All / Collapse All"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Module Outline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            if (topics.isNotEmpty)
              InkWell(
                onTap: _toggleExpandAll,
                borderRadius: BorderRadius.circular(6.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        isAllExpanded ? 'COLLAPSE ALL' : 'EXPAND ALL',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 3.0),
                      AnimatedRotation(
                        turns: isAllExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 14.0,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8.0),
        Divider(
          height: 1.0,
          color: borderColor.withValues(alpha: 0.4),
        ),

        // Topics List
        if (topics.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36.0),
            child: Center(
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topics.length,
            itemBuilder: (BuildContext context, int index) {
              final _DisplayTopic topic = topics[index];
              final bool isExpanded = _expandedTopicIds.contains(topic.id);
              final String orderStr = topic.number.toString().padLeft(2, '0');

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Topic Header Trigger (Hollow row with ripple)
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
                      borderRadius: BorderRadius.circular(8.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14.0,
                          horizontal: 4.0,
                        ),
                        child: Row(
                          children: <Widget>[
                            // Monospace number index (01, 02)
                            SizedBox(
                              width: 28.0,
                              child: Text(
                                orderStr,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),

                            // Topic Title & Description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    topic.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                            const SizedBox(width: 10.0),

                            // Solved Status Indicator
                            if (topic.isCompleted) ...<Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 13.0,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    'Completed',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...<Widget>[
                              Text(
                                '${topic.solvedCount} / ${topic.totalCount} Solved',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8.0),

                            // Rotating Chevron
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.expand_more_rounded,
                                size: 18.0,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expanded Activities List (Hollow Rows with Dividers)
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity, height: 0.0),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(left: 28.0, bottom: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Divider(
                              height: 1.0,
                              color: borderColor.withValues(alpha: 0.2),
                            ),
                            if (topic.activities.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Text(
                                  'No activities in this topic yet.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: textSecondary,
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: topic.activities.length,
                                separatorBuilder: (BuildContext context, int i) =>
                                    Divider(
                                  height: 1.0,
                                  color: borderColor.withValues(alpha: 0.2),
                                ),
                                itemBuilder: (BuildContext context, int i) {
                                  final ModuleActivityModel act = topic.activities[i];
                                  final bool isSolved = act.isCompleted;
                                  final bool isChallenge = act.category == 'challenge';
                                  final bool isLocked = !_module!.isEnrolled;

                                  return InkWell(
                                    onTap: () => _navigateToActivity(act),
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10.0,
                                        horizontal: 4.0,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          // Status indicator dot or checkmark
                                          if (isSolved) ...<Widget>[
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 15.0,
                                              color: Color(0xFF10B981),
                                            ),
                                          ] else if (isLocked) ...<Widget>[
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 14.0,
                                              color: textSecondary.withValues(alpha: 0.5),
                                            ),
                                          ] else if (isChallenge) ...<Widget>[
                                            Container(
                                              width: 5.0,
                                              height: 5.0,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFF59E0B),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ] else ...<Widget>[
                                            Container(
                                              width: 5.0,
                                              height: 5.0,
                                              decoration: BoxDecoration(
                                                color: textSecondary.withValues(alpha: 0.4),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 10.0),

                                          // Activity Title + Category Badge + SLA + Subtitle
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Row(
                                                  children: <Widget>[
                                                    Flexible(
                                                      child: Text(
                                                        act.title,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 13.0,
                                                          fontWeight: FontWeight.w600,
                                                          color: textPrimary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6.0),

                                                    // Minimal Hollow Category Badge
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 5.0,
                                                        vertical: 1.5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isChallenge
                                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                                                            : (isDark
                                                                ? AppColors.darkSurfaceCard
                                                                : AppColors.lightSurfaceCard),
                                                        borderRadius: BorderRadius.circular(4.0),
                                                        border: Border.all(
                                                          color: isChallenge
                                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                                              : borderColor.withValues(alpha: 0.5),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        isChallenge ? 'CHALLENGE' : 'PRACTICE',
                                                        style: GoogleFonts.jetBrainsMono(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: isChallenge
                                                              ? const Color(0xFFF59E0B)
                                                              : textSecondary,
                                                        ),
                                                      ),
                                                    ),

                                                    // Time SLA
                                                    if (isChallenge && act.timeSla.isNotEmpty && act.timeSla != '—') ...<Widget>[
                                                      const SizedBox(width: 4.0),
                                                      Text(
                                                        '· ${act.timeSla}',
                                                        style: GoogleFonts.jetBrainsMono(
                                                          fontSize: 10.0,
                                                          color: textSecondary.withValues(alpha: 0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),

                                                // Subtitle
                                                if (act.description.isNotEmpty) ...<Widget>[
                                                  const SizedBox(height: 2.0),
                                                  Text(
                                                    _cleanChallengeSummary(act.description),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11.0,
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

                                          // Minimal Hollow Action Button
                                          if (isLocked) ...<Widget>[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: 12.0,
                                                  color: textSecondary.withValues(alpha: 0.6),
                                                ),
                                                const SizedBox(width: 3.0),
                                                Text(
                                                  'Locked',
                                                  style: GoogleFonts.jetBrainsMono(
                                                    fontSize: 11.0,
                                                    color: textSecondary.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else if (isSolved) ...<Widget>[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Text(
                                                  'Review',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(width: 2.0),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 12.0,
                                                  color: textSecondary,
                                                ),
                                              ],
                                            ),
                                          ] else if (isChallenge) ...<Widget>[
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 9.0,
                                                vertical: 4.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(8.0),
                                                border: Border.all(
                                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Text(
                                                    'Solve',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFFF59E0B),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3.0),
                                                  const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 11.0,
                                                    color: Color(0xFFF59E0B),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...<Widget>[
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10.0,
                                                vertical: 4.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(8.0),
                                                border: Border.all(
                                                  color: AppColors.primary.withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Text(
                                                    'Solve',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3.0),
                                                  const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 11.0,
                                                    color: AppColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 220),
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
  // 3. LEARNER REVIEWS SECTION (Matching Web 1:1)
  // ===========================================================================
  Widget _buildLearnerReviewsSection({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color borderColor,
  }) {
    final int recommendedCount = _reviews.where((ModuleReviewModel r) => r.rating >= 4).length;
    final int recommendedPct = _reviews.isNotEmpty
        ? ((recommendedCount / _reviews.length) * 100).round()
        : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header Row: "Learner Reviews" with badge + "Write a Review" button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Learner Reviews',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceCard
                        : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${_reviews.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _handleOpenReviewModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor:
                    isDark ? AppColors.onPrimaryDark : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 7.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 0,
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Write a Review',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  const Icon(Icons.arrow_forward_rounded, size: 12.0),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14.0),

        // Reviews Metric Overview Header Card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: borderColor.withValues(alpha: isDark ? 0.35 : 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Row: Overall Rating & Recommendation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Overall Rating Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'OVERALL RATING',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            _reviews.isNotEmpty
                                ? _effectiveRating.toStringAsFixed(1)
                                : '—',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 30.0,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            '/ 5.0',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: List<Widget>.generate(5, (int i) {
                          final bool isLit = _reviews.isNotEmpty && (i + 1) <= _effectiveRating.round();
                          return Icon(
                            isLit ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 15.0,
                            color: isLit ? const Color(0xFFFBBF24) : textSecondary.withValues(alpha: 0.3),
                          );
                        }),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Based on ${_reviews.length} verified review${_reviews.length == 1 ? "" : "s"}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.0,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Recommendation %
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'RECOMMENDATION',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        '$recommendedPct%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 26.0,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Learners recommend',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.0,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Divider(height: 1.0, color: borderColor.withValues(alpha: 0.3)),
              const SizedBox(height: 12.0),

              // Star Breakdown Distribution Bars (5 down to 1)
              for (int stars = 5; stars >= 1; stars--) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 28.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '$stars',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(width: 2.0),
                            const Icon(
                              Icons.star_rounded,
                              size: 11.0,
                              color: Color(0xFFFBBF24),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2.5),
                          child: LinearProgressIndicator(
                            value: _reviews.isNotEmpty
                                ? (_reviews.where((ModuleReviewModel r) => r.rating == stars).length /
                                        _reviews.length)
                                    .clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 5.0,
                            backgroundColor: borderColor.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFBBF24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      SizedBox(
                        width: 20.0,
                        child: Text(
                          '${_reviews.where((ModuleReviewModel r) => r.rating == stars).length}',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14.0),

        // Reviews List or Empty State
        if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: borderColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                    size: 20.0,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
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
                const SizedBox(height: 14.0),
                OutlinedButton(
                  onPressed: _handleOpenReviewModal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Leave First Review',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      const Icon(Icons.arrow_forward_rounded, size: 12.0),
                    ],
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
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 10.0),
            itemBuilder: (BuildContext context, int index) {
              final ModuleReviewModel rev = _reviews[index];
              final String initial = rev.userName.isNotEmpty
                  ? rev.userName[0].toUpperCase()
                  : 'L';

              return Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: borderColor.withValues(alpha: isDark ? 0.3 : 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Author + Rating Header
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
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  rev.userName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                if (rev.createdAt.isNotEmpty)
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

                        // Stars
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List<Widget>.generate(5, (int i) {
                            final bool isLit = (i + 1) <= rev.rating;
                            return Icon(
                              isLit ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 13.0,
                              color: isLit
                                  ? const Color(0xFFFBBF24)
                                  : textSecondary.withValues(alpha: 0.25),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),

                    // Review Comment
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
}
