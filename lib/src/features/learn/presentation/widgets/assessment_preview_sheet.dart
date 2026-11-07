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
    final Color bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final AssessmentModel asm = widget.assessment;
    final bool canAfford = _balance >= asm.costCoins;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36.0,
                height: 4.0,
                margin: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2.0),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        LanguageAvatarStack(languages: asm.stack, size: 32.0),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 22.0),
                          color: textSecondary,
                          constraints: const BoxConstraints(
                            minWidth: 48.0,
                            minHeight: 48.0,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      asm.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      asm.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        color: textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: borderColor),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _buildSpec(
                              'Duration',
                              '${asm.durationMins} min',
                              textPrimary,
                              textSecondary,
                            ),
                          ),
                          Expanded(
                            child: _buildSpec(
                              'Challenges',
                              '${asm.challengeCount}',
                              textPrimary,
                              textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (asm.challenges.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20.0),
                      Text(
                        'Challenges',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      for (int i = 0; i < asm.challenges.length; i++)
                        Container(
                          constraints: const BoxConstraints(minHeight: 48.0),
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: borderColor),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 28.0,
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13.0,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  asm.challenges[i].title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w500,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                '${asm.challenges[i].testCases.length} tests',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.0,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 16.0),
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14.0,
                          backgroundColor: borderColor,
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
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            'Curated by ${asm.mentorName}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 12.0),
              decoration: BoxDecoration(
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
                          'Your balance',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: textSecondary,
                          ),
                        ),
                        Text(
                          '$_balance coins',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.0,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        canAfford
                            ? 'After unlock: ${_balance - asm.costCoins}'
                            : 'Need ${asm.costCoins - _balance} more',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.0,
                          color: canAfford ? textSecondary : AppColors.error,
                        ),
                      ),
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
                              : (canAfford ? _handleUnlock : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor:
                            isDark ? AppColors.onPrimaryDark : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: _isUnlocking
                          ? const SizedBox(
                              width: 18.0,
                              height: 18.0,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            )
                          : Text(
                              _isUnlocked
                                  ? 'Start Assessment'
                                  : (canAfford
                                      ? 'Unlock for ${asm.costCoins} coins'
                                      : 'Not enough coins'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpec(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}
