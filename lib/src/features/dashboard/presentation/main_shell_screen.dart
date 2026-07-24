import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_navbar.dart';

import '../../../constants/app_colors.dart';
import '../../../theme/theme_mode_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/supabase_profile_repository.dart';
import '../../profile/domain/profile_model.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
    this.profileRepository = const SupabaseProfileRepository(),
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  ProfileModel? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final ProfileModel? profile = await widget.profileRepository.getProfile(
        user.id,
      );
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await widget.authRepository.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'CodeMentor AI',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            'Nav ${_currentIndex + 1} Selected',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Row(
                    children: <Widget>[
                      // Theme Toggle Switch
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceCard
                              : AppColors.lightSurfaceCard,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          padding: const EdgeInsets.all(6.0),
                          constraints: const BoxConstraints(),
                          onPressed: () => themeModeController.toggleTheme(),
                          icon: Icon(
                            isDark
                                ? Icons.wb_sunny_rounded
                                : Icons.dark_mode_rounded,
                            size: 18.0,
                            color: isDark
                                ? const Color(0xFFFBBF24)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      // Sign Out Button
                      IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        color: AppColors.error,
                        tooltip: 'Sign Out',
                        onPressed: _handleSignOut,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Active View Container
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: <Widget>[
                  _buildNav1View(context, isDark),
                  _buildNav2View(context, isDark),
                  _buildNav3View(context, isDark),
                  _buildNav4View(context, isDark),
                  _buildNav5View(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppNavbar(
        selectedIndex: _currentIndex,
        onItemSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  // NAV 1: Main Dashboard View
  Widget _buildNav1View(BuildContext context, bool isDark) {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final String displayName = _profile != null
        ? _profile!.fullName
        : 'Developer';
    final String language = _profile?.primaryLanguage ?? 'Python';
    final String level = _profile?.skillLevel ?? 'Intermediate';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Welcome Profile Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.darkCardGradient
                  : AppColors.lightCardGradient,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Welcome back, $displayName! 👋',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              language,
                              style: const TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              level,
                              style: const TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),

          // Nav 1 Status Hero Card
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceCard
                  : AppColors.lightSurfaceCard,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.grid_view_rounded,
                  size: 48.0,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Nav 1 Active Screen',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Your main dashboard overview and AI mentorship workspace.',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NAV 2 View Placeholder
  Widget _buildNav2View(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.code_rounded,
              size: 64.0,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16.0),
            Text(
              'Nav 2 Screen',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Code Sandbox & Interactive Challenges View',
              style: TextStyle(
                fontSize: 14.0,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NAV 3 View Placeholder
  Widget _buildNav3View(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.auto_awesome_rounded,
              size: 64.0,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16.0),
            Text(
              'Nav 3 Screen',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Real-Time AI Pair Programming & Chat View',
              style: TextStyle(
                fontSize: 14.0,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NAV 4 View Placeholder
  Widget _buildNav4View(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.analytics_rounded,
              size: 64.0,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16.0),
            Text(
              'Nav 4 Screen',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Skill Radar & Progress Analytics View',
              style: TextStyle(
                fontSize: 14.0,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NAV 5 View Placeholder
  Widget _buildNav5View(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.person_rounded,
              size: 64.0,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16.0),
            Text(
              'Nav 5 Screen',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'User Profile & Settings Management View',
              style: TextStyle(
                fontSize: 14.0,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
