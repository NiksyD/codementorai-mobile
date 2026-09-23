import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // Top App Bar
            _buildAppBar(isDark: isDark, textPrimary: textPrimary),

            // Main Body
            Expanded(
              child: _isLoading
                  ? _buildSkeletonLoading(isDark: isDark)
                  : _room == null
                      ? _buildNotFoundState(
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRoom,
                          color: AppColors.primary,
                          backgroundColor:
                              isDark ? AppColors.darkSurfaceCard : Colors.white,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(
                              20.0,
                              8.0,
                              20.0,
                              32.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Room Overview Card
                                _buildRoomHeaderCard(
                                  room: _room!,
                                  isDark: isDark,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                                const SizedBox(height: 24.0),

                                // Modules Section Header
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'Curriculum Modules',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 2.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkSurface
                                            : AppColors.lightSurface,
                                        borderRadius:
                                            BorderRadius.circular(10.0),
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder,
                                        ),
                                      ),
                                      child: Text(
                                        '${_room!.curriculumModules.length}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6.0),
                                Text(
                                  'Complete attached modules to earn room completion credits.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16.0),

                                // Modules List or Empty State
                                if (_room!.curriculumModules.isEmpty)
                                  _buildEmptyModules(
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  )
                                else
                                  ..._room!.curriculumModules.map(
                                    (RoomModuleSummary mod) => _buildModuleCard(
                                      module: mod,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                    ),
                                  ),
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

  Widget _buildAppBar({required bool isDark, required Color textPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/rooms');
              }
            },
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18.0,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _room?.name ?? 'Room Details',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _room != null ? 'Section ${_room!.section}' : 'Classroom',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomHeaderCard({
    required RoomModel room,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final String mentorSeed =
        room.mentorEmail ?? (room.mentorName.isNotEmpty ? room.mentorName : room.id);
    final String avatarUrl = room.mentorAvatarUrl?.trim().isNotEmpty == true
        ? room.mentorAvatarUrl!
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=$mentorSeed';

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Section & Language Badges Row
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Text(
                  room.section,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  room.targetLanguage.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Title
          Text(
            room.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),

          if (room.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8.0),
            Text(
              room.description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18.0),

          // Mentor Profile Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Image.network(
                    avatarUrl,
                    width: 32.0,
                    height: 32.0,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 32.0,
                      height: 32.0,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 18.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Taught by ${room.mentorName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (room.mentorEmail != null)
                        Text(
                          room.mentorEmail!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18.0),

          // Overall Progress Box
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${room.completedActivitiesCount} / ${room.totalActivities} activities completed',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    Text(
                      '${room.progressPct}%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999.0),
                  child: LinearProgressIndicator(
                    value: room.progressPct / 100.0,
                    minHeight: 6.0,
                    backgroundColor: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
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

  Widget _buildModuleCard({
    required RoomModuleSummary module,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/modules/${module.id}');
          },
          borderRadius: BorderRadius.circular(20.0),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Module Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            module.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            module.description.trim().isNotEmpty
                                ? module.description.trim()
                                : 'Self-paced coding practice exercises and challenges.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Container(
                      width: 34.0,
                      height: 34.0,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),

                // Meta Row: Stacks + Topics count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (module.stack.isNotEmpty)
                      LanguageAvatarStack(
                        languages: module.stack,
                        size: 20.0,
                        overlap: 6.0,
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      '${module.topicsCount} Topics • ${module.activitiesCount > 0 ? module.activitiesCount : module.topicsCount * 3} Activities',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
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

  Widget _buildEmptyModules({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 52.0,
            height: 52.0,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: const Icon(
              Icons.layers_outlined,
              size: 24.0,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14.0),
          Text(
            'No Modules Attached Yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Your mentor has not attached any course modules to this room yet. Check back soon.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              color: textSecondary,
              height: 1.4,
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
            const Icon(
              Icons.warning_amber_rounded,
              size: 40.0,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12.0),
            Text(
              'Room Not Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'This room may have been archived or removed by the instructor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 18.0),
            ElevatedButton(
              onPressed: () => context.go('/rooms'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text('Back to Rooms'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          SkeletonBox(
            width: double.infinity,
            height: 160.0,
            borderRadius: 22.0,
          ),
          SizedBox(height: 24.0),
          SkeletonBox(
            width: 140.0,
            height: 18.0,
            borderRadius: 4.0,
          ),
          SizedBox(height: 16.0),
          SkeletonBox(
            width: double.infinity,
            height: 90.0,
            borderRadius: 20.0,
          ),
          SizedBox(height: 14.0),
          SkeletonBox(
            width: double.infinity,
            height: 90.0,
            borderRadius: 20.0,
          ),
        ],
      ),
    );
  }
}
