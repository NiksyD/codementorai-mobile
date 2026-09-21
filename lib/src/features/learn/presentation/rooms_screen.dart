import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/room_model.dart';
import 'widgets/join_room_sheet.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final PathwayRepository pathwayRepository;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<RoomModel> _rooms = <RoomModel>[];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _setupRealtimeAndPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadRooms({bool silent = false}) async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!silent) {
      setState(() => _isLoading = true);
    }

    final List<dynamic> result =
        await widget.pathwayRepository.getLearnerRooms(user.id);

    if (mounted) {
      setState(() {
        _rooms = result.cast<RoomModel>();
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeAndPolling() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Supabase Realtime subscription on room_members for instant admission updates
      final SupabaseClient supabase = Supabase.instance.client;
      _realtimeChannel = supabase
          .channel('mobile-learner-admissions-${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'learner_id',
              value: user.id,
            ),
            callback: (PostgresChangePayload payload) {
              _loadRooms(silent: true);
            },
          )
          .subscribe();
    } catch (_) {
      // Non-blocking if realtime unavailable
    }

    // 2. Periodic fast polling if pending rooms exist
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final bool hasPending = _rooms.any((RoomModel r) => r.isPending);
      if (hasPending) {
        _loadRooms(silent: true);
      }
    });
  }

  Future<void> _handleJoinRoom({Map<String, dynamic>? initialPending}) async {
    HapticFeedback.lightImpact();
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final bool? joined = await JoinRoomSheet.show(
      context,
      initialAdmissionData: initialPending,
      onJoin: (String code) async {
        return widget.pathwayRepository.joinRoom(
          code: code,
          userId: user.id,
        );
      },
    );

    if (joined == true) {
      _loadRooms(silent: true);
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
          onRefresh: () => _loadRooms(silent: false),
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Back button if navigated from dashboard or elsewhere
                if (Navigator.of(context).canPop()) ...<Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: textPrimary,
                    ),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(height: 8.0),
                ],

                // Header (Matching Web /learn/rooms 1:1)
                _buildHeader(
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 24.0),

                // Rooms List / Skeleton / Empty State
                if (_isLoading)
                  _buildSkeletonList(isDark: isDark)
                else if (_rooms.isEmpty)
                  _buildEmptyState(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  )
                else
                  _buildRoomsList(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),

                const SizedBox(height: 32.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Rooms',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Access your enrolled rooms, collaborate with mentors, and track your progress.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.4,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12.0),
        ElevatedButton.icon(
          onPressed: () => _handleJoinRoom(),
          icon: const Icon(Icons.add_rounded, size: 16.0),
          label: Text(
            'Join Room',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList({required bool isDark}) {
    return Column(
      children: List<Widget>.generate(3, (_) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: ShimmerLoading(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Top: Header & Metadata
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SkeletonBox(
                            width: 160.0,
                            height: 18.0,
                            borderRadius: 6.0,
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: <Widget>[
                              const SkeletonBox(
                                width: 44.0,
                                height: 16.0,
                                borderRadius: 5.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              const SkeletonCircle(size: 16.0),
                              const SizedBox(width: 6.0),
                              const SkeletonBox(
                                width: 72.0,
                                height: 13.0,
                                borderRadius: 4.0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    const SkeletonBox(
                      width: 32.0,
                      height: 32.0,
                      borderRadius: 10.0,
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const SkeletonBox(
                  width: 110.0,
                  height: 12.0,
                  borderRadius: 4.0,
                ),
                const SizedBox(height: 14.0),
                // Divider line
                Container(
                  height: 1.0,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 12.0),
                // Bottom: Progress bar & status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const <Widget>[
                    SkeletonBox(
                      width: 110.0,
                      height: 12.0,
                      borderRadius: 4.0,
                    ),
                    SkeletonBox(
                      width: 28.0,
                      height: 12.0,
                      borderRadius: 4.0,
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                const SkeletonBox(
                  width: double.infinity,
                  height: 6.0,
                  borderRadius: 3.0,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'No Rooms Joined Yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.0,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Have an invitation code from your mentor, teacher, or school? Enter the 6-character room code to join your room and start learning.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              height: 1.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 20.0),
          ElevatedButton.icon(
            onPressed: () => _handleJoinRoom(),
            icon: const Icon(Icons.key_rounded, size: 16.0),
            label: Text(
              'Enter Room Code',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      children: _rooms.map((RoomModel room) {
        final bool isPending = room.isPending;

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          decoration: BoxDecoration(
            color: isPending
                ? (const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.04 : 0.02))
                : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isPending
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (isPending) {
                  _handleJoinRoom(initialPending: <String, dynamic>{
                    'name': room.name,
                    'section': room.section,
                    'mentorName': room.mentorName,
                  });
                } else {
                  // Direct navigation to room details
                  context.push('/rooms/${room.id}', extra: room);
                }
              },
              borderRadius: BorderRadius.circular(20.0),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Top: Title, Section, Mentor, and Status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                room.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6.0),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 2.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurface
                                          : AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: Text(
                                      room.section,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      color: textSecondary.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 8.0,
                                        backgroundColor: isDark
                                            ? AppColors.darkSurface
                                            : AppColors.lightSurface,
                                        backgroundImage: room.mentorAvatarUrl != null
                                            ? NetworkImage(room.mentorAvatarUrl!)
                                            : NetworkImage(
                                                'https://api.dicebear.com/7.x/avataaars/png?seed=${room.mentorName}',
                                              ) as ImageProvider,
                                      ),
                                      const SizedBox(width: 5.0),
                                      Text(
                                        room.mentorName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8.0),

                        // Status Badge / Arrow
                        if (isPending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 11.0,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  'Pending',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: 32.0,
                            height: 32.0,
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
                              size: 15.0,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14.0),

                    // Curriculum Modules Meta
                    Text(
                      room.curriculumModules.length > 1
                          ? '${room.curriculumModules.length} Modules • ${room.totalTopics} Topics'
                          : '${room.totalTopics} Topics',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14.0),

                    // Progress or Awaiting admission
                    if (!isPending) ...<Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            '${room.completedActivitiesCount} / ${room.totalActivities} completed',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.0,
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            '${room.progressPct}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3.0),
                        child: LinearProgressIndicator(
                          value: (room.progressPct / 100.0).clamp(0.0, 1.0),
                          minHeight: 5.0,
                          backgroundColor: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ] else ...<Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.hourglass_empty_rounded,
                            size: 13.0,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 5.0),
                          Text(
                            'Awaiting admission from mentor',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
