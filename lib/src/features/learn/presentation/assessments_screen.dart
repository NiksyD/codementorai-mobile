import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/filter_tab_bar.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../constants/app_colors.dart';
import '../data/assessment_repository.dart';
import '../data/supabase_assessment_repository.dart';
import '../domain/assessment_model.dart';
import 'widgets/assessment_preview_sheet.dart';
import 'widgets/report_assessment_sheet.dart';

class AssessmentsScreen extends StatefulWidget {
  const AssessmentsScreen({
    super.key,
    this.assessmentRepository = const SupabaseAssessmentRepository(),
  });

  final AssessmentRepository assessmentRepository;

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  String _selectedDifficulty = 'all';
  String _searchQuery = '';
  List<AssessmentModel> _assessments = <AssessmentModel>[];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, String>> _difficultyFilters =
      <Map<String, String>>[
    <String, String>{'id': 'all', 'label': 'All'},
    <String, String>{'id': 'easy', 'label': 'Easy'},
    <String, String>{'id': 'medium', 'label': 'Medium'},
    <String, String>{'id': 'hard', 'label': 'Hard'},
    <String, String>{'id': 'saved', 'label': 'Saved'},
  ];

  @override
  void initState() {
    super.initState();
    SupabaseAssessmentRepository.bookmarkedAssessmentIdsNotifier
        .addListener(_onBookmarksChanged);
    _loadAssessments();
  }

  @override
  void dispose() {
    SupabaseAssessmentRepository.bookmarkedAssessmentIdsNotifier
        .removeListener(_onBookmarksChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onBookmarksChanged() {
    final Set<String> bookmarkedIds =
        SupabaseAssessmentRepository.bookmarkedAssessmentIdsNotifier.value;
    if (mounted) {
      setState(() {
        _assessments = _assessments
            .map((AssessmentModel a) =>
                a.copyWith(isInLibrary: bookmarkedIds.contains(a.id)))
            .toList();
      });
    }
  }

  Future<void> _loadAssessments() async {
    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';
    final List<AssessmentModel> data =
        await widget.assessmentRepository.getPublishedAssessments(userId);
    if (mounted) {
      setState(() {
        _assessments = data;
        _isLoading = false;
      });
    }
  }

  List<AssessmentModel> get _filteredAssessments {
    return _assessments.where((AssessmentModel a) {
      final bool matchesDifficulty = _selectedDifficulty == 'all' ||
          (_selectedDifficulty == 'saved' && a.isInLibrary) ||
          (_selectedDifficulty == a.difficulty.toLowerCase());

      final bool matchesSearch = _searchQuery.isEmpty ||
          a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.stack.any(
            (String s) => s.toLowerCase().contains(_searchQuery.toLowerCase()),
          ) ||
          a.mentorName.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesDifficulty && matchesSearch;
    }).toList();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadAssessments,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              // Top App Bar / Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: textPrimary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              'Competition Assessments',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20.0,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Text(
                          'Timed evaluations and readiness benchmarks.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // Search Input
                      TextField(
                        controller: _searchController,
                        onChanged: (String val) {
                          setState(() => _searchQuery = val);
                        },
                        textAlignVertical: TextAlignVertical.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurfaceCard
                              : AppColors.lightSurfaceCard,
                          hintText: 'Search assessments by language or topic...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w400,
                            color: textSecondary.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 19.0,
                            color: textSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18.0,
                                    color: textSecondary,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 12.0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.0),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.0),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.0),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14.0),

