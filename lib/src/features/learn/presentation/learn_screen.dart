import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../common_widgets/language_icon.dart';
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

    final String firstName = _profile?.firstName?.isNotEmpty == true
        ? _profile!.firstName!
        : (Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'Developer');

    final String avatarUrl = _profile?.avatarUrl?.isNotEmpty == true
        ? _profile!.avatarUrl!
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=$firstName';

    final PathwayModel? activePathway = _dashboardData?.activePathway;
    final List<PathwayModel> enrolledPathways = _dashboardData?.enrolledPathways ?? const <PathwayModel>[];
    final List<LearnChallengeModel> challenges = _dashboardData?.recommendedChallenges ?? const <LearnChallengeModel>[];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          child: _isLoading && _dashboardData == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 1. TOP GREETING & STREAK BAR
                      _buildTopGreeting(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        firstName: firstName,
                        avatarUrl: avatarUrl,
                        streak: _dashboardData?.currentStreak ?? 3,
                      ),
                      const SizedBox(height: 20.0),

                      // 2. HERO ACTIVE PATHWAY CARD (LIVE DATA)
                      if (activePathway != null) ...<Widget>[
                        _buildHeroPathwayCard(
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          pathway: activePathway,
                        ),
                        const SizedBox(height: 20.0),
                      ],

                      // 3. 12-WEEK ACTIVITY HEATMAP
                      ActivityHeatmap(
                        totalActiveDays: _dashboardData?.totalActiveDays ?? 28,
                        currentStreak: _dashboardData?.currentStreak ?? 3,
                      ),
                      const SizedBox(height: 20.0),

                      // 4. PROBLEM SOLVING METRICS
                      _buildProblemSolvingStats(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        easy: _dashboardData?.easySolved ?? 18,
                        medium: _dashboardData?.mediumSolved ?? 9,
                        hard: _dashboardData?.hardSolved ?? 2,
                      ),
                      const SizedBox(height: 24.0),

                      // 5. ENROLLED & RECOMMENDED PATHWAYS (LIVE DATA)
                      if (enrolledPathways.isNotEmpty) ...<Widget>[
                        _buildPathwaysSection(
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          pathways: enrolledPathways,
                        ),
                        const SizedBox(height: 24.0),
                      ],

                      // 6. RECOMMENDED NEXT CHALLENGES
                      _buildRecommendedChallenges(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        challenges: challenges,
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
  // 1. TOP GREETING & STATUS
  // ===========================================================================
  Widget _buildTopGreeting({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required String firstName,
    required String avatarUrl,
    required int streak,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // Avatar + Greeting
        Row(
          children: <Widget>[
            Container(
              width: 46.0,
              height: 46.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.0),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 10.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Welcome back,',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                Text(
                  firstName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Notifications & Level Pill
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16.0,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    '$streak Day Streak',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            _buildNotificationBell(isDark, textPrimary, textSecondary),
          ],
        ),
      ],
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
      borderRadius: BorderRadius.circular(14.0),
      child: Container(
        width: 38.0,
        height: 38.0,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: unreadCount > 0
                ? AppColors.primary.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              unreadCount > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 20.0,
              color: unreadCount > 0 ? textPrimary : textSecondary,
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8.0,
                right: 8.0,
                child: Container(
                  width: 8.0,
                  height: 8.0,
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
  // 2. HERO ACTIVE PATHWAY CARD
  // ===========================================================================
  Widget _buildHeroPathwayCard({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required PathwayModel pathway,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  const Color(0xFF1E2638),
                  AppColors.darkSurfaceCard,
                ]
              : <Color>[
                  Colors.white,
                  AppColors.lightSurfaceCard,
                ],
        ),
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 18.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Stack & Completion %
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              LanguageAvatarStack(
                languages: pathway.stack.isNotEmpty
                    ? pathway.stack
                    : <String>[pathway.language],
                size: 28.0,
              ),
              Text(
                '${pathway.completion}% Complete',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Title & Current Module
          Text(
            pathway.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            pathway.currentModule,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14.0),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: LinearProgressIndicator(
              value: (pathway.completion / 100.0).clamp(0.0, 1.0),
              minHeight: 6.0,
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16.0),

          // Action Button: Continue Learning
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
                foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
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
                    pathway.completion > 0 ? 'Continue Learning' : 'Start Learning',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.onPrimaryDark : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. PROBLEM SOLVING METRICS
  // ===========================================================================
  Widget _buildProblemSolvingStats({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required int easy,
    required int medium,
    required int hard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Problem Solving Stats',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10.0),
        Row(
          children: <Widget>[
            Expanded(
              child: _buildDifficultyStatCard(
                label: 'Easy',
                count: '$easy',
                total: '/ 40',
                color: const Color(0xFF3ECF8E),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: _buildDifficultyStatCard(
                label: 'Medium',
                count: '$medium',
                total: '/ 35',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: _buildDifficultyStatCard(
                label: 'Hard',
                count: '$hard',
                total: '/ 15',
                color: const Color(0xFFEF4444),
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDifficultyStatCard({
    required String label,
    required String count,
    required String total,
    required Color color,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 7.0,
                height: 7.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                count,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 4.0),
              Text(
                total,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. ENROLLED & RECOMMENDED PATHWAYS
  // ===========================================================================
  Widget _buildPathwaysSection({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required List<PathwayModel> pathways,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Enrolled Modules',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            Text(
              '${pathways.length} activities total',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.0,
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        SizedBox(
          height: 140.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: pathways.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12.0),
            itemBuilder: (BuildContext context, int index) {
              final PathwayModel p = pathways[index];
              return Container(
                width: 240.0,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/modules/${p.id}');
                  },
                  borderRadius: BorderRadius.circular(18.0),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            LanguageAvatarStack(
                              languages: p.stack.isNotEmpty
                                  ? p.stack
                                  : <String>[p.language],
                              size: 22.0,
                            ),
                            Text(
                              '${p.completion}%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: p.completion > 0
                                    ? AppColors.primary
                                    : textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          p.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: LinearProgressIndicator(
                            value: (p.completion / 100.0).clamp(0.0, 1.0),
                            minHeight: 4.0,
                            backgroundColor: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        Text(
                          '${p.totalModules} Topics',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. RECOMMENDED NEXT CHALLENGES
  // ===========================================================================
  Widget _buildRecommendedChallenges({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required List<LearnChallengeModel> challenges,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Recommended Challenges',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12.0),
        Column(
          children: challenges.map((LearnChallengeModel ch) {
            final Color diffColor = _getDifficultyColor(ch.difficulty);

            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: <Widget>[
                  LanguageIcon(language: ch.language, size: 20.0),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          ch.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: diffColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Text(
                                ch.difficulty,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: diffColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              ch.category,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.0,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: textSecondary,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
