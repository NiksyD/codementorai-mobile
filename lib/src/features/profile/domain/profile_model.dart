class ProfileModel {
  const ProfileModel({
    required this.userId,
    required this.email,
    this.firstName,
    this.lastName,
    this.role,
    this.avatarUrl,
    this.primaryLanguage,
    this.skillLevel,
    this.phoneNumber,
    this.city,
    this.province,
    this.userOnboarded,
  });

  final String userId;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? role;
  final String? avatarUrl;
  final String? primaryLanguage;
  final String? skillLevel;
  final String? phoneNumber;
  final String? city;
  final String? province;
  final bool? userOnboarded;

  String get fullName {
    final String first = firstName?.trim() ?? '';
    final String last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return email.split('@').first;
    return '$first $last'.trim();
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      userId: json['user_id'] as String? ?? '',
      email: json['user_email'] as String? ?? '',
      firstName: json['user_first_name'] as String?,
      lastName: json['user_last_name'] as String?,
      role: json['user_role'] as String?,
      avatarUrl: json['user_avatar_url'] as String?,
      primaryLanguage: json['user_primary_language'] as String?,
      skillLevel: json['user_skill_level'] as String?,
      phoneNumber: json['user_phone_number'] as String?,
      city: json['user_city'] as String?,
      province: json['user_province'] as String?,
      userOnboarded: json['user_onboarded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    final String now = DateTime.now().toIso8601String();
    return <String, dynamic>{
      'user_id': userId,
      'user_email': email,
      'user_first_name': firstName ?? '',
      'user_last_name': lastName ?? '',
      'user_role': role ?? 'learner',
      'user_avatar_url': avatarUrl ?? '',
      'user_onboarded': userOnboarded ?? false,
      'user_email_notifications': true,
      'user_created_at': now,
      'user_updated_at': now,
    };
  }
}
