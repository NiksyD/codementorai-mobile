import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/language_icon.dart';
import '../../../constants/app_colors.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/supabase_profile_repository.dart';
import '../../profile/domain/profile_model.dart';

class TargetLanguageOption {
  const TargetLanguageOption({
    required this.id,
    required this.label,
    required this.desc,
  });

  final String id;
  final String label;
  final String desc;
}

class SkillLevelOption {
  const SkillLevelOption({
    required this.id,
    required this.label,
    required this.desc,
  });

  final String id;
  final String label;
  final String desc;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.profileRepository = const SupabaseProfileRepository(),
  });

  final ProfileRepository profileRepository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 1; // 1: Identity, 2: Pathway
  bool _isLoading = false;

  // Step 1: Identity
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String? _step1Error;
  String? _customAvatarUrl;
  bool _isUploadingAvatar = false;

  static const List<String> _avatarPool = <String>[
    'Felix', 'Aneka', 'Jack', 'Luna', 'Oliver', 'Sarah', 'George', 'Elena',
    'Milo', 'Zoe', 'Hugo', 'Maya', 'Leo', 'Ruby', 'Ezra', 'Nova', 'Silas', 'Clara',
  ];

  late List<String> _currentAvatarSeeds;
  late String _selectedAvatarSeed;

  // Step 2: Pathway (Learner-only)
  String _selectedLanguage = 'python';
  String _selectedSkillLevel = 'intermediate';

  static const List<TargetLanguageOption> _languages = <TargetLanguageOption>[
    TargetLanguageOption(id: 'python', label: 'Python', desc: 'Scripting & Data'),
    TargetLanguageOption(id: 'javascript', label: 'JavaScript', desc: 'Web Development'),
    TargetLanguageOption(id: 'typescript', label: 'TypeScript', desc: 'Typed Web Apps'),
    TargetLanguageOption(id: 'java', label: 'Java', desc: 'Object-Oriented'),
    TargetLanguageOption(id: 'cpp', label: 'C++', desc: 'High Performance'),
    TargetLanguageOption(id: 'csharp', label: 'C#', desc: 'Enterprise & Games'),
    TargetLanguageOption(id: 'c', label: 'C', desc: 'Low-level Systems'),
  ];

  static const List<SkillLevelOption> _skillLevels = <SkillLevelOption>[
    SkillLevelOption(id: 'beginner', label: 'Beginner', desc: '0–1 years experience'),
    SkillLevelOption(id: 'intermediate', label: 'Intermediate', desc: '1–3 years experience'),
    SkillLevelOption(id: 'advanced', label: 'Advanced', desc: '3+ years experience'),
  ];

  @override
  void initState() {
    super.initState();
    _currentAvatarSeeds = _avatarPool.sublist(0, 8);
    _selectedAvatarSeed = _currentAvatarSeeds.first;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final String? fullName = (user.userMetadata?['full_name'] as String?) ??
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
        _step1Error = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User session not found. Please log in again.');
      }
      final Uint8List bytes = await File(image.path).readAsBytes();
      final String fileExt = image.path.split('.').last.toLowerCase();
      final String fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));

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

  void _handleContinueStep1() {
    FocusScope.of(context).unfocus();
    final String first = _firstNameController.text.trim();
    final String last = _lastNameController.text.trim();

    if (first.isEmpty) {
      HapticFeedback.vibrate();
      setState(() {
        _step1Error = 'First name is required.';
      });
      return;
    }

    if (last.isEmpty) {
      HapticFeedback.vibrate();
      setState(() {
        _step1Error = 'Last name is required.';
      });
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _step1Error = null;
      _currentStep = 2;
    });
  }

  Future<void> _handleSaveLearnerProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppToast.showError(context, 'No active user session found');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String rawRole = (user.userMetadata?['role'] as String?) ?? 'learner';
      final String userRole = rawRole == 'student' ? 'learner' : rawRole;
      final ProfileModel profile = ProfileModel(
        userId: user.id,
        email: user.email ?? '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        role: userRole,
        primaryLanguage: _selectedLanguage,
        skillLevel: _selectedSkillLevel,
        avatarUrl: _customAvatarUrl ??
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              // Top Progress Stepper (1: Identity -> 2: Pathway)
              _buildTopStepper(isDark, textPrimary, textSecondary),

              // Step Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: _buildCurrentStep(isDark, textPrimary, textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopStepper(bool isDark, Color textPrimary, Color textSecondary) {
    const int totalSteps = 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Back Button if Step > 1
          if (_currentStep > 1)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20.0),
              color: textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentStep--;
                });
              },
            )
          else
            const SizedBox(width: 24.0),

          // Stepper Indicator Pills
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(totalSteps, (int index) {
              final int stepNum = index + 1;
              final bool isActive = _currentStep == stepNum;
              final bool isPassed = _currentStep > stepNum;

              return Row(
                children: <Widget>[
                  Container(
                    width: 28.0,
                    height: 28.0,
                    decoration: BoxDecoration(
                      color: isPassed
                          ? AppColors.primary
                          : (isActive
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : (isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive || isPassed
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isPassed
                          ? Icon(
                              Icons.check_rounded,
                              size: 14.0,
                              color: isDark
                                  ? AppColors.onPrimaryDark
                                  : AppColors.onPrimaryLight,
                            )
                          : Text(
                              '$stepNum',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? AppColors.primary
                                    : textSecondary,
                              ),
                            ),
                    ),
                  ),
                  if (index < totalSteps - 1)
                    Container(
                      width: 28.0,
                      height: 2.0,
                      margin: const EdgeInsets.symmetric(horizontal: 6.0),
                      color: isPassed
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                    ),
                ],
              );
            }),
          ),

          // Right Spacer
          const SizedBox(width: 24.0),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(bool isDark, Color textPrimary, Color textSecondary) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Identity(isDark, textPrimary, textSecondary);
      case 2:
        return _buildStep2Pathway(isDark, textPrimary, textSecondary);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // STEP 1: PERSONAL IDENTITY & AVATAR
  // ==========================================
  Widget _buildStep1Identity(bool isDark, Color textPrimary, Color textSecondary) {
    final String currentAvatarUrl = _customAvatarUrl ??
        'https://api.dicebear.com/7.x/avataaars/png?seed=$_selectedAvatarSeed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8.0),
        Text(
          'Choose Your Avatar & Name',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22.0,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6.0),
        Text(
          'Personalize your developer identity across the platform',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24.0),

        // Selected Avatar Large Preview (Interactive Tap to Upload)
        Center(
          child: Stack(
            children: <Widget>[
              InkWell(
                onTap: _isUploadingAvatar ? null : _pickAndUploadPhoto,
                borderRadius: BorderRadius.circular(44.0),
                child: Container(
                  width: 84.0,
                  height: 84.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 16.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _isUploadingAvatar
                        ? Container(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            child: const Center(
                              child: SizedBox(
                                width: 24.0,
                                height: 24.0,
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
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person_rounded,
                              size: 40.0,
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
                  onTap: _isUploadingAvatar ? null : _pickAndUploadPhoto,
                  borderRadius: BorderRadius.circular(14.0),
                  child: Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        width: 2.0,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 13.0,
                      color: isDark ? AppColors.onPrimaryDark : Colors.white,
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
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            ElevatedButton.icon(
              onPressed: _isUploadingAvatar ? null : _pickAndUploadPhoto,
              icon: const Icon(Icons.upload_file_rounded, size: 16.0),
              label: Text(
                _isUploadingAvatar ? 'Uploading…' : 'Upload Photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                foregroundColor: textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18.0),

        // Avatar Seeds Grid (8 items matching web)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            childAspectRatio: 1.0,
          ),
          itemCount: _currentAvatarSeeds.length,
          itemBuilder: (BuildContext context, int index) {
            final String seed = _currentAvatarSeeds[index];
            final bool isSelected = _customAvatarUrl == null && _selectedAvatarSeed == seed;

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
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(6.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.network(
                    'https://api.dicebear.com/7.x/avataaars/png?seed=$seed',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_outline_rounded,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20.0),

        // Error Banner if needed
        if (_step1Error != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              _step1Error!,
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
                    decoration: const InputDecoration(hintText: 'Jane'),
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
                    decoration: const InputDecoration(hintText: 'Doe'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28.0),

        // Continue Button
        SizedBox(
          height: 48.0,
          child: ElevatedButton(
            onPressed: _handleContinueStep1,
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
                Text(
                  'Continue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.onPrimaryDark : Colors.white,
                  ),
                ),
                const SizedBox(width: 6.0),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16.0,
                  color: isDark ? AppColors.onPrimaryDark : Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: LEARNING PATHWAY (Learner-only)
  // ==========================================
  Widget _buildStep2Pathway(bool isDark, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8.0),
        Text(
          'Choose Your Pathway',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22.0,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6.0),
        Text(
          'Select your primary language and experience level to tailor your practice',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24.0),

        // Primary Language Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Primary Language',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            Text(
              '(Changeable anytime)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.0,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),

        // Languages Grid with Devicon SVG Icons
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            childAspectRatio: 2.2,
          ),
          itemCount: _languages.length,
          itemBuilder: (BuildContext context, int index) {
            final TargetLanguageOption lang = _languages[index];
            final bool isSelected = _selectedLanguage == lang.id;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedLanguage = lang.id;
                });
              },
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    LanguageIcon(
                      language: lang.id,
                      size: 22.0,
                      showContainer: false,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            lang.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primary : textPrimary,
                            ),
                          ),
                          Text(
                            lang.desc,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.0,
                              color: textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20.0),

        // Current Skill Level Header
        Text(
          'Current Skill Level',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10.0),

        Column(
          children: _skillLevels.map((SkillLevelOption level) {
            final bool isSelected = _selectedSkillLevel == level.id;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedSkillLevel = level.id;
                });
              },
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 18.0,
                      height: 18.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : textSecondary,
                          width: 1.5,
                        ),
                        color: isSelected ? AppColors.primary : Colors.transparent,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 12.0,
                              color: isDark ? AppColors.onPrimaryDark : Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            level.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primary : textPrimary,
                            ),
                          ),
                          Text(
                            level.desc,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24.0),

        // Primary CTA (Start Practicing)
        SizedBox(
          height: 48.0,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSaveLearnerProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
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
                      color: isDark ? AppColors.onPrimaryDark : Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Start Practicing',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.onPrimaryDark : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16.0,
                        color: isDark ? AppColors.onPrimaryDark : Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
