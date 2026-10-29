import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common_widgets/animated_blob_background.dart';
import '../../../common_widgets/app_toast.dart';
import '../../../constants/app_colors.dart';
import '../data/profile_repository.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/profile_model.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.profileRepository = const SupabaseProfileRepository(),
  });

  final ProfileRepository profileRepository;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;

  String _selectedRole = 'Student';
  String _selectedLanguage = 'Python';
  String _selectedSkillLevel = 'Intermediate';

  static const List<String> _roles = <String>[
    'Student',
    'Junior Developer',
    'Mid/Senior Engineer',
    'Hobbyist',
    'Educator',
  ];

  static const List<String> _languages = <String>[
    'Python',
    'JavaScript',
    'PHP',
    'Dart / Flutter',
    'C++',
    'Java',
    'Go',
    'Rust',
    'C#',
  ];

  static const List<Map<String, String>> _skillLevels = <Map<String, String>>[
    <String, String>{
      'title': 'Beginner',
      'desc': 'Just starting out or learning programming fundamentals.',
      'icon': '🌱',
    },
    <String, String>{
      'title': 'Intermediate',
      'desc': 'Comfortable building projects and solving coding problems.',
      'icon': '⚡',
    },
    <String, String>{
      'title': 'Advanced',
      'desc': 'Experienced in software engineering, architecture, and design.',
      'icon': '🚀',
    },
    <String, String>{
      'title': 'Master',
      'desc': 'Deep technical expertise across complex algorithms and systems.',
      'icon': '👑',
    },
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppToast.showError(context, 'No active user session found');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ProfileModel profile = ProfileModel(
        userId: user.id,
        email: user.email ?? '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        role: _selectedRole,
        primaryLanguage: _selectedLanguage,
        skillLevel: _selectedSkillLevel,
        avatarUrl: user.userMetadata?['avatar_url'] as String? ?? '',
        phoneNumber: '',
        city: '',
        province: '',
      );

      await widget.profileRepository.saveProfile(profile);

      if (!mounted) return;

      AppToast.showSuccess(
        context,
        'Welcome, ${profile.firstName}! Your developer profile is set.',
      );

      context.go('/dashboard');
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(context, error);
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

    return AnimatedBlobBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Step Indicator Header
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentStep >= 1
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // Brand Icon Badge Header
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  Text(
                    _currentStep == 0
                        ? 'Personal Details'
                        : 'Developer Preferences',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 24.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    _currentStep == 0
                        ? 'Tell us a bit about yourself to personalize your mentorship.'
                        : 'Select your core language and current experience level.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28.0),

                  // STEP 0: Personal Info
                  if (_currentStep == 0) ...<Widget>[
                    TextFormField(
                      controller: _firstNameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        hintText: 'Enter your first name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    TextFormField(
                      controller: _lastNameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'Enter your last name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20.0),

                    Text(
                      'Your Primary Role / Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _roles.map((String role) {
                        final bool isSelected = _selectedRole == role;
                        return ChoiceChip(
                          label: Text(role),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceCard
                              : AppColors.lightSurfaceCard,
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() {
                                _selectedRole = role;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  // STEP 1: Developer Preferences
                  if (_currentStep == 1) ...<Widget>[
                    Text(
                      'Primary Programming Language',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _languages.map((String lang) {
                        final bool isSelected = _selectedLanguage == lang;
                        return ChoiceChip(
                          label: Text(lang),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceCard
                              : AppColors.lightSurfaceCard,
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() {
                                _selectedLanguage = lang;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24.0),

                    Text(
                      'Select Skill Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Column(
                      children: _skillLevels.map((Map<String, String> level) {
                        final String title = level['title']!;
                        final String desc = level['desc']!;
                        final String icon = level['icon']!;
                        final bool isSelected = _selectedSkillLevel == title;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceCard
                                : AppColors.lightSurfaceCard,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            leading: Text(
                              icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              desc,
                              style: TextStyle(
                                fontSize: 12.0,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedSkillLevel = title;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 28.0),

                  // Bottom Action Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16.0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentStep == 0) {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  setState(() {
                                    _currentStep = 1;
                                  });
                                }
                              } else {
                                _handleSaveProfile();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18.0),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  _currentStep == 0
                                      ? 'Continue to Preferences'
                                      : 'Complete Profile & Enter Dashboard',
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18.0,
                                ),
                              ],
                            ),
                    ),
                  ),

                  if (_currentStep == 1) ...<Widget>[
                    const SizedBox(height: 12.0),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentStep = 0;
                        });
                      },
                      child: const Text('← Back to Personal Details'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
