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

    final List<dynamic> result =
        await widget.pathwayRepository.getLearnerRooms(userId ?? 'learner-user');

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

  List<RoomModel> get _pendingInvites => _rooms
      .where((RoomModel c) => c.isPending && c.isEmailInvite)
      .toList();

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
        return widget.pathwayRepository.joinRoom(
          code: code,
          userId: userId!,
        );
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

    final bool ok =
        await widget.pathwayRepository.acceptRoomInvitation(room.id);
    if (!mounted) return;

    setState(() => _processingId = null);
    if (ok) {
      AppToast.showSuccess(context, 'Invitation accepted! Welcome to ${room.name}.');
      _loadRooms(silent: true);
    } else {
      AppToast.showError(context, 'Failed to accept invitation. Please try again.');
    }
  }

  Future<void> _handleDeclineInvite(RoomModel room) async {
    if (_processingId != null) return;
    setState(() => _processingId = room.id);
    HapticFeedback.selectionClick();

    final bool ok =
        await widget.pathwayRepository.declineRoomInvitation(room.id);
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
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                                    final bool ok = await widget.pathwayRepository
                                        .declineRoomInvitation(room.id);
                                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                                    if (ok && mounted) {
                                      AppToast.showInfo(context, 'Invitation declined.');
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
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
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
                                    final bool ok = await widget.pathwayRepository
                                        .acceptRoomInvitation(room.id);
                                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
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
                              foregroundColor:
                                  isDark ? AppColors.onPrimaryDark : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18.0,
                                    height: 18.0,
                                    child: CircularProgressIndicator(strokeWidth: 2.0),
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
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
                              foregroundColor:
                                  isDark ? AppColors.onPrimaryDark : Colors.white,
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
                          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                        height: 36.0,
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

                      // Pending Email Invitations Alert Banner (Matching Web lines 213-234)
                      if (pendingInvites.isNotEmpty) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 38.0,
                                height: 38.0,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.mark_email_unread_rounded,
                                  color: Color(0xFF10B981),
                                  size: 20.0,
                                ),
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
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      'Accept your invitation below to join the cohort and access learning modules.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.0,
                                        height: 1.35,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7.0,
                                  vertical: 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'Action Needed',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),
                      ],

                      // Summary Counter Header (Matching Web 1:1)
                      if (!_isLoading && displayRooms.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            'Showing ${displayRooms.length} hub${displayRooms.length == 1 ? '' : 's'}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
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
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final RoomModel room = displayRooms[index];
                        return _buildHubCard(
                          room: room,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      },
                      childCount: displayRooms.length,
                    ),
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

    // Distinct contextual border & surface tints matching Web 1:1
    final Color cardBg = isEmailInvite
        ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.05 : 0.02)
        : isPending
            ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.04 : 0.02)
            : (isDark ? AppColors.darkSurfaceCard : Colors.white);

    final Color cardBorder = isEmailInvite
        ? const Color(0xFF10B981).withValues(alpha: 0.30)
        : isPending
            ? const Color(0xFFF59E0B).withValues(alpha: 0.30)
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isEmailInvite) {
              _showInvitationSheet(room);
            } else if (isPending) {
              _handleJoinRoom(initialPending: <String, dynamic>{
                'name': room.name,
                'section': room.section,
                'mentorName': room.mentorName,
              });
            } else {
              // Direct navigation to hub details
              context.push('/hubs/${room.id}', extra: room);
            }
          },
          borderRadius: BorderRadius.circular(18.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 1. Top Row: Title, Section Badge & Status Pill
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
                              // Section Badge
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
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ),

                              // Status Badge
                              if (isEmailInvite)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                    vertical: 2.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.0),
                                    border: Border.all(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.mail_outline_rounded,
                                        size: 10.5,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        'Invitation',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isPending)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                    vertical: 2.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.0),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 10.5,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 3.5),
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
                              else if (progressPct >= 100)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                    vertical: 2.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6.0),
                                    border: Border.all(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 10.5,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        'Completed',
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),

                // 2. Description (Matching Web)
                Text(
                  room.description.trim().isNotEmpty
                      ? room.description.trim()
                      : isEmailInvite
                          ? 'Invited by ${room.mentorName} to collaborate and learn.'
                          : 'Collaborative workspace for exercises, coding challenges, and mentoring.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    height: 1.45,
                    color: textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12.0),

                // 3. Mobile Meta Line: Mentor + Activities / Modules
                Row(
                  children: <Widget>[
                    Builder(
                      builder: (BuildContext _) {
                        final bool isTestEnv = WidgetsBinding.instance.runtimeType
                            .toString()
                            .contains('Test');
                        final String? avatarUrl = room.mentorAvatarUrl ??
                            (!isTestEnv
                                ? 'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(room.mentorName)}'
                                : null);

                        return CircleAvatar(
                          radius: 8.5,
                          backgroundColor: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          backgroundImage:
                              avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  room.mentorName.isNotEmpty
                                      ? room.mentorName[0].toUpperCase()
                                      : 'M',
                                  style: TextStyle(
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      room.mentorName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Text(
                        '·',
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      isPending
                          ? '${room.totalActivities} activities'
                          : '${room.curriculumModules.length} ${room.curriculumModules.length == 1 ? 'module' : 'modules'}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isEmailInvite) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text(
                          '·',
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Invited you',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14.0),

                // 4. Progress or Action Area (Strict Web 1:1 Parity)
                if (isEmailInvite) ...<Widget>[
                  // Direct Accept / Decline Buttons (Matching Web lines 424-448)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: isProcessing ? null : () => _handleDeclineInvite(room),
                        icon: const Icon(Icons.close_rounded, size: 14.0),
                        label: Text(
                          'Decline',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSecondary,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 8.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : () => _handleAcceptInvite(room),
                        icon: isProcessing
                            ? const SizedBox(
                                width: 13.0,
                                height: 13.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 14.0),
                        label: Text(
                          'Accept',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor:
                              isDark ? AppColors.onPrimaryDark : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isPending) ...<Widget>[
                  // Code Pending Awaiting Admission (Matching Web lines 533-541)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.access_time_rounded,
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
                      ElevatedButton.icon(
                        onPressed: () => _handleJoinRoom(initialPending: <String, dynamic>{
                          'name': room.name,
                          'section': room.section,
                          'mentorName': room.mentorName,
                        }),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 13.0),
                        label: Text(
                          'View Status',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFF59E0B),
                          elevation: 0,
                          side: const BorderSide(
                            color: Color(0xFFF59E0B),
                            width: 0.8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 6.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...<Widget>[
                  // Active Room: Progress bar with strict 0% handling + Action CTA
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                            '$progressPct%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: progressPct > 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: progressPct >= 100
                                  ? const Color(0xFF10B981)
                                  : progressPct > 0
                                      ? AppColors.primary
                                      : textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),

                      // Strict 0% Handling Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999.0),
                        child: LayoutBuilder(
                          builder: (BuildContext ctx, BoxConstraints constraints) {
                            final double totalWidth = constraints.maxWidth;
                            final double fillWidth = progressPct == 0
                                ? 0.0
                                : (totalWidth * (progressPct / 100.0)).clamp(0.0, totalWidth);

                            return Stack(
                              children: <Widget>[
                                Container(
                                  height: 5.0,
                                  width: totalWidth,
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : AppColors.lightSurface,
                                ),
                                if (fillWidth > 0)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOut,
                                    height: 5.0,
                                    width: fillWidth,
                                    decoration: BoxDecoration(
                                      color: progressPct >= 100
                                          ? const Color(0xFF10B981)
                                          : AppColors.primary,
                                      borderRadius: BorderRadius.circular(999.0),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14.0),

                      // Bottom CTA (Matching Web: Open Hub / Continue / Review Hub)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.push('/hubs/${room.id}', extra: room);
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14.0),
                          label: Text(
                            progressPct >= 100
                                ? 'Review Hub'
                                : progressPct > 0
                                    ? 'Continue'
                                    : 'Open Hub',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: progressPct >= 100
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : progressPct > 0
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightSurface),
                            foregroundColor: progressPct >= 100
                                ? const Color(0xFF10B981)
                                : progressPct > 0
                                    ? (isDark
                                        ? AppColors.onPrimaryDark
                                        : Colors.white)
                                    : textPrimary,
                            side: progressPct >= 100
                                ? const BorderSide(
                                    color: Color(0xFF10B981),
                                    width: 0.8,
                                  )
                                : (progressPct == 0
                                    ? BorderSide(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      )
                                    : null),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 7.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999.0),
                            ),
                          ),
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
  }

  Widget _buildSkeletonList({required bool isDark}) {
    return Column(
      children: List<Widget>.generate(3, (_) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: ShimmerLoading(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const <Widget>[
                    SkeletonBox(width: 150.0, height: 18.0, borderRadius: 6.0),
                    SkeletonBox(width: 50.0, height: 16.0, borderRadius: 6.0),
                  ],
                ),
                const SizedBox(height: 10.0),
                const SkeletonBox(width: 220.0, height: 12.0, borderRadius: 4.0),
                const SizedBox(height: 14.0),
                Row(
                  children: const <Widget>[
                    SkeletonCircle(size: 17.0),
                    SizedBox(width: 6.0),
                    SkeletonBox(width: 70.0, height: 12.0, borderRadius: 4.0),
                    SizedBox(width: 8.0),
                    SkeletonBox(width: 60.0, height: 12.0, borderRadius: 4.0),
                  ],
                ),
                const SizedBox(height: 14.0),
                const SkeletonBox(width: double.infinity, height: 5.0, borderRadius: 999.0),
                const SizedBox(height: 12.0),
                Align(
                  alignment: Alignment.centerRight,
                  child: const SkeletonBox(width: 90.0, height: 28.0, borderRadius: 999.0),
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

    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
                isSearchActive
                    ? Icons.search_off_rounded
                    : _activeFilter == 'pending'
                        ? Icons.hourglass_empty_rounded
                        : Icons.hub_outlined,
                size: 26.0,
                color: textSecondary,
              ),
            ),
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
                fontSize: 12.5,
                height: 1.4,
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
                  foregroundColor:
                      isDark ? AppColors.onPrimaryDark : Colors.white,
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
