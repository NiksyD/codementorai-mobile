import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../common_widgets/language_avatar_stack.dart';
import '../../../../constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common_widgets/app_toast.dart';
import '../../data/assessment_repository.dart';
import '../../data/supabase_assessment_repository.dart';
import '../../domain/assessment_model.dart';

class AssessmentPreviewSheet extends StatefulWidget {
  const AssessmentPreviewSheet({
    super.key,
    required this.assessment,
    required this.onStart,
    this.assessmentRepository = const SupabaseAssessmentRepository(),
    this.onUnlocked,
  });

  final AssessmentModel assessment;
  final VoidCallback onStart;
  final AssessmentRepository assessmentRepository;
  final VoidCallback? onUnlocked;

  static Future<void> show(
    BuildContext context, {
    required AssessmentModel assessment,
    required VoidCallback onStart,
    AssessmentRepository assessmentRepository = const SupabaseAssessmentRepository(),
    VoidCallback? onUnlocked,
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
        assessmentRepository: assessmentRepository,
        onUnlocked: onUnlocked,
      ),
    );
  }

  @override
  State<AssessmentPreviewSheet> createState() => _AssessmentPreviewSheetState();
}

class _AssessmentPreviewSheetState extends State<AssessmentPreviewSheet> {
  late bool _isUnlocked = widget.assessment.isUnlocked;
  bool _isUnlocking = false;
  int _balance = 0;

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    if (!_isUnlocked) _loadBalance();
  }

  Future<void> _loadBalance() async {
    final int balance = await widget.assessmentRepository.getWalletBalance(_userId);
    if (mounted) setState(() => _balance = balance);
  }

  Future<void> _handleUnlock() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);
    final String? error = await widget.assessmentRepository.unlockAssessment(
      userId: _userId,
      assessment: widget.assessment,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _isUnlocking = false);
      AppToast.showError(context, error);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _isUnlocking = false;
      _isUnlocked = true;
    });
    widget.onUnlocked?.call();
    AppToast.showSuccess(context, 'Assessment unlocked successfully!');
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
                      // Header Row: Avatar Stack + Close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          LanguageAvatarStack(
                            languages: asm.stack,
                            size: 32.0,
                          ),
                          Row(
                            children: <Widget>[
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

                      // Parameter Card (Time, Challenges)
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!_isUnlocked) ...<Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Your balance: $_balance coins',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            _balance >= asm.costCoins
                                ? 'After unlock: ${_balance - asm.costCoins}'
                                : 'Need ${asm.costCoins - _balance} more',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              color: _balance >= asm.costCoins
                                  ? textSecondary
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _isUnlocking
                            ? null
                            : _isUnlocked
                                ? () {
                                    Navigator.of(context).pop();
                                    widget.onStart();
                                  }
                                : (_balance >= asm.costCoins ? _handleUnlock : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor:
                              isDark ? AppColors.onPrimaryDark : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                        ),
                        child: _isUnlocking
                            ? const SizedBox(
                                width: 18.0,
                                height: 18.0,
                                child: CircularProgressIndicator(strokeWidth: 2.0),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    _isUnlocked
                                        ? Icons.bolt_rounded
                                        : Icons.lock_open_rounded,
                                    size: 18.0,
                                  ),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    _isUnlocked
                                        ? 'Start Assessment'
                                        : (_balance >= asm.costCoins
                                            ? 'Unlock · ${asm.costCoins} Coins'
                                            : 'Insufficient CodeCoins'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
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
