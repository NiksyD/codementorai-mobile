import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/filter_tab_bar.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/room_model.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.roomId,
    this.initialRoom,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final String roomId;
  final RoomModel? initialRoom;
  final PathwayRepository pathwayRepository;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  RoomModel? _room;
  bool _isLoading = false;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    if (_room == null) {
      _loadRoom();
    }
  }

  Future<void> _loadRoom() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final List<dynamic> rooms =
          await widget.pathwayRepository.getLearnerRooms(user.id);
      final RoomModel? matched = rooms
          .cast<RoomModel>()
          .where((RoomModel r) => r.id == widget.roomId)
          .firstOrNull;

      if (mounted) {
        setState(() {
          _room = matched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _buildAppBar(textPrimary: textPrimary, borderColor: borderColor),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonLoading()
                  : _room == null
                      ? _buildNotFoundState(
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRoom,
                          color: AppColors.primary,
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceCard
                              : Colors.white,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(
                              20.0,
                              16.0,
                              20.0,
                              32.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _buildHeader(
                                  room: _room!,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  borderColor: borderColor,
                                ),
                                const SizedBox(height: 20.0),
                                _buildTabs(borderColor),
                                if (_selectedTabIndex == 0) ...<Widget>[
                                  if (_room!.curriculumModules.isEmpty)
                                    _buildEmpty(
                                      title: 'No modules yet',
                                      message:
                                          'Your mentor has not attached any modules to this hub yet.',
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                    )
                                  else
                                    for (final RoomModuleSummary mod
                                        in _room!.curriculumModules)
                                      _buildModuleRow(
                                        module: mod,
                                        textPrimary: textPrimary,
                                        textSecondary: textSecondary,
                                        borderColor: borderColor,
                                      ),
                                ] else ...<Widget>[
                                  if (_room!.assessments.isEmpty)
                                    _buildEmpty(
                                      title: 'No assessments yet',
                                      message:
                                          'Your mentor has not assigned any assessments to this hub yet.',
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                    )
                                  else
                                    for (final RoomAssessmentSummary assess
                                        in _room!.assessments)
                                      _buildAssessmentRow(
                                        assessment: assess,
                                        isDark: isDark,
                                        textPrimary: textPrimary,
                                        textSecondary: textSecondary,
                                        borderColor: borderColor,
                                      ),
                                ],
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar({
    required Color textPrimary,
    required Color borderColor,
  }) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Back',
            constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
            icon: Icon(Icons.arrow_back_rounded, size: 22.0, color: textPrimary),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/rooms');
              }
            },
          ),
          Expanded(
            child: Text(
              _room?.name ?? 'Hub',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12.0),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required RoomModel room,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final String mentorSeed = room.mentorEmail ??
        (room.mentorName.isNotEmpty ? room.mentorName : room.id);
    final String avatarUrl = room.mentorAvatarUrl?.trim().isNotEmpty == true
        ? room.mentorAvatarUrl!
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=$mentorSeed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          room.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          'Section ${room.section}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: textSecondary,
          ),
        ),
        if (room.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10.0),
          Text(
            room.description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.0,
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 16.0),
        Row(
          children: <Widget>[
            ClipOval(
              child: Image.network(
                avatarUrl,
                width: 28.0,
                height: 28.0,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 28.0,
                  height: 28.0,
                  color: borderColor,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 16.0,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                'Taught by ${room.mentorName}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '${room.completedActivitiesCount} of ${room.totalActivities} activities completed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textSecondary,
              ),
            ),
            Text(
              '${room.progressPct}%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(2.0),
          child: LinearProgressIndicator(
            value: room.progressPct / 100.0,
            minHeight: 4.0,
            backgroundColor: borderColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: FilterTabBar(
        tabs: <FilterTabItem>[
          FilterTabItem(
            id: 'modules',
            label: 'Learning Modules',
            count: _room!.curriculumModules.length,
          ),
          FilterTabItem(
            id: 'assessments',
            label: 'Assessments',
            count: _room!.assessments.length,
          ),
        ],
        selectedId: _selectedTabIndex == 0 ? 'modules' : 'assessments',
        onTabSelected: (String id) =>
            setState(() => _selectedTabIndex = id == 'modules' ? 0 : 1),
      ),
    );
  }

  Widget _buildModuleRow({
    required RoomModuleSummary module,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final int activities = module.activitiesCount > 0
        ? module.activitiesCount
        : module.topicsCount * 3;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/modules/${module.id}');
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 72.0),
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    module.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    module.description.trim().isNotEmpty
                        ? module.description.trim()
                        : 'Self-paced coding practice and challenges.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: <Widget>[
                      if (module.stack.isNotEmpty) ...<Widget>[
                        LanguageAvatarStack(
                          languages: module.stack,
                          size: 20.0,
                          overlap: 6.0,
                        ),
                        const SizedBox(width: 10.0),
                      ],
                      Text(
                        '${module.topicsCount} topics · $activities activities',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.0,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Icon(Icons.chevron_right_rounded, size: 22.0, color: textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentRow({
    required RoomAssessmentSummary assessment,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isCompleted = assessment.isCompleted;
    final bool isInProgress = assessment.isInProgress;
    final String status = isCompleted
        ? (assessment.userBestScore != null
            ? 'Best ${assessment.userBestScore}%'
            : 'Completed')
        : isInProgress
            ? 'In progress'
            : 'Not started';
    final String action = isCompleted
        ? 'Review'
        : isInProgress
            ? 'Resume'
            : 'Start';
    final String difficulty = assessment.difficulty.isEmpty
        ? ''
        : '${assessment.difficulty[0].toUpperCase()}${assessment.difficulty.substring(1).toLowerCase()}';
    final int n = assessment.challengesCount;

    void open() {
      HapticFeedback.lightImpact();
      context.push('/assessments/${assessment.id}/take');
    }

    return InkWell(
      onTap: open,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72.0),
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    assessment.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  if (assessment.description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4.0),
                    Text(
                      assessment.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        color: textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 2.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (difficulty.isNotEmpty)
                        Text(
                          difficulty,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                      Text(
                        '${assessment.durationMins} min · $n ${n == 1 ? 'challenge' : 'challenges'}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.0,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 6.0),
                OutlinedButton(
                  onPressed: open,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(72.0, 40.0),
                    foregroundColor: textPrimary,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: Text(
                    action,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty({
    required String title,
    required String message,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Hub not found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'This hub may have been archived or removed by the mentor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 16.0),
            OutlinedButton(
              onPressed: () => context.go('/hubs'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(140.0, 48.0),
                foregroundColor: textPrimary,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text('Back to Hubs'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return const Padding(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(width: 220.0, height: 24.0, borderRadius: 4.0),
          SizedBox(height: 10.0),
          SkeletonBox(width: double.infinity, height: 14.0, borderRadius: 4.0),
          SizedBox(height: 28.0),
          SkeletonBox(width: double.infinity, height: 72.0, borderRadius: 4.0),
          SizedBox(height: 12.0),
          SkeletonBox(width: double.infinity, height: 72.0, borderRadius: 4.0),
        ],
      ),
    );
  }
}
