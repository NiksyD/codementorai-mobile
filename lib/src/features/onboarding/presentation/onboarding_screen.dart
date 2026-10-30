import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/supabase_profile_repository.dart';
import '../../profile/domain/profile_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.profileRepository = const SupabaseProfileRepository(),
    this.authRepository = const SupabaseAuthRepository(),
  });

  final ProfileRepository profileRepository;
  final AuthRepository authRepository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;

  // Personal Identity & Profile Fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String? _stepError;
  String? _customAvatarUrl;
  bool _isUploadingAvatar = false;

  static const List<String> _avatarPool = <String>[
    'Felix',
    'Aneka',
    'Jack',
    'Luna',
    'Oliver',
    'Sarah',
    'George',
    'Elena',
    'Milo',
    'Zoe',
    'Hugo',
    'Maya',
    'Leo',
    'Ruby',
    'Ezra',
    'Nova',
    'Silas',
    'Clara',
  ];

  late List<String> _currentAvatarSeeds;
  late String _selectedAvatarSeed;

  @override
  void initState() {
    super.initState();
    _currentAvatarSeeds = _avatarPool.sublist(0, 8);
    _selectedAvatarSeed = _currentAvatarSeeds.first;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final String? fullName =
          (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['name'] as String?);
      if (fullName != null && fullName.isNotEmpty) {
        if (fullName.contains(',')) {
          final List<String> commaParts = fullName.split(',');
          _lastNameController.text = commaParts[0].trim();
          if (commaParts.length > 1) {
            _firstNameController.text = commaParts[1].trim();
          }
        } else {
          final List<String> parts = fullName.split(' ');
          _firstNameController.text = parts.first;
          if (parts.length > 1) {
            _lastNameController.text = parts.sublist(1).join(' ');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _shuffleAvatars() {
    HapticFeedback.lightImpact();
    final List<String> shuffled = List<String>.from(_avatarPool)..shuffle();
    setState(() {
      _currentAvatarSeeds = shuffled.sublist(0, 8);
      _selectedAvatarSeed = _currentAvatarSeeds.first;
      _customAvatarUrl = null;
    });
  }

  Future<void> _pickAndUploadPhoto() async {
    HapticFeedback.lightImpact();
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null || !mounted) return;

      setState(() {
        _isUploadingAvatar = true;
        _stepError = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User session not found. Please log in again.');
      }
      final Uint8List bytes = await File(image.path).readAsBytes();
      final String fileExt = image.path.split('.').last.toLowerCase();
      final String fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      if (!mounted) return;

      setState(() {
        _customAvatarUrl = publicUrl;
      });
      HapticFeedback.mediumImpact();
      AppToast.showSuccess(context, 'Avatar uploaded successfully!');
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      AppToast.showError(context, 'Failed to upload: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _handleFinishOnboarding() async {
    FocusScope.of(context).unfocus();
    final String first = _firstNameController.text.trim();
    final String last = _lastNameController.text.trim();

    if (first.isEmpty) {
      HapticFeedback.vibrate();
      setState(() {
        _stepError = 'First name is required.';
      });
      return;
    }

    if (last.isEmpty) {
      HapticFeedback.vibrate();
      setState(() {
        _stepError = 'Last name is required.';
      });
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppToast.showError(context, 'No active user session found');
      return;
    }

    setState(() {
      _isLoading = true;
      _stepError = null;
    });

    try {
      final String rawRole =
          (user.userMetadata?['role'] as String?) ?? 'learner';
      final String userRole = rawRole == 'student' ? 'learner' : rawRole;
      final ProfileModel profile = ProfileModel(
        userId: user.id,
        email: user.email ?? '',
        firstName: first,
        lastName: last,
        role: userRole,
        primaryLanguage: 'javascript',
        skillLevel: 'beginner',
        avatarUrl:
            _customAvatarUrl ??
            'https://api.dicebear.com/7.x/avataaars/png?seed=$_selectedAvatarSeed',
        phoneNumber: '',
        city: '',
        province: '',
        userOnboarded: true,
      );

      await widget.profileRepository.saveProfile(profile);

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      AppToast.showSuccess(
        context,
        'Welcome, ${profile.firstName}! Your workspace is ready.',
      );

      context.go('/dashboard');
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      AppToast.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Text(
            'Sign Out',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out and return to the login screen?',
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

    try {
      await widget.authRepository.signOut();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      AppToast.showSuccess(context, 'Signed out successfully');
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to sign out: $error');
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

    final String currentAvatarUrl =
        _customAvatarUrl ??
        'https://api.dicebear.com/7.x/avataaars/png?seed=$_selectedAvatarSeed';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              // Top Action Bar with Sign Out
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const SizedBox(width: 40.0),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleSignOut,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 15.0,
                        color: textSecondary,
                      ),
                      label: Text(
                        'Sign Out',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Welcome to CodeMentorAI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Personalize your developer identity to get started',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      color: textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28.0),

                  // Selected Avatar Large Preview (Interactive Tap to Upload)
                  Center(
                    child: Stack(
                      children: <Widget>[
                        InkWell(
                          onTap: _isUploadingAvatar ? null : _pickAndUploadPhoto,
                          borderRadius: BorderRadius.circular(48.0),
                          child: Container(
                            width: 96.0,
                            height: 96.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2.5,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 18.0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _isUploadingAvatar
                                  ? Container(
                                      color: isDark
                                          ? AppColors.darkSurface
                                          : AppColors.lightSurface,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 26.0,
                                          height: 26.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Image.network(
                                      currentAvatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.person_rounded,
                                                size: 44.0,
                                                color: AppColors.primary,
                                              ),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _isUploadingAvatar
                                ? null
                                : _pickAndUploadPhoto,
                            borderRadius: BorderRadius.circular(16.0),
                            child: Container(
                              padding: const EdgeInsets.all(7.0),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBackground
                                      : AppColors.lightBackground,
                                  width: 2.0,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 14.0,
                                color: isDark
                                    ? AppColors.onPrimaryDark
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18.0),

                  // Dual Action Controls (Shuffle + Upload Photo)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _isUploadingAvatar ? null : _shuffleAvatars,
                        icon: const Icon(Icons.shuffle_rounded, size: 16.0),
                        label: Text(
                          'Shuffle',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 10.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      ElevatedButton.icon(
                        onPressed: _isUploadingAvatar
                            ? null
                            : _pickAndUploadPhoto,
                        icon: const Icon(Icons.upload_file_rounded, size: 16.0),
                        label: Text(
                          _isUploadingAvatar ? 'Uploading…' : 'Upload Photo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          foregroundColor: textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 10.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // Avatar Seeds Grid (8 presets)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10.0,
                          crossAxisSpacing: 10.0,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: _currentAvatarSeeds.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String seed = _currentAvatarSeeds[index];
                      final bool isSelected =
                          _customAvatarUrl == null &&
                          _selectedAvatarSeed == seed;

                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedAvatarSeed = seed;
                            _customAvatarUrl = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(14.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(6.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: Image.network(
                              'https://api.dicebear.com/7.x/avataaars/png?seed=$seed',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.person_outline_rounded,
                                    color: textSecondary,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24.0),

                  // Error Banner if needed
                  if (_stepError != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _stepError!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                  ],

                  // First Name & Last Name (2 Column Row)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'First Name',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            TextFormField(
                              controller: _firstNameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                color: textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Jane',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Last Name',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            TextFormField(
                              controller: _lastNameController,
                              textInputAction: TextInputAction.done,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                color: textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Doe',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32.0),

                  // Complete Setup Button
                  SizedBox(
                    height: 50.0,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleFinishOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: isDark
                            ? AppColors.onPrimaryDark
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20.0,
                              width: 20.0,
                              child: CircularProgressIndicator(
                                color: isDark
                                    ? AppColors.onPrimaryDark
                                    : Colors.white,
                                strokeWidth: 2.2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Complete Setup',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.onPrimaryDark
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16.0,
                                  color: isDark
                                      ? AppColors.onPrimaryDark
                                      : Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Secondary Sign Out / Exit button
                  Center(
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _handleSignOut,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 15.0,
                        color: textSecondary,
                      ),
                      label: Text(
                        'Sign in with a different account',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
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
),
);
}
}
