import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../common_widgets/app_toast.dart';
import '../../../../constants/app_colors.dart';

class MentorProfileSheet extends StatelessWidget {
  const MentorProfileSheet({
    super.key,
    required this.coachName,
    this.coachAvatar,
    this.currentRole,
    this.bio,
    this.rating = 4.9,
    this.studentCount = 1420,
    this.skills = const <String>[],
    this.credentials = const <String>[],
    this.githubUrl,
    this.linkedinUrl,
    this.websiteUrl,
  });

  final String coachName;
  final String? coachAvatar;
  final String? currentRole;
  final String? bio;
  final double rating;
  final int studentCount;
  final List<String> skills;
  final List<String> credentials;
  final String? githubUrl;
  final String? linkedinUrl;
  final String? websiteUrl;

  static Future<void> show(
    BuildContext context, {
    required String coachName,
    String? coachAvatar,
    String? currentRole,
    String? bio,
    double rating = 4.9,
    int studentCount = 1420,
    List<String> skills = const <String>[],
    List<String> credentials = const <String>[],
    String? githubUrl,
    String? linkedinUrl,
    String? websiteUrl,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => MentorProfileSheet(
        coachName: coachName,
        coachAvatar: coachAvatar,
        currentRole: currentRole,
        bio: bio,
        rating: rating,
        studentCount: studentCount,
        skills: skills,
        credentials: credentials,
        githubUrl: githubUrl,
        linkedinUrl: linkedinUrl,
        websiteUrl: websiteUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color surfaceColor =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color chipBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    final String effectiveRole = currentRole ??
        'Senior Software Architect & Technical Educator';
    final String effectiveBio = bio ??
        '10+ years designing fault-tolerant distributed systems and architectures. Mentoring developers worldwide with battle-tested production blueprints and socratic code review.';

    final List<String> effectiveSkills = skills.isNotEmpty
        ? skills
        : <String>[
            'Software Architecture',
            'Algorithms',
            'Data Structures',
            'SLA Benchmarking',
            'Code Optimization',
          ];

    final List<String> effectiveCredentials = credentials.isNotEmpty
        ? credentials
        : <String>[
            'Staff Principal Engineer & Systems Educator',
            'Author of Production Engineering Curriculums',
            'M.S. in Computer Science',
          ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border.all(color: borderColor),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                width: 38.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),

            // Scrollable Profile Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Hero Profile Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ClipOval(
                          child: coachAvatar != null && coachAvatar!.isNotEmpty
                              ? Image.network(
                                  coachAvatar!,
                                  width: 60.0,
                                  height: 60.0,
                                  fit: BoxFit.cover,
                                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                    return Container(
                                      width: 60.0,
                                      height: 60.0,
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      alignment: Alignment.center,
                                      child: Text(
                                        coachName.isNotEmpty ? coachName[0].toUpperCase() : 'M',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 24.0,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  width: 60.0,
                                  height: 60.0,
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  alignment: Alignment.center,
                                  child: Text(
                                    coachName.isNotEmpty ? coachName[0].toUpperCase() : 'M',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24.0,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      coachName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17.0,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 17.0,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                effectiveRole,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  color: textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // Metrics Strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          _buildMetricItem(
                            label: 'RATING',
                            value: rating.toStringAsFixed(1),
                            icon: Icons.star_rounded,
                            iconColor: const Color(0xFFFBBF24),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Container(
                            height: 28.0,
                            width: 1.0,
                            color: borderColor,
                          ),
                          _buildMetricItem(
                            label: 'LEARNERS',
                            value: '$studentCount+',
                            icon: Icons.group_outlined,
                            iconColor: AppColors.primary,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Container(
                            height: 28.0,
                            width: 1.0,
                            color: borderColor,
                          ),
                          _buildMetricItem(
                            label: 'STATUS',
                            value: 'Verified',
                            icon: Icons.verified_user_outlined,
                            iconColor: const Color(0xFF10B981),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // About / Bio
                    Text(
                      'About the Mentor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      effectiveBio,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // Expertise
                    Text(
                      'Core Expertise',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: effectiveSkills.map((String skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 5.0,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            skill,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18.0),

                    // Credentials
                    Text(
                      'Verified Credentials',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Column(
                      children: effectiveCredentials.map((String cred) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 2.0),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 15.0,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  cred,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18.0),

                    // Social links row
                    Row(
                      children: <Widget>[
                        _buildSocialButton(
                          context,
                          label: 'GitHub',
                          icon: Icons.code_rounded,
                          url: githubUrl ?? 'https://github.com',
                          isDark: isDark,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 8.0),
                        _buildSocialButton(
                          context,
                          label: 'LinkedIn',
                          icon: Icons.business_center_rounded,
                          url: linkedinUrl ?? 'https://linkedin.com',
                          isDark: isDark,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 8.0),
                        _buildSocialButton(
                          context,
                          label: 'Website',
                          icon: Icons.language_rounded,
                          url: websiteUrl ?? 'https://codementorai.dev',
                          isDark: isDark,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      height: 42.0,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor:
                              isDark ? AppColors.onPrimaryDark : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Close Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14.0, color: iconColor),
            const SizedBox(width: 4.0),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String url,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: url));
          HapticFeedback.lightImpact();
          AppToast.showSuccess(context, '$label profile link copied!');
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          backgroundColor:
              isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 14.0, color: textPrimary),
            const SizedBox(width: 4.0),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
