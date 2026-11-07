import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/currency_formatter.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/module_detail_model.dart';
import '../domain/module_review_model.dart';
import '../domain/pathway_model.dart';
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

  bool get isCompleted => totalCount > 0 && solvedCount == totalCount;
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
    final ModuleDetailModel? cached = widget.pathwayRepository
        .getCachedModuleDetails(widget.moduleId);
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
    _expandedTopicIds.clear();
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
    final List<ModuleReviewModel> revs = await widget.pathwayRepository
        .getModuleReviews(widget.moduleId);
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

  Future<void> _handleUnlockChallenges() async {
    final String userId = _getUserId();
    if (userId.isEmpty) {
      AppToast.showError(context, 'Please log in to unlock challenges');
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
      currentModule: _module!.topics.isNotEmpty
          ? _module!.topics.first.title
          : '',
      coachName: _module!.coachName,
      coachAvatar: _module!.coachAvatar,
      price: _module!.price > 0 ? _module!.price : 0.84,
    );

    await ModulePreviewSheet.show(
      context,
      module: tempPathway,
      onEnroll: (String tier) async {
        final String? error = await widget.pathwayRepository
            .unlockModuleWithCoins(userId, widget.moduleId);
        if (error == null) {
          await _loadModuleData();
          if (mounted) {
            AppToast.showSuccess(
              context,
              'Coding challenges unlocked successfully!',
            );
          }
        } else if (mounted) {
          AppToast.showError(context, error);
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

  Future<void> _handleOpenReviewModal() async {
    HapticFeedback.lightImpact();
    final String userId = _getUserId();
    if (userId.isEmpty) {
      AppToast.showError(context, 'Please log in to write a review');
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

    final bool isChallenge = act.category == 'challenge';
    final bool isChallengeLocked = isChallenge && !_module!.isPurchased;

    if (isChallengeLocked) {
      await _handleUnlockChallenges();
      return;
    }

    // Auto-enroll user in free practice tracking if not already enrolled
    final String userId = _getUserId();
    if (!_module!.isEnrolled && userId.isNotEmpty) {
      await widget.pathwayRepository.enrollModule(userId, widget.moduleId);
    }

    if (!mounted) return;

    if (isChallenge) {
      await context.push('/modules/${widget.moduleId}/challenges/${act.id}');
    } else {
      await context.push('/modules/${widget.moduleId}/practice/${act.id}');
    }

    if (mounted) {
      _loadModuleData();
    }
  }

  Future<void> _handlePrimaryCta() async {
    HapticFeedback.mediumImpact();
    if (_module == null) return;

    // Auto-enroll user in free practice tracking if not already enrolled
    final String userId = _getUserId();
    if (!_module!.isEnrolled && userId.isNotEmpty) {
      await widget.pathwayRepository.enrollModule(userId, widget.moduleId);
    }

    // Find first unsolved practice activity (or challenge if unlocked)
    ModuleActivityModel? firstUnsolved;
    for (final _DisplayTopic t in _displayTopics) {
      for (final ModuleActivityModel a in t.activities) {
        if (!a.isCompleted) {
          final bool isChallenge = a.category == 'challenge';
          final bool isLocked = isChallenge && !_module!.isPurchased;
          if (!isLocked) {
            firstUnsolved = a;
            break;
          }
        }
      }
      if (firstUnsolved != null) break;
    }

    // Fallback to first activity if all solved
    final ModuleActivityModel? target =
        firstUnsolved ??
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
      list.add(
        _DisplayTopic(
          id: topic.id,
          number: i + 1,
          title: topic.title,
          description: topic.description,
          activities: topic.activities,
        ),
      );
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
      list.add(
        _DisplayTopic(
          id: 'topic-benchmark-challenges',
          number: list.length + 1,
          title: 'Benchmark Challenges',
          description: 'Algorithmic benchmark challenges and performance SLAs.',
          activities: standaloneChallenges,
        ),
      );
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
      (_DisplayTopic t) =>
          t.activities.any((ModuleActivityModel a) => !a.isCompleted),
      orElse: () => list.first,
    );
  }

  int get _totalSolvedExercises {
    int count = 0;
    for (final _DisplayTopic t in _displayTopics) {
      count += t.activities
          .where((ModuleActivityModel a) => a.isCompleted)
          .length;
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
        .replaceAll(
          RegExp(r'###\s*Problem Statement:?', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'###\s*Key Requirements[\s\S]*', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'###\s*Example[\s\S]*', caseSensitive: false), ' ')
        .replaceAll(
          RegExp(r'###\s*Constraints[\s\S]*', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'[*_#`\->]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'Implement optimal algorithmic logic matching SLA bounds.';
    }
    return cleaned;
  }

  Widget _buildCoachAvatar(
    String coachName,
    String? coachAvatar,
    double radius,
  ) {
    if (coachAvatar != null && coachAvatar.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          coachAvatar,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return _buildInitialsAvatar(coachName, radius);
              },
        ),
      );
    }
    return _buildInitialsAvatar(coachName, radius);
  }

  Widget _buildInitialsAvatar(String coachName, double radius) {
    final String initial = coachName.isNotEmpty
        ? coachName[0].toUpperCase()
        : 'M';
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
    final bool isAllExpanded =
        topics.isNotEmpty && _expandedTopicIds.length == topics.length;

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
              fontWeight: FontWeight.w700,
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
                color: mod.isBookmarked ? textPrimary : textSecondary,
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── HERO BANNER: SPLIT-BLOCK ARCHETYPE (Matching Web 1:1) ──
              _buildSplitBlockHero(
                mod: mod,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              const SizedBox(height: 32.0),

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
  // 1. HERO: plain section, no card
  // ===========================================================================
  Widget _buildSplitBlockHero({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final int completion = _completionPercentage;
    final int totalSolved = _totalSolvedExercises;
    final int totalExercises = _totalExercises;
    final _DisplayTopic? activeTopic = _activeUnsolvedTopic;
    final bool isDone = completion >= 100;
    final Color onPrimary = isDark ? AppColors.onPrimaryDark : Colors.white;

    final String topicLabel = isDone
        ? 'Completed'
        : activeTopic != null
        ? 'Up next'
        : 'Up next';
    final String topicTitle = isDone
        ? 'Every topic in this module is done'
        : activeTopic?.title ?? 'Topic 1';
    final String solvedText = isDone
        ? 'All challenges passed'
        : activeTopic != null && activeTopic.totalCount > 0
        ? '${activeTopic.solvedCount} of ${activeTopic.totalCount} solved in this topic'
        : '$totalSolved of $totalExercises solved';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            LanguageAvatarStack(
              languages: mod.stack.isNotEmpty ? mod.stack : <String>['python'],
              size: 24.0,
              borderColor: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
            ),
            Text(
              '$completion% Complete',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        Text(
          mod.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          mod.description.trim().isNotEmpty
              ? mod.description.trim()
              : 'Master core concepts and hands-on coding challenges with real-time feedback.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14.0),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _buildCoachAvatar(mod.coachName, mod.coachAvatar, 9.0),
            const SizedBox(width: 6.0),
            Text(
              'By ${mod.coachName}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
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
            InkWell(
              onTap: _scrollToReviews,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.star_rounded, size: 14.0, color: textSecondary),
                    const SizedBox(width: 3.0),
                    Text(
                      _effectiveRating.toStringAsFixed(1),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      _reviews.isNotEmpty
                          ? '(${_reviews.length} ${_reviews.length == 1 ? "review" : "reviews"})'
                          : 'New module · 0 reviews',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        color: textSecondary,
                        decoration: TextDecoration.underline,
                        decorationColor: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!_module!.isPurchased)
          InkWell(
            onTap: _handleUnlockChallenges,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16.0,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Unlock challenges for ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      decoration: TextDecoration.underline,
                      decorationColor: textPrimary,
                    ),
                  ),
                  Text(
                    '${CurrencyFormatter.coinsFromUsd(mod.price > 0 ? mod.price : 0.84)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    ' coins',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      decoration: TextDecoration.underline,
                      decorationColor: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14.0),
        Divider(height: 1.0, thickness: 1.0, color: borderColor),
        const SizedBox(height: 18.0),
        // Strict 0% handling (AGENTS.md 2.3): no minimum sliver.
        ClipRRect(
          borderRadius: BorderRadius.circular(999.0),
          child: SizedBox(
            height: 4.0,
            child: LinearProgressIndicator(
              value: completion > 0
                  ? (completion / 100.0).clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceHighest
                  : AppColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14.0),
        Text(
          topicLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          topicTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2.0),
        Text(
          solvedText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 16.0),
        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: _handlePrimaryCta,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  isDone ? Icons.check_rounded : Icons.play_arrow_rounded,
                  size: 18.0,
                ),
                const SizedBox(width: 6.0),
                Text(
                  isDone
                      ? 'Review Module'
                      : completion > 0
                      ? 'Continue Learning'
                      : 'Start Learning',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    color: onPrimary,
                  ),
                ),
                const SizedBox(width: 6.0),
                const Icon(Icons.arrow_forward_rounded, size: 16.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. MODULE OUTLINE: hairline rows, no nested cards
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Module Outline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            if (topics.isNotEmpty)
              InkWell(
                onTap: _toggleExpandAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48.0,
                    minWidth: 48.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1.0,
                    child: Text(
                      isAllExpanded ? 'Collapse all' : 'Expand all',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        color: textSecondary,
                        decoration: TextDecoration.underline,
                        decorationColor: textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Divider(height: 1.0, thickness: 1.0, color: borderColor),
        if (topics.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36.0),
            child: Center(
              child: Column(
                children: <Widget>[
                  Text(
                    'No practice topics found',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'This module does not contain any published practice exercises yet.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final _DisplayTopic topic in topics) ...<Widget>[
            _buildTopicRow(
              topic: topic,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
            ),
          ],
      ],
    );
  }

  Widget _buildTopicRow({
    required _DisplayTopic topic,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isExpanded = _expandedTopicIds.contains(topic.id);
    final String orderStr = topic.number.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 32.0,
                      child: Text(
                        orderStr,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13.0,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            topic.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (topic.description.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2.0),
                            Text(
                              topic.description,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                color: textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    if (topic.isCompleted) ...<Widget>[
                      Icon(
                        Icons.check_rounded,
                        size: 18.0,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 6.0),
                    ],
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 22.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(left: 32.0, bottom: 8.0),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor)),
              ),
              child: topic.activities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'No activities in this topic yet.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          color: textSecondary,
                        ),
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        for (final ModuleActivityModel act in topic.activities)
                          _buildActivityRow(
                            act: act,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityRow({
    required ModuleActivityModel act,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isSolved = act.isCompleted;
    final bool isChallenge = act.category == 'challenge';
    final bool isLocked = isChallenge && !_module!.isPurchased;

    final IconData statusIcon = isSolved
        ? Icons.check_rounded
        : isLocked
        ? Icons.lock_outline_rounded
        : Icons.radio_button_unchecked_rounded;
    final String action = isLocked
        ? 'Locked'
        : isSolved
        ? 'Review'
        : 'Solve';

    return InkWell(
      onTap: () => _navigateToActivity(act),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: Icon(statusIcon, size: 18.0, color: textSecondary),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      act.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: isSolved ? textSecondary : textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isSolved &&
                        act.description.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2.0),
                      Text(
                        _cleanChallengeSummary(act.description),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4.0),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: isChallenge ? 'Challenge' : 'Practice',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                            ),
                          ),
                          if (isChallenge &&
                              act.timeSla.isNotEmpty &&
                              act.timeSla != '—')
                            TextSpan(
                              text: '  ·  ${act.timeSla}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.0,
                                color: textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10.0),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      action,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: isLocked ? textSecondary : textPrimary,
                      ),
                    ),
                    if (!isLocked) ...<Widget>[
                      const SizedBox(width: 3.0),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14.0,
                        color: textPrimary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. LEARNER REVIEWS: figures and hairline rows, no cards
  // ===========================================================================
  Widget _buildLearnerReviewsSection({
    required ModuleDetailModel mod,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final int recommendedCount = _reviews
        .where((ModuleReviewModel r) => r.rating >= 4)
        .length;
    final int recommendedPct = _reviews.isNotEmpty
        ? ((recommendedCount / _reviews.length) * 100).round()
        : 0;
    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0),
    );

    Widget stars(double size, bool Function(int) lit) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int i) {
        return Icon(
          lit(i + 1) ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: lit(i + 1) ? textPrimary : textSecondary,
        );
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Learner Reviews  ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  TextSpan(
                    text: '${_reviews.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: _handleOpenReviewModal,
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                minimumSize: const Size(48.0, 44.0),
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkBorderVariant
                      : AppColors.lightBorder,
                ),
                shape: buttonShape,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
              ),
              child: Text(
                'Write a Review',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Divider(height: 1.0, thickness: 1.0, color: borderColor),
        const SizedBox(height: 16.0),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Column(
                children: <Widget>[
                  Text(
                    'No reviews yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    'Complete this module and be the first to share feedback. Reviews help other learners choose.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  OutlinedButton(
                    onPressed: _handleOpenReviewModal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      minimumSize: const Size(48.0, 44.0),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorderVariant
                            : AppColors.lightBorder,
                      ),
                      shape: buttonShape,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    child: Text(
                      'Leave First Review',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Overall rating',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: _effectiveRating.toStringAsFixed(1),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 32.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' / 5.0',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  stars(16.0, (int n) => n <= _effectiveRating.round()),
                  const SizedBox(height: 4.0),
                  Text(
                    'Based on ${_reviews.length} verified review${_reviews.length == 1 ? "" : "s"}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Recommend',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                  Text(
                    '$recommendedPct%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 32.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'of learners',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          for (int star = 5; star >= 1; star--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 36.0,
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '$star',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.0,
                              color: textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: ' star',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999.0),
                      child: SizedBox(
                        height: 4.0,
                        child: LinearProgressIndicator(
                          value:
                              (_reviews
                                          .where(
                                            (ModuleReviewModel r) =>
                                                r.rating == star,
                                          )
                                          .length /
                                      _reviews.length)
                                  .clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceHighest
                              : AppColors.lightBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28.0,
                    child: Text(
                      '${_reviews.where((ModuleReviewModel r) => r.rating == star).length}',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12.0),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: <Widget>[
                for (final ModuleReviewModel rev in _reviews)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    rev.userName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  if (rev.createdAt.isNotEmpty)
                                    Text(
                                      rev.createdAt,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12.0,
                                        color: textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            stars(14.0, (int n) => n <= rev.rating),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '\u201c${rev.comment}\u201d',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
