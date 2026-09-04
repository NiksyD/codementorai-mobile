import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../common_widgets/language_avatar_stack.dart';
import '../../../../constants/app_colors.dart';
import '../../domain/assessment_model.dart';

class AssessmentPreviewSheet extends StatefulWidget {
  const AssessmentPreviewSheet({
    super.key,
    required this.assessment,
    required this.onStart,
  });

  final AssessmentModel assessment;
  final VoidCallback onStart;

  static Future<void> show(
    BuildContext context, {
    required AssessmentModel assessment,
    required VoidCallback onStart,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext ctx) => AssessmentPreviewSheet(
        assessment: assessment,
        onStart: onStart,
      ),
    );
  }

  @override
  State<AssessmentPreviewSheet> createState() => _AssessmentPreviewSheetState();
}

class _AssessmentPreviewSheetState extends State<AssessmentPreviewSheet> {
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
    final Color bgColor =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final AssessmentModel asm = widget.assessment;
    final Color diffColor = _getDifficultyColor(asm.difficulty);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 32.0,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 38.0,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 10.0, bottom: 12.0),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 16.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Header Row: Avatar Stack + Difficulty Badge + Close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          LanguageAvatarStack(
                            languages: asm.stack,
                            size: 32.0,
                          ),
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color: diffColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: diffColor.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  asm.difficulty.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: diffColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded, size: 20.0),
                                color: textSecondary,
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.darkBackground
                                      : AppColors.lightBackground,
                                  padding: const EdgeInsets.all(6.0),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14.0),

                      // Title
                      Text(
                        asm.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6.0),

                      // Description
                      Text(
                        asm.description,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // Parameter Card (Time, Challenges, Score, Attempts)
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'EXAM SPECIFICATIONS',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _buildSpecTile(
                                    icon: Icons.timer_outlined,
                                    label: 'Duration',
                                    value: '${asm.durationMins} mins',
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                ),
                                Container(
                                  width: 1.0,
                                  height: 36.0,
                                  color: borderColor,
                                ),
                                Expanded(
                                  child: _buildSpecTile(
                                    icon: Icons.code_rounded,
                                    label: 'Problems',
                                    value: '${asm.challengeCount} Tasks',
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10.0),
                            Divider(height: 1.0, color: borderColor),
                            const SizedBox(height: 10.0),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _buildSpecTile(
                                    icon: Icons.check_circle_outline_rounded,
                                    label: 'Benchmark',
                                    value: '${asm.passingScore}% to pass',
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                ),
                                Container(
                                  width: 1.0,
                                  height: 36.0,
                                  color: borderColor,
                                ),
                                Expanded(
                                  child: _buildSpecTile(
                                    icon: Icons.refresh_rounded,
                                    label: 'Attempts',
                                    value: 'Max ${asm.maxAttempts}',
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // Included Challenges Outline (if present)
                      if (asm.challenges.isNotEmpty) ...<Widget>[
                        Text(
                          'CURATED CHALLENGES',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        ...asm.challenges.asMap().entries.map((entry) {
                          final int idx = entry.key;
                          final AssessmentChallengeModel ch = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 10.0,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkBackground
                                  : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 22.0,
                                  height: 22.0,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${idx + 1}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Text(
                                    ch.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  '${ch.testCases.length} Tests',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8.0),
                      ],

                      // Mentor Info Footer
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 14.0,
                            backgroundColor: isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground,
                            backgroundImage: asm.mentorAvatar != null
                                ? NetworkImage(asm.mentorAvatar!)
                                : null,
                            child: asm.mentorAvatar == null
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 16.0,
                                    color: textSecondary,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Curated by',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.0,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                asm.mentorName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 12.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onStart();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: isDark
                          ? AppColors.onPrimaryDark
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.bolt_rounded, size: 18.0),
                        const SizedBox(width: 6.0),
                        Text(
                          'Start Assessment',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
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

  Widget _buildSpecTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16.0, color: AppColors.primary),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
