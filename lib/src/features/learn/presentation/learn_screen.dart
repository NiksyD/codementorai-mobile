import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_toast.dart';
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
  int _walletBalance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _profile = SupabaseProfileRepository.cachedProfile;
    _dashboardData = SupabasePathwayRepository.cachedData;
    _isLoading = _dashboardData == null;
    SupabasePathwayRepository.catalogRefreshNotifier.addListener(
      _onCatalogRefresh,
    );
    SupabaseProfileRepository.profileChangeNotifier.addListener(
      _onProfileChange,
    );
    _loadData();
  }

  @override
  void dispose() {
    SupabasePathwayRepository.catalogRefreshNotifier.removeListener(
      _onCatalogRefresh,
    );
    SupabaseProfileRepository.profileChangeNotifier.removeListener(
      _onProfileChange,
    );
    super.dispose();
  }

  void _onProfileChange() {
    final ProfileModel? updated =
        SupabaseProfileRepository.profileChangeNotifier.value;
    if (updated != null && mounted) {
      setState(() {
        _profile = updated;
      });
    }
  }

  User? _getAuthUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _onCatalogRefresh() {
    _loadData();
  }

  Future<int> _fetchWalletBalance(String userId) async {
    try {
      String resolvedId = userId;
      if (resolvedId.isEmpty || resolvedId == 'current_user') {
        resolvedId = Supabase.instance.client.auth.currentUser?.id ?? '';
      }
      if (resolvedId.isEmpty) return 0;

      final dynamic res = await Supabase.instance.client
          .from('user_wallets')
          .select('balance_coins')
          .eq('user_id', resolvedId)
          .maybeSingle();

      if (res is Map<String, dynamic>) {
        final dynamic coins = res['balance_coins'];
        if (coins is num) {
          return coins.toInt();
        }
      } else if (res == null) {
        // Auto-provision 250 welcome bonus if user has no wallet row yet
        try {
          final dynamic inserted = await Supabase.instance.client
              .from('user_wallets')
              .insert(<String, dynamic>{
                'user_id': resolvedId,
                'balance_coins': 250,
                'total_earned_coins': 0,
              })
              .select('balance_coins')
              .maybeSingle();

          if (inserted is Map<String, dynamic> &&
              inserted['balance_coins'] is num) {
            await Supabase.instance.client
                .from('coin_transactions')
                .insert(<String, dynamic>{
                  'user_id': resolvedId,
                  'amount_coins': 250,
                  'balance_after': 250,
                  'tx_type': 'welcome_bonus',
                  'reference_id': 'onboarding_gift',
                  'description':
                      'Welcome to CodeMentorAI! 250 CodeCoins starter bonus',
                });
            return (inserted['balance_coins'] as num).toInt();
          }
        } catch (_) {}
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _loadData() async {
    final User? user = _getAuthUser();
    final String userId = user?.id ?? _profile?.userId ?? 'current_user';
    try {
      final results = await Future.wait([
        widget.profileRepository.getProfile(userId),
        widget.pathwayRepository.getLearnDashboardData(userId),
        widget.notificationRepository.getNotifications(userId),
        _fetchWalletBalance(userId),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as ProfileModel?;
          _dashboardData = results[1] as LearnDashboardData?;
          _notifications = results[2] as List<NotificationModel>;
          _walletBalance = results[3] as int;
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

    final User? authUser = _getAuthUser();
    final Map<String, dynamic> authMeta =
        authUser?.userMetadata ?? <String, dynamic>{};

    final String firstName = _profile?.firstName?.isNotEmpty == true
        ? _profile!.firstName!
        : ((authMeta['first_name'] as String?) ??
              (authMeta['full_name'] as String?)?.split(' ').first ??
              authUser?.email?.split('@').first ??
              'Developer');

    final String? resolvedAvatar = (_profile?.avatarUrl?.isNotEmpty == true)
        ? _profile!.avatarUrl
        : ((authMeta['avatar_url'] as String?) ??
              (authMeta['picture'] as String?));

    final String avatarUrl =
        (resolvedAvatar != null && resolvedAvatar.trim().isNotEmpty)
        ? resolvedAvatar.trim()
        : '';

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
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
                      const SizedBox(height: 28.0),

                      // ── 2. HERO: RESUME ACTIVE LEARNING (Matching Web shadcn Card) ──
                      if (activePathway != null) ...<Widget>[
                        _buildHeroPathwayCard(
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          pathway: activePathway,
                        ),
                        const SizedBox(height: 24.0),
                        Divider(
                          height: 1.0,
                          thickness: 1.0,
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                        const SizedBox(height: 20.0),
                      ],

                      // ── 3. FULL-WIDTH PRACTICE ACTIVITY & ANNUAL HEATMAP (Matching Web shadcn Heatmap) ──
                      ActivityHeatmap(
                        submissions:
                            _dashboardData?.submissions ??
                            const <DashboardSubmission>[],
                        totalActiveDays: _dashboardData?.totalActiveDays ?? 0,
                        currentStreak: _dashboardData?.currentStreak ?? 0,
                      ),
                      const SizedBox(height: 96.0),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. GREETING ROW: avatar, name, and three quiet status items
  // ===========================================================================
  Widget _buildTopGreeting({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required String firstName,
    required String avatarUrl,
  }) {
    final String initial = firstName.isNotEmpty
        ? firstName[0].toUpperCase()
        : 'D';
    final Widget initialMark = Center(
      child: Text(
        initial,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16.0,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceCard
                  : AppColors.lightSurfaceCard,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    key: ValueKey<String>(avatarUrl),
                    fit: BoxFit.cover,
                    loadingBuilder:
                        (
                          BuildContext context,
                          Widget child,
                          ImageChunkEvent? progress,
                        ) => progress == null ? child : initialMark,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => initialMark,
                  )
                : initialMark,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Welcome back,',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  firstName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17.0,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildStatItem(
            icon: Icons.monetization_on_outlined,
            value: _walletBalance > 9999
                ? '${(_walletBalance / 1000).toStringAsFixed(1)}k'
                : '$_walletBalance',
            semanticLabel: 'CodeCoins',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            message:
                'CodeCoins: $_walletBalance. Complete practice and challenges to earn more.',
          ),
          _buildStatItem(
            icon: Icons.local_fire_department_outlined,
            value: '${_dashboardData?.currentStreak ?? 0}d',
            semanticLabel: 'Day streak',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            message: (_dashboardData?.currentStreak ?? 0) > 0
                ? '${_dashboardData?.currentStreak}-day streak. Keep it going.'
                : 'Complete a practice or challenge today to start a streak.',
          ),
          _buildNotificationBell(textPrimary, textSecondary),
        ],
      ),
    );
  }

  /// Icon and number with no box around them. The tap area stays 48dp tall.
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String semanticLabel,
    required Color textPrimary,
    required Color textSecondary,
    required String message,
  }) {
    return Semantics(
      button: true,
      label: '$semanticLabel $value',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          AppToast.showInfo(context, message);
        },
        borderRadius: BorderRadius.circular(8.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48.0, minWidth: 48.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(icon, size: 18.0, color: textSecondary),
                ),
                const SizedBox(width: 4.0),
                ExcludeSemantics(
                  child: Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBell(Color textPrimary, Color textSecondary) {
    final int unreadCount = _notifications
        .where((NotificationModel n) => !n.isRead)
        .length;

    return Semantics(
      button: true,
      label: unreadCount > 0
          ? 'Notifications, $unreadCount unread'
          : 'Notifications',
      child: InkWell(
        onTap: _handleOpenNotifications,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48.0,
          height: 48.0,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(
                unreadCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                size: 22.0,
                color: unreadCount > 0 ? textPrimary : textSecondary,
              ),
              if (unreadCount > 0)
                const Positioned(
                  top: 12.0,
                  right: 13.0,
                  child: SizedBox(
                    width: 7.0,
                    height: 7.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleOpenNotifications() {
    final User? user = _getAuthUser();
    final String userId = user?.id ?? _profile?.userId ?? '';
    if (userId.isEmpty) return;

    NotificationSheet.show(
      context,
      userId: userId,
      repository: widget.notificationRepository,
      initialNotifications: _notifications,
      onChanged: () {
        widget.notificationRepository.getNotifications(userId).then((list) {
          if (mounted) setState(() => _notifications = list);
        });
      },
    );
  }

  // ===========================================================================
  // 2. ACTIVE MODULE: plain section, no card
  // ===========================================================================
  Widget _buildHeroPathwayCard({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required PathwayModel pathway,
  }) {
    // Strict 0% handling (AGENTS.md 2.3): no minimum sliver.
    final double progressValue = pathway.completion <= 0
        ? 0.0
        : (pathway.completion / 100.0).clamp(0.0, 1.0);

    final String ctaLabel = pathway.completion >= 100
        ? 'Review Track'
        : pathway.completion > 0
        ? 'Continue Learning'
        : 'Start Learning';

    final bool isDone = pathway.completion >= 100;
    final String topicLabel = isDone ? 'Completed' : 'Up next';
    final String topicTitle = isDone
        ? 'Every topic in this module is done'
        : (pathway.currentModule.isNotEmpty
              ? pathway.currentModule
              : 'Topic 1');

    final Color onPrimary = isDark ? AppColors.onPrimaryDark : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            LanguageAvatarStack(
              languages: pathway.stack.isNotEmpty
                  ? pathway.stack
                  : <String>[pathway.language],
              size: 24.0,
              overlap: 6.0,
              borderColor: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
            ),
            Text(
              '${pathway.completion}% Complete',
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
          pathway.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3,
            height: 1.25,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6.0),
        Text(
          pathway.description.isNotEmpty
              ? pathway.description
              : 'Continue practicing structured lessons and algorithmic problems.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.5,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(999.0),
          child: SizedBox(
            height: 4.0,
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceHighest
                  : AppColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Text(
          topicLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
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
        const SizedBox(height: 20.0),
        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/modules/${pathway.id}');
            },
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
                const Icon(Icons.play_arrow_rounded, size: 18.0),
                const SizedBox(width: 6.0),
                Text(
                  ctaLabel,
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
        const SizedBox(height: 4.0),
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/modules/${pathway.id}');
          },
          borderRadius: BorderRadius.circular(8.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'View all topics',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14.0,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. SKELETON LOADING STATE (matches the flat layout above)
  // ===========================================================================
  Widget _buildDashboardSkeleton({required bool isDark}) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Row(
              children: <Widget>[
                SkeletonBox(width: 40.0, height: 40.0, borderRadius: 20.0),
                SizedBox(width: 12.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBox(width: 80.0, height: 12.0, borderRadius: 4.0),
                    SizedBox(height: 6.0),
                    SkeletonBox(width: 120.0, height: 16.0, borderRadius: 4.0),
                  ],
                ),
              ],
            ),
            SizedBox(height: 32.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                SkeletonBox(width: 64.0, height: 24.0, borderRadius: 12.0),
                SkeletonBox(width: 90.0, height: 12.0, borderRadius: 4.0),
              ],
            ),
            SizedBox(height: 16.0),
            SkeletonBox(width: 240.0, height: 22.0, borderRadius: 4.0),
            SizedBox(height: 8.0),
            SkeletonBox(
              width: double.infinity,
              height: 12.0,
              borderRadius: 4.0,
            ),
            SizedBox(height: 6.0),
            SkeletonBox(width: 200.0, height: 12.0, borderRadius: 4.0),
            SizedBox(height: 20.0),
            SkeletonBox(
              width: double.infinity,
              height: 4.0,
              borderRadius: 999.0,
            ),
            SizedBox(height: 20.0),
            SkeletonBox(
              width: double.infinity,
              height: 48.0,
              borderRadius: 12.0,
            ),
            SizedBox(height: 32.0),
            SkeletonBox(width: 140.0, height: 15.0, borderRadius: 4.0),
            SizedBox(height: 16.0),
            SkeletonBox(
              width: double.infinity,
              height: 100.0,
              borderRadius: 8.0,
            ),
          ],
        ),
      ),
    );
  }
}
