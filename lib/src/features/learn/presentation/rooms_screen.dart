import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/filter_tab_bar.dart';
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
  String _activeFilter = 'all'; // 'all' | 'active' | 'pending'
  String _searchQuery = '';
  String? _processingId;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollingTimer;

  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms({bool silent = false}) async {
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}

    if (!silent) {
      setState(() => _isLoading = true);
    }

    final List<dynamic> result = await widget.pathwayRepository.getLearnerRooms(
      userId ?? 'learner-user',
    );

    if (mounted) {
      setState(() {
        _rooms = result.cast<RoomModel>();
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeAndPolling() {
    User? user;
    try {
      user = Supabase.instance.client.auth.currentUser;
    } catch (_) {}
    if (user == null) return;

    try {
      final SupabaseClient supabase = Supabase.instance.client;
      _realtimeChannel = supabase
          .channel('mobile-learner-admissions-${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'hub_members',
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

    // Periodic fast polling if pending rooms exist
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final bool hasPending = _rooms.any((RoomModel r) => r.isPending);
      if (hasPending) {
        _loadRooms(silent: true);
      }
    });
  }

  // Filtered rooms logic matching Web /learn/hubs 1:1
  List<RoomModel> get _activeRooms =>
      _rooms.where((RoomModel c) => !c.isPending).toList();

  List<RoomModel> get _pendingRooms =>
      _rooms.where((RoomModel c) => c.isPending).toList();

  List<RoomModel> get _pendingInvites =>
      _rooms.where((RoomModel c) => c.isPending && c.isEmailInvite).toList();

  List<RoomModel> get _filteredRooms {
    return _rooms.where((RoomModel c) {
      if (_activeFilter == 'active' && c.isPending) return false;
      if (_activeFilter == 'pending' && !c.isPending) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final String q = _searchQuery.toLowerCase().trim();
        final bool matchesName = c.name.toLowerCase().contains(q);
        final bool matchesSection = c.section.toLowerCase().contains(q);
        final bool matchesMentor = c.mentorName.toLowerCase().contains(q);
        final bool matchesDesc = c.description.toLowerCase().contains(q);
        if (!matchesName && !matchesSection && !matchesMentor && !matchesDesc) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _handleJoinRoom({Map<String, dynamic>? initialPending}) async {
    HapticFeedback.lightImpact();
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}
    if (userId == null) return;

    final bool? joined = await JoinRoomSheet.show(
      context,
      initialAdmissionData: initialPending,
      onJoin: (String code) async {
        return widget.pathwayRepository.joinRoom(code: code, userId: userId!);
      },
    );

    if (joined == true) {
      _loadRooms(silent: true);
    }
  }

  Future<void> _handleAcceptInvite(RoomModel room) async {
    if (_processingId != null) return;
    setState(() => _processingId = room.id);
    HapticFeedback.mediumImpact();

    final bool ok = await widget.pathwayRepository.acceptRoomInvitation(
      room.id,
    );
    if (!mounted) return;

    setState(() => _processingId = null);
    if (ok) {
      AppToast.showSuccess(
        context,
        'Invitation accepted! Welcome to ${room.name}.',
      );
      _loadRooms(silent: true);
    } else {
      AppToast.showError(
        context,
        'Failed to accept invitation. Please try again.',
      );
    }
  }

  Future<void> _handleDeclineInvite(RoomModel room) async {
    if (_processingId != null) return;
    setState(() => _processingId = room.id);
    HapticFeedback.selectionClick();

    final bool ok = await widget.pathwayRepository.declineRoomInvitation(
      room.id,
    );
    if (!mounted) return;

    setState(() => _processingId = null);
    if (ok) {
      AppToast.showInfo(context, 'Invitation declined.');
      _loadRooms(silent: true);
    } else {
      AppToast.showError(context, 'Failed to decline invitation.');
    }
  }

  Future<void> _showInvitationSheet(RoomModel room) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (BuildContext sheetCtx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 36.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Container(
                      width: 52.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        color: Color(0xFF10B981),
                        size: 26.0,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'Hub Invitation',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '${room.mentorName} invited you to join ${room.name} (${room.section}).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        height: 1.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() => isSubmitting = true);
                                    HapticFeedback.selectionClick();
                                    final bool ok = await widget
                                        .pathwayRepository
                                        .declineRoomInvitation(room.id);
                                    if (sheetCtx.mounted) {
                                      Navigator.of(sheetCtx).pop();
                                    }
                                    if (ok && mounted) {
                                      AppToast.showInfo(
                                        context,
                                        'Invitation declined.',
                                      );
                                      _loadRooms(silent: true);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: Text(
                              'Decline',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() => isSubmitting = true);
                                    HapticFeedback.mediumImpact();
                                    final bool ok = await widget
                                        .pathwayRepository
                                        .acceptRoomInvitation(room.id);
                                    if (sheetCtx.mounted) {
                                      Navigator.of(sheetCtx).pop();
                                    }
                                    if (ok && mounted) {
                                      AppToast.showSuccess(
                                        context,
                                        'Welcome to ${room.name}!',
                                      );
                                      _loadRooms(silent: true);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: isDark
                                  ? AppColors.onPrimaryDark
                                  : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18.0,
                                    height: 18.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                : Text(
                                    'Accept',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.0,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

    final List<RoomModel> displayRooms = _filteredRooms;
    final List<RoomModel> pendingInvites = _pendingInvites;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _loadRooms(silent: false),
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              // ── Header & Search Controls (Matching Web 1:1) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Optional back button
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
                        const SizedBox(height: 4.0),
                      ],

                      // Screen Title & Action Cluster (Matching Web 1:1)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'My Hubs',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22.0,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Access your enrolled hubs, collaborate with mentors, and track your progress.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
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
                              'Join Hub',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: isDark
                                  ? AppColors.onPrimaryDark
                                  : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                                vertical: 10.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18.0),

                      // Shadcn Search Input (Matching Web Filters)
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
                          controller: _searchController,
                          onChanged: (String val) {
                            setState(() {
                              _searchQuery = val;
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
                            hintText: 'Search hubs...',
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
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 17.0,
                                      color: textSecondary,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 12.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14.0),

                      // Shadcn Filter Tabs with Dynamic Count Badges (Matching Web 1:1)
                      FilterTabBar(
                        tabs: <FilterTabItem>[
                          FilterTabItem(
                            id: 'all',
                            label: 'All Hubs',
                            count: _rooms.length,
                          ),
                          FilterTabItem(
                            id: 'active',
                            label: 'Active',
                            count: _activeRooms.length,
                          ),
                          FilterTabItem(
                            id: 'pending',
                            label: 'Pending',
                            count: _pendingRooms.length,
                          ),
                        ],
                        selectedId: _activeFilter,
                        onTabSelected: (String filterId) {
                          setState(() {
                            _activeFilter = filterId;
                          });
                        },
                      ),
                      const SizedBox(height: 16.0),

                      // Pending invitations: a plain notice, no tinted card
                      if (pendingInvites.isNotEmpty) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                              bottom: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.mail_outline_rounded,
                                size: 20.0,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      pendingInvites.length == 1
                                          ? 'You have a pending hub invitation'
                                          : 'You have ${pendingInvites.length} pending hub invitations',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      'Accept it below to join the cohort and see its modules.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.0,
                                        height: 1.4,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8.0),
                      ],

                      // Summary Counter Header (Matching Web 1:1)
                      if (!_isLoading && displayRooms.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text: '${displayRooms.length}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' hub${displayRooms.length == 1 ? '' : 's'}',
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

              // ── Hubs List / Empty State / Skeleton ──
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 96.0),
                  sliver: SliverToBoxAdapter(
                    child: _buildSkeletonList(isDark: isDark),
                  ),
                )
              else if (displayRooms.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 96.0),
                  sliver: SliverToBoxAdapter(
                    child: _buildEmptyState(
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 96.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((
                      BuildContext context,
                      int index,
                    ) {
                      final RoomModel room = displayRooms[index];
                      return _buildHubCard(
                        room: room,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      );
                    }, childCount: displayRooms.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubCard({
    required RoomModel room,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isPending = room.isPending;
    final bool isEmailInvite = room.isEmailInvite;
    final int progressPct = room.progressPct;
    final bool isProcessing = _processingId == room.id;
    final Color hairline = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    void openRoom() {
      HapticFeedback.lightImpact();
      if (isEmailInvite) {
        _showInvitationSheet(room);
      } else if (isPending) {
        _handleJoinRoom(
          initialPending: <String, dynamic>{
            'name': room.name,
            'section': room.section,
            'mentorName': room.mentorName,
          },
        );
      } else {
        context.push('/hubs/${room.id}', extra: room);
      }
    }

    // Status is plain text with an icon, never a coloured badge.
    final String? statusLabel = isEmailInvite
        ? 'Invitation'
        : isPending
        ? 'Pending'
        : progressPct >= 100
        ? 'Completed'
        : null;
    final IconData? statusIcon = isEmailInvite
        ? Icons.mail_outline_rounded
        : isPending
        ? Icons.access_time_rounded
        : progressPct >= 100
        ? Icons.check_rounded
        : null;

    final ButtonStyle outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: textPrimary,
      minimumSize: const Size(48.0, 44.0),
      side: BorderSide(
        color: isDark ? AppColors.darkBorderVariant : AppColors.lightBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
    );
    final TextStyle buttonText = GoogleFonts.plusJakartaSans(
      fontSize: 13.0,
      fontWeight: FontWeight.w600,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: hairline, width: 1.0)),
      ),
      child: InkWell(
        onTap: openRoom,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      room.name,
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
                  ),
                  if (statusLabel != null) ...<Widget>[
                    const SizedBox(width: 12.0),
                    Padding(
                      padding: const EdgeInsets.only(top: 3.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(statusIcon, size: 15.0, color: textSecondary),
                          const SizedBox(width: 4.0),
                          Text(
                            statusLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (room.section.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2.0),
                Text(
                  room.section,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8.0),
              Text(
                room.description.trim().isNotEmpty
                    ? room.description.trim()
                    : isEmailInvite
                    ? 'Invited by ${room.mentorName} to collaborate and learn.'
                    : 'Collaborative workspace for exercises, coding challenges, and mentoring.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  height: 1.45,
                  color: textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10.0),
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      room.mentorName,
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
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: isPending
                              ? '${room.totalActivities}'
                              : '${room.curriculumModules.length}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: isPending
                              ? ' activities'
                              : (room.curriculumModules.length == 1
                                    ? ' module'
                                    : ' modules'),
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
              if (isEmailInvite)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: isProcessing
                          ? null
                          : () => _handleDeclineInvite(room),
                      style: TextButton.styleFrom(
                        foregroundColor: textSecondary,
                        minimumSize: const Size(48.0, 44.0),
                      ),
                      child: Text(
                        'Decline',
                        style: buttonText.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () => _handleAcceptInvite(room),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: isDark
                            ? AppColors.onPrimaryDark
                            : Colors.white,
                        elevation: 0,
                        minimumSize: const Size(48.0, 44.0),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 16.0,
                              height: 16.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            )
                          : Text('Accept', style: buttonText),
                    ),
                  ],
                )
              else if (isPending)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Waiting for the mentor to admit you',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    OutlinedButton(
                      onPressed: openRoom,
                      style: outlinedStyle,
                      child: Text('View status', style: buttonText),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999.0),
                            child: SizedBox(
                              height: 4.0,
                              child: LinearProgressIndicator(
                                // Exactly empty at 0% (AGENTS.md 2.3).
                                value: progressPct <= 0
                                    ? 0.0
                                    : (progressPct / 100.0).clamp(0.0, 1.0),
                                backgroundColor: isDark
                                    ? AppColors.darkSurfaceHighest
                                    : AppColors.lightBorder,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          '$progressPct%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${room.completedActivitiesCount} of ${room.totalActivities} activities done',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: openRoom,
                          style: outlinedStyle,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                progressPct >= 100
                                    ? 'Review Hub'
                                    : progressPct > 0
                                    ? 'Continue'
                                    : 'Open Hub',
                                style: buttonText,
                              ),
                              const SizedBox(width: 4.0),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14.0,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList({required bool isDark}) {
    return Column(
      children: List<Widget>.generate(3, (_) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: const ShimmerLoading(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 180.0, height: 18.0, borderRadius: 4.0),
                SizedBox(height: 10.0),
                SkeletonBox(
                  width: double.infinity,
                  height: 12.0,
                  borderRadius: 4.0,
                ),
                SizedBox(height: 6.0),
                SkeletonBox(width: 200.0, height: 12.0, borderRadius: 4.0),
                SizedBox(height: 16.0),
                SkeletonBox(
                  width: double.infinity,
                  height: 4.0,
                  borderRadius: 999.0,
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
    final bool isSearchActive = _searchQuery.trim().isNotEmpty;
    final bool isFilterActive = _activeFilter != 'all';

    final String heading = isSearchActive
        ? 'No hubs matching "$_searchQuery"'
        : _activeFilter == 'pending'
        ? 'No pending admission requests'
        : _activeFilter == 'active'
        ? 'No active hubs yet'
        : 'No Hubs Joined Yet';

    final String caption = isSearchActive
        ? 'Try searching for a different hub name, section, or mentor.'
        : _activeFilter == 'pending'
        ? 'You have no pending requests or invitations awaiting admission.'
        : 'Have an invitation code from your mentor or instructor? Enter the 6-character hub code to join.';

    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 16.0),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                height: 1.45,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 16.0),
            if (isSearchActive || isFilterActive)
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _activeFilter = 'all';
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
              )
            else
              ElevatedButton.icon(
                onPressed: () => _handleJoinRoom(),
                icon: const Icon(Icons.key_rounded, size: 14.0),
                label: Text(
                  'Enter Hub Code',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: isDark
                      ? AppColors.onPrimaryDark
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
