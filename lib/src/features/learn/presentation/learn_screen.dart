import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/data/supabase_notification_repository.dart';
import '../../notifications/domain/notification_model.dart';
import '../../notifications/presentation/widgets/notification_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/supabase_profile_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/learn_dashboard_data.dart';
import '../domain/pathway_model.dart';
import 'widgets/activity_heatmap.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({
    super.key,
    this.profileRepository = const SupabaseProfileRepository(),
    this.pathwayRepository = const SupabasePathwayRepository(),
    this.notificationRepository = const SupabaseNotificationRepository(),
  });

  final ProfileRepository profileRepository;
  final PathwayRepository pathwayRepository;
  final NotificationRepository notificationRepository;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  ProfileModel? _profile;
  LearnDashboardData? _dashboardData;
  List<NotificationModel> _notifications = <NotificationModel>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _profile = SupabaseProfileRepository.cachedProfile;
    _dashboardData = SupabasePathwayRepository.cachedData;
    _isLoading = _dashboardData == null;
    SupabasePathwayRepository.catalogRefreshNotifier
        .addListener(_onCatalogRefresh);
    _loadData();
  }

  @override
  void dispose() {
    SupabasePathwayRepository.catalogRefreshNotifier
        .removeListener(_onCatalogRefresh);
    super.dispose();
  }

  void _onCatalogRefresh() {
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final results = await Future.wait([
          widget.profileRepository.getProfile(user.id),
          widget.pathwayRepository.getLearnDashboardData(user.id),
          widget.notificationRepository.getNotifications(user.id),
        ]);

        if (mounted) {
          setState(() {
            _profile = results[0] as ProfileModel?;
            _dashboardData = results[1] as LearnDashboardData?;
            _notifications = results[2] as List<NotificationModel>;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

    final String firstName = _profile?.firstName?.isNotEmpty == true
        ? _profile!.firstName!
        : (Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'Developer');

    final String avatarUrl = _profile?.avatarUrl?.isNotEmpty == true
        ? _profile!.avatarUrl!
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=$firstName';

    final PathwayModel? activePathway = _dashboardData?.activePathway;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          child: _isLoading && _dashboardData == null
              ? _buildDashboardSkeleton(isDark: isDark)
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // ── 1. Top Header Row (Matching Web shadcn Header) ──
                      _buildTopGreeting(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        firstName: firstName,
                        avatarUrl: avatarUrl,
                      ),
                      const SizedBox(height: 20.0),

                      // ── 2. HERO: RESUME ACTIVE LEARNING (Matching Web shadcn Card) ──
                      if (activePathway != null) ...<Widget>[
                        _buildHeroPathwayCard(
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          pathway: activePathway,
                        ),
                        const SizedBox(height: 20.0),
                      ],

                      // ── 3. FULL-WIDTH PRACTICE ACTIVITY & ANNUAL HEATMAP (Matching Web shadcn Heatmap) ──
                      ActivityHeatmap(
                        submissions: _dashboardData?.submissions ?? const <DashboardSubmission>[],
                        totalActiveDays: _dashboardData?.totalActiveDays ?? 0,
                        currentStreak: _dashboardData?.currentStreak ?? 0,
                      ),
                      const SizedBox(height: 32.0),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP GREETING & NOTIFICATION HEADER (Matching Web shadcn Header 1:1)
  // ===========================================================================
  Widget _buildTopGreeting({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required String firstName,
    required String avatarUrl,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.6)
                : AppColors.lightBorder.withValues(alpha: 0.8),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Squircle Avatar + Greeting Copy
          Expanded(
            child: Row(
              children: <Widget>[
                Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.0),
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          firstName.isNotEmpty ? firstName[0].toUpperCase() : 'D',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
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
                        'Welcome back, $firstName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Pick up where you left off or explore new challenges.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
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
          const SizedBox(width: 12.0),

          // Notification Bell
          _buildNotificationBell(isDark, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final int unreadCount =
        _notifications.where((NotificationModel n) => !n.isRead).length;

    return InkWell(
      onTap: _handleOpenNotifications,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: 38.0,
        height: 38.0,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: unreadCount > 0
                ? AppColors.primary.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              unreadCount > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 19.0,
              color: unreadCount > 0 ? textPrimary : textSecondary,
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8.0,
                right: 8.0,
                child: Container(
                  width: 7.0,
                  height: 7.0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        blurRadius: 4.0,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleOpenNotifications() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    NotificationSheet.show(
      context,
      userId: user.id,
      repository: widget.notificationRepository,
      initialNotifications: _notifications,
      onChanged: () {
        widget.notificationRepository.getNotifications(user.id).then((list) {
          if (mounted) setState(() => _notifications = list);
        });
      },
    );
  }

  // ===========================================================================
  // 2. HERO ACTIVE PATHWAY CARD (Matching Web shadcn Card 1:1)
  // ===========================================================================
  Widget _buildHeroPathwayCard({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required PathwayModel pathway,
  }) {
    // Strict 0% Handling per AGENTS.md rule 2.3
    final double progressValue = pathway.completion <= 0
        ? 0.0
        : (pathway.completion / 100.0).clamp(0.0, 1.0);

    final String ctaLabel = pathway.completion >= 100
        ? 'Review Track'
        : pathway.completion > 0
            ? 'Continue Learning'
            : 'Start Learning';

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row: Minimalist LanguageAvatarStack on left, {completion}% Complete on right per AGENTS.md
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              LanguageAvatarStack(
                languages: pathway.stack.isNotEmpty
                    ? pathway.stack
                    : <String>[pathway.language],
                size: 32.0,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pathway.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      pathway.description.isNotEmpty
                          ? pathway.description
                          : 'Continue practicing structured lessons and algorithmic problems.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Action Button: Full-width shadcn button
          SizedBox(
            width: double.infinity,
            height: 44.0,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/modules/${pathway.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 18.0,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    ctaLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.onPrimaryDark : Colors.white,
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
          const SizedBox(height: 14.0),

          // Progress with Inline Percentage
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Progress',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  Text(
                    '${pathway.completion}% Complete',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.0),
                child: SizedBox(
                  height: 6.0,
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. SKELETON LOADING STATE (Matching Web shadcn LearnDashboardSkeleton 1:1)
  // ===========================================================================
  Widget _buildDashboardSkeleton({required bool isDark}) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Top Header Skeleton
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: <Widget>[
                  const SkeletonBox(
                    width: 44.0,
                    height: 44.0,
                    borderRadius: 14.0,
                  ),
                  const SizedBox(width: 12.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      SkeletonBox(width: 150.0, height: 16.0, borderRadius: 4.0),
                      SizedBox(height: 6.0),
                      SkeletonBox(width: 220.0, height: 12.0, borderRadius: 4.0),
                    ],
                  ),
                  const Spacer(),
                  const SkeletonBox(width: 38.0, height: 38.0, borderRadius: 12.0),
                ],
              ),
            ),
            const SizedBox(height: 20.0),

            // Hero Card Skeleton
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Row(
                    children: <Widget>[
                      SkeletonBox(width: 64.0, height: 32.0, borderRadius: 16.0),
                      SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SkeletonBox(width: 180.0, height: 16.0, borderRadius: 4.0),
                            SizedBox(height: 6.0),
                            SkeletonBox(width: double.infinity, height: 12.0, borderRadius: 4.0),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.0),
                  SkeletonBox(width: double.infinity, height: 44.0, borderRadius: 12.0),
                  SizedBox(height: 14.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      SkeletonBox(width: 60.0, height: 12.0, borderRadius: 4.0),
                      SkeletonBox(width: 80.0, height: 12.0, borderRadius: 4.0),
                    ],
                  ),
                  SizedBox(height: 6.0),
                  SkeletonBox(width: double.infinity, height: 6.0, borderRadius: 999.0),
                ],
              ),
            ),
            const SizedBox(height: 20.0),

            // Heatmap Card Skeleton
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      SkeletonBox(width: 120.0, height: 15.0, borderRadius: 4.0),
                      SkeletonBox(width: 110.0, height: 13.0, borderRadius: 4.0),
                    ],
                  ),
                  SizedBox(height: 8.0),
                  SkeletonBox(width: 160.0, height: 11.0, borderRadius: 4.0),
                  SizedBox(height: 18.0),
                  SkeletonBox(width: double.infinity, height: 100.0, borderRadius: 8.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