                      // Category / Difficulty Pills
                      FilterTabBar(
                        height: 36.0,
                        tabs: _difficultyFilters.map((Map<String, String> cat) {
                          return FilterTabItem(
                            id: cat['id']!,
                            label: cat['label']!,
                          );
                        }).toList(),
                        selectedId: _selectedDifficulty,
                        onTabSelected: (String id) {
                          setState(() {
                            _selectedDifficulty = id;
                          });
                        },
                      ),
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
              ),

              // Content List
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Container(
                        height: 180.0,
                        margin: const EdgeInsets.only(bottom: 14.0),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceCard.withValues(alpha: 0.5)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                      childCount: 3,
                    ),
                  ),
                )
              else if (_filteredAssessments.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 48.0,
                            color: textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            'No assessments found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try refining your search keyword or filters.'
                                : 'Check back soon for new competition benchmarks.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 40.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final AssessmentModel a = _filteredAssessments[index];
                        return _buildAssessmentCard(
                          context,
                          assessment: a,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      },
                      childCount: _filteredAssessments.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(
    BuildContext context, {
    required AssessmentModel assessment,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final Color diffColor = _getDifficultyColor(assessment.difficulty);

    Future<void> handleCardTap() async {
      HapticFeedback.lightImpact();
      await AssessmentPreviewSheet.show(
        context,
        assessment: assessment,
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
            .map((AssessmentModel a) =>
                a.id == assessment.id ? a.copyWith(isInLibrary: nextState) : a)
            .toList();
      });

      final bool ok = await widget.assessmentRepository.toggleAssessmentBookmark(
        user.id,
        assessment.id,
        nextState,
      );

      if (!ok && mounted) {
        setState(() {
          _assessments = _assessments
              .map((AssessmentModel a) =>
                  a.id == assessment.id ? a.copyWith(isInLibrary: !nextState) : a)
              .toList();
        });
        if (context.mounted) {
          AppToast.showError(context, 'Failed to update saved assessment');
        }
      }
    }

    Future<void> handleReport() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        AppToast.showError(context, 'Please log in to submit a report');
        return;
      }
      final bool? reported = await ReportAssessmentSheet.show(
        context,
        assessmentId: assessment.id,
        assessmentTitle: assessment.title,
        assessmentRepository: widget.assessmentRepository,
        userId: user.id,
      );
      if (reported == true && context.mounted) {
        AppToast.showSuccess(context, 'Report submitted for review');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        onTap: handleCardTap,
        borderRadius: BorderRadius.circular(20.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header: Stack + Difficulty Badge + Actions (Flag & Bookmark)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  LanguageAvatarStack(
                    languages: assessment.stack,
                    size: 26.0,
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: diffColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          assessment.difficulty.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: diffColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      // Flag / Report
                      GestureDetector(
                        onTap: handleReport,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Icon(
                            Icons.flag_outlined,
                            size: 18.0,
                            color: textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      // Bookmark
                      GestureDetector(
                        onTap: handleToggleBookmark,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Icon(
                            assessment.isInLibrary
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 19.0,
                            color: assessment.isInLibrary
                                ? AppColors.primary
                                : textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // Title & Description
              Text(
                assessment.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                assessment.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  color: textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12.0),

              // Specifications Micro-Pill Row
              Row(
                children: <Widget>[
                  _buildMicroSpec(
                    icon: Icons.timer_outlined,
                    label: '${assessment.durationMins}m',
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 12.0),
                  _buildMicroSpec(
                    icon: Icons.code_rounded,
                    label: '${assessment.challengeCount} Tasks',
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 12.0),
                  _buildMicroSpec(
                    icon: Icons.check_circle_outline_rounded,
                    label: '${assessment.passingScore}% Benchmark',
                    textSecondary: textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14.0),

              Divider(
                height: 1.0,
                color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12.0),

              // Footer: Mentor info + Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 11.0,
                          backgroundColor: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightBackground,
                          backgroundImage: assessment.mentorAvatar != null
                              ? NetworkImage(assessment.mentorAvatar!)
                              : null,
                          child: assessment.mentorAvatar == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 13.0,
                                  color: textSecondary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            assessment.mentorName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: handleCardTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor:
                          isDark ? AppColors.onPrimaryDark : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 7.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'View',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
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
        Icon(icon, size: 13.5, color: textSecondary.withValues(alpha: 0.7)),
        const SizedBox(width: 4.0),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11.0,
            color: textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
