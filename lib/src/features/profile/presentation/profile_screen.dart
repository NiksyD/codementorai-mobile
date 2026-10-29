import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../constants/app_colors.dart';
import '../../../theme/theme_mode_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../data/profile_repository.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
    this.profileRepository = const SupabaseProfileRepository(),
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;

  String _firstName = '';
  String _lastName = '';

  User? _getAuthUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = _getAuthUser();
    if (user != null) {
      final ProfileModel? profile = await widget.profileRepository.getProfile(user.id);
      final metadata = user.userMetadata ?? <String, dynamic>{};

      if (mounted) {
        setState(() {
          _profile = profile;
          _firstName = profile?.firstName ?? (metadata['first_name'] as String?) ?? '';
          _lastName = profile?.lastName ?? (metadata['last_name'] as String?) ?? '';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAvatarUpload() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image == null) return;

    final user = _getAuthUser();
    if (user == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final String fileExt = image.name.split('.').last.toLowerCase();
      final String filePath = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, bytes);

      final String publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      final ProfileModel updatedProfile = ProfileModel(
        userId: user.id,
        email: user.email ?? _profile?.email ?? '',
        firstName: _firstName,
        lastName: _lastName,
        role: _profile?.role ?? (user.userMetadata?['role'] as String?) ?? 'student',
        avatarUrl: publicUrl,
        primaryLanguage: _profile?.primaryLanguage,
        skillLevel: _profile?.skillLevel,
      );

      await widget.profileRepository.saveProfile(updatedProfile);

      if (mounted) {
        setState(() {
          _profile = updatedProfile;
          _isUploadingAvatar = false;
        });
        AppToast.showSuccess(context, 'Avatar updated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        AppToast.showError(context, 'Failed to upload avatar: $e');
      }
    }
  }

  void _showEditNameSheet() {
    HapticFeedback.selectionClick();
    final TextEditingController firstCtrl = TextEditingController(text: _firstName);
    final TextEditingController lastCtrl = TextEditingController(text: _lastName);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
              ),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Edit Name',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 14.0),
                  TextField(
                    controller: firstCtrl,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    controller: lastCtrl,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                  const SizedBox(height: 18.0),
                  SizedBox(
                    width: double.infinity,
                    height: 46.0,
                    child: ElevatedButton(
                      onPressed: () async {
                        final String newFirst = firstCtrl.text.trim();
                        final String newLast = lastCtrl.text.trim();
                        if (newFirst.isEmpty) return;

                        Navigator.pop(ctx);
                        final user = _getAuthUser();
                        if (user != null) {
                          final ProfileModel updated = ProfileModel(
                            userId: user.id,
                            email: _profile?.email ?? user.email ?? '',
                            firstName: newFirst,
                            lastName: newLast,
                            role: _profile?.role ?? (user.userMetadata?['role'] as String?) ?? 'student',
                            avatarUrl: _profile?.avatarUrl,
                            primaryLanguage: _profile?.primaryLanguage,
                            skillLevel: _profile?.skillLevel,
                          );
                          await widget.profileRepository.saveProfile(updated);
                          if (mounted) {
                            setState(() {
                              _firstName = newFirst;
                              _lastName = newLast;
                              _profile = updated;
                            });
                            AppToast.showSuccess(context, 'Name updated successfully');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) {
        return const _ChangePasswordModal();
      },
    );
  }

  void _showLegalDialog(String title, String content) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.plusJakartaSans(fontSize: 13.0, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: Text(
            'Sign Out',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out of CodeMentor AI?',
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: Text(
                'Sign Out',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await widget.authRepository.signOut();
    if (!mounted) return;
    AppToast.showSuccess(context, 'Signed out successfully');
    context.go('/login');
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
    final Color sectionHeaderColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final User? authUser = _getAuthUser();
    final Map<String, dynamic> authMeta = authUser?.userMetadata ?? <String, dynamic>{};
    final String displayName = _profile?.fullName.isNotEmpty == true
        ? _profile!.fullName
        : ((authMeta['full_name'] as String?) ??
            authUser?.email?.split('@').first ??
            'Developer');
    final String email = _profile?.email.isNotEmpty == true
        ? _profile!.email
        : (authUser?.email ?? '');
    final String? resolvedAvatar = (_profile?.avatarUrl?.isNotEmpty == true)
        ? _profile!.avatarUrl
        : ((authMeta['avatar_url'] as String?) ?? (authMeta['picture'] as String?));
    final String avatarUrl = (resolvedAvatar != null && resolvedAvatar.trim().isNotEmpty)
        ? resolvedAvatar.trim()
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=$displayName';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 1. TOP TITLE & CAPTION
                    Text(
                      'Profile & Settings',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22.0,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      'Manage your personal details, preferences, and account security.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // 2. USER PROFILE HERO CARD
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: borderColor),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 12.0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          // Avatar with camera micro-badge
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _handleAvatarUpload();
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Container(
                                  width: 64.0,
                                  height: 64.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      width: 2.0,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _isUploadingAvatar
                                        ? const Center(
                                            child: SizedBox(
                                              width: 22.0,
                                              height: 22.0,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          )
                                        : Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(
                                              Icons.person_rounded,
                                              size: 34.0,
                                              color: textSecondary,
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -2.0,
                                  right: -2.0,
                                  child: Container(
                                    width: 22.0,
                                    height: 22.0,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF262626) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                        width: 1.5,
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 4.0,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        size: 11.0,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16.0),

                          // Name + Email
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3.0),
                                Text(
                                  email,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w400,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),

                          // Quick Edit Name Pencil Button
                          IconButton(
                            onPressed: _showEditNameSheet,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18.0,
                              color: textSecondary,
                            ),
                            tooltip: 'Edit Name',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22.0),

                    // 3. ACCOUNT DETAILS (1:1 Web /settings/account)
                    _buildSectionHeader('ACCOUNT DETAILS', sectionHeaderColor),
                    const SizedBox(height: 8.0),
                    Material(
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                        side: BorderSide(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          _buildSettingRow(
                            icon: Icons.person_outline_rounded,
                            title: 'Display Name',
                            subtitle: displayName,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 20.0,
                              color: textSecondary,
                            ),
                            onTap: _showEditNameSheet,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDark: isDark,
                          ),
                          Divider(
                            height: 1.0,
                            thickness: 1.0,
                            indent: 66.0,
                            endIndent: 16.0,
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.6)
                                : const Color(0xFFF1F5F9),
                          ),
                          _buildSettingRow(
                            icon: Icons.alternate_email_rounded,
                            title: 'Email Address',
                            subtitle: email,
                            trailing: Icon(
                              Icons.lock_outline_rounded,
                              size: 16.0,
                              color: textSecondary.withValues(alpha: 0.7),
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              AppToast.showInfo(
                                context,
                                'Email address is linked to your account and cannot be modified.',
                              );
                            },
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22.0),

                    // 4. PREFERENCES (1:1 Web /settings/notifications + Appearance)
                    _buildSectionHeader('PREFERENCES', sectionHeaderColor),
                    const SizedBox(height: 8.0),
                    Material(
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                        side: BorderSide(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildSettingRow(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle: isDark ? 'Dark Theme' : 'Light Theme',
                        trailing: Switch.adaptive(
                          value: isDark,
                          activeTrackColor: AppColors.primary,
                          onChanged: (bool val) {
                            HapticFeedback.selectionClick();
                            themeModeController.toggleTheme();
                          },
                        ),
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 22.0),

                    // 5. SECURITY & LEGAL (1:1 Web /settings/security)
                    _buildSectionHeader('SECURITY & LEGAL', sectionHeaderColor),
                    const SizedBox(height: 8.0),
                    Material(
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                        side: BorderSide(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          _buildSettingRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Change Password',
                            subtitle: 'Update account credentials',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 20.0,
                              color: textSecondary,
                            ),
                            onTap: _showChangePasswordSheet,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDark: isDark,
                          ),
                          Divider(
                            height: 1.0,
                            thickness: 1.0,
                            indent: 66.0,
                            endIndent: 16.0,
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.6)
                                : const Color(0xFFF1F5F9),
                          ),
                          _buildSettingRow(
                            icon: Icons.description_outlined,
                            title: 'Privacy Policy & Terms',
                            subtitle: 'Terms of service & privacy notice',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 20.0,
                              color: textSecondary,
                            ),
                            onTap: () => _showLegalDialog(
                              'Privacy & Terms',
                              'CodeMentor AI respects your data privacy. Code submissions and practice progress are securely stored in your personal account.',
                            ),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // 6. SIGN OUT BUTTON (Modern Destructive Card)
                    InkWell(
                      borderRadius: BorderRadius.circular(16.0),
                      onTap: _handleSignOut,
                      child: Container(
                        height: 48.0,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: AppColors.error
                                .withValues(alpha: isDark ? 0.30 : 0.20),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.logout_rounded,
                              size: 18.0,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              'Sign Out',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // 7. APP VERSION BADGE
                    Center(
                      child: Text(
                        'CodeMentor AI v1.0.0 (Build 42)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          color: textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 96.0),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
          child: Row(
            children: <Widget>[
              // Monochromatic slate squircle leading icon container
              Container(
                width: 36.0,
                height: 36.0,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18.0,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 14.0),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2.0),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8.0),

              // Trailing widget
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: color,
        ),
      ),
    );
  }
}

class _ChangePasswordModal extends StatefulWidget {
  const _ChangePasswordModal();

  @override
  State<_ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<_ChangePasswordModal> {
  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isUpdating = false;

  String _newPassword = '';

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(() {
      setState(() {
        _newPassword = _newPassCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // Password Security Criteria (100% Parity with Register & Web Security)
  bool get _hasMinLength => _newPassword.length >= 8;
  bool get _hasUpperAndLower =>
      RegExp(r'[A-Z]').hasMatch(_newPassword) && RegExp(r'[a-z]').hasMatch(_newPassword);
  bool get _hasNumberOrSymbol =>
      RegExp(r'[0-9]|[^A-Za-z0-9]').hasMatch(_newPassword);

  int get _strengthScore {
    if (_newPassword.isEmpty) return 0;
    int score = 0;
    if (_newPassword.length >= 8) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(_newPassword) && RegExp(r'[a-z]').hasMatch(_newPassword)) {
      score += 1;
    }
    if (RegExp(r'[0-9]').hasMatch(_newPassword)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(_newPassword) || _newPassword.length >= 12) {
      score += 1;
    }
    return score;
  }

  static const List<Color> _strengthColors = <Color>[
    Color(0x3394A3B8),
    Color(0xFFEF4444), // Weak (Red)
    Color(0xFFF59E0B), // Fair (Amber)
    Color(0xFF38BDF8), // Good (Sky)
    Color(0xFF3ECF8E), // Strong (Mint / Emerald)
  ];

  static const List<String> _strengthLabels = <String>[
    'Empty',
    'Weak',
    'Fair',
    'Good',
    'Strong',
  ];

  Future<void> _handleUpdatePassword() async {
    final String currentPass = _currentPassCtrl.text;
    final String newPass = _newPassCtrl.text;
    final String conf = _confirmPassCtrl.text;

    if (currentPass.isEmpty) {
      HapticFeedback.vibrate();
      AppToast.showError(context, 'Please enter your current password');
      return;
    }

    if (!_hasMinLength || !_hasUpperAndLower || !_hasNumberOrSymbol) {
      HapticFeedback.vibrate();
      AppToast.showError(context, 'Please meet all password security requirements');
      return;
    }

    if (newPass != conf) {
      HapticFeedback.vibrate();
      AppToast.showError(context, 'New passwords do not match');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email != null) {
      try {
        // 1. Verify current password
        await Supabase.instance.client.auth.signInWithPassword(
          email: user!.email!,
          password: currentPass,
        );

        // 2. Update to new password
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPass),
        );

        if (!mounted) return;
        Navigator.pop(context);
        HapticFeedback.mediumImpact();
        AppToast.showSuccess(context, 'Password updated successfully');
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isUpdating = false;
        });
        HapticFeedback.heavyImpact();
        final String rawMsg = e.toString().replaceAll('AuthException: ', '').replaceAll('Exception: ', '');
        AppToast.showError(context, rawMsg.contains('Invalid login') ? 'Incorrect current password' : rawMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color surfaceColor = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final int score = _strengthScore;
    final Color activeStrengthColor = _strengthColors[score];
    final String activeStrengthLabel = _strengthLabels[score];

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Change Password',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 14.0),

                // Current Password
                TextField(
                  controller: _currentPassCtrl,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: textSecondary,
                        size: 20.0,
                      ),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),

                // New Password
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: textSecondary,
                        size: 20.0,
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),

                // 4-Segment Strength Meter
                if (_newPassword.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8.0),
                  Row(
                    children: <Widget>[
                      ...List.generate(4, (int index) {
                        final bool isFilled = index < score;
                        return Expanded(
                          child: Container(
                            height: 4.0,
                            margin: EdgeInsets.only(right: index < 3 ? 4.0 : 0.0),
                            decoration: BoxDecoration(
                              color: isFilled ? activeStrengthColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 8.0),
                      Text(
                        activeStrengthLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: activeStrengthColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),

                  // Requirements Checklist
                  _buildRequirementItem('At least 8 characters', _hasMinLength, textSecondary),
                  _buildRequirementItem('Upper & lowercase letters', _hasUpperAndLower, textSecondary),
                  _buildRequirementItem('Number or symbol', _hasNumberOrSymbol, textSecondary),
                ],

                const SizedBox(height: 12.0),

                // Confirm Password
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: textSecondary,
                        size: 20.0,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),

                // Submit CTA
                SizedBox(
                  width: double.infinity,
                  height: 46.0,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _handleUpdatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20.0,
                            height: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Update Password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
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

  Widget _buildRequirementItem(String label, bool isMet, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: <Widget>[
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 13.0,
            color: isMet ? const Color(0xFF3ECF8E) : textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.0,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w500,
              color: isMet ? const Color(0xFF3ECF8E) : textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
