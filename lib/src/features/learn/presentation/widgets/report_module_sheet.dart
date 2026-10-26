import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../constants/app_colors.dart';
import '../../data/pathway_repository.dart';

class ReportReasonOption {
  const ReportReasonOption({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class ReportModuleSheet extends StatefulWidget {
  const ReportModuleSheet({
    super.key,
    required this.moduleId,
    required this.moduleTitle,
    this.activityId,
    this.activityTitle,
    required this.pathwayRepository,
  });

  final String moduleId;
  final String moduleTitle;
  final String? activityId;
  final String? activityTitle;
  final PathwayRepository pathwayRepository;

  static Future<bool?> show(
    BuildContext context, {
    required String moduleId,
    required String moduleTitle,
    String? activityId,
    String? activityTitle,
    required PathwayRepository pathwayRepository,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ReportModuleSheet(
        moduleId: moduleId,
        moduleTitle: moduleTitle,
        activityId: activityId,
        activityTitle: activityTitle,
        pathwayRepository: pathwayRepository,
      ),
    );
  }

  @override
  State<ReportModuleSheet> createState() => _ReportModuleSheetState();
}

class _ReportModuleSheetState extends State<ReportModuleSheet> {
  static const List<ReportReasonOption> _reasons = <ReportReasonOption>[
    ReportReasonOption(
      id: 'broken_code',
      title: 'Broken code or runner failure',
      description: 'Starter code won\'t compile, or test runner hangs / crashes.',
    ),
    ReportReasonOption(
      id: 'inaccurate_content',
      title: 'Inaccurate or misleading content',
      description: 'Explanations, algorithms, or test assertions contain factual errors.',
    ),
    ReportReasonOption(
      id: 'copyright_plagiarism',
      title: 'Plagiarism or copyright violation',
      description: 'Material copied directly from another author without attribution.',
    ),
    ReportReasonOption(
      id: 'inappropriate_content',
      title: 'Inappropriate or offensive content',
      description: 'Contains profanity, discriminatory language, or harmful text.',
    ),
    ReportReasonOption(
      id: 'other',
      title: 'Other issue',
      description: 'Any other problem not covered by the categories above.',
    ),
  ];

  String _selectedReason = _reasons.first.id;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;
  bool _isUpdating = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingReport();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingReport() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final Map<String, dynamic>? existing = await widget.pathwayRepository
          .getActiveModuleReport(
        moduleId: widget.moduleId,
        userId: user.id,
        activityId: widget.activityId,
      );

      if (mounted && existing != null) {
        setState(() {
          _isUpdating = true;
          if (existing['report_reason'] != null) {
            _selectedReason = existing['report_reason'] as String;
          }
          if (existing['report_details'] != null) {
            _detailsController.text = existing['report_details'] as String;
          }
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    final String details = _detailsController.text.trim();
    if (details.isEmpty) {
      setState(() => _errorMessage = 'Please describe the issue in detail.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Please log in to submit a report.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();
    final bool ok = await widget.pathwayRepository.submitModuleReport(
      moduleId: widget.moduleId,
      userId: user.id,
      reason: _selectedReason,
      details: details,
      activityId: widget.activityId,
    );

    if (!mounted) return;

    if (ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to submit report. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color cardColor =
        isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: _isSuccess
              ? _buildSuccessView(textPrimary, textSecondary)
              : _buildFormView(
                  isDark: isDark,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 32.0,
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            _isUpdating ? 'Report Updated' : 'Report Submitted',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            _isUpdating
                ? 'Your existing report for this ${widget.activityTitle != null ? 'activity' : 'module'} has been updated with your latest description.'
                : 'Thank you for helping keep CodeMentorAI accurate and high quality. Our moderation team has received this report.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimaryDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Drag Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
            width: 36.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
        ),

        // Header Row
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 4.0, 16.0, 12.0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.activityTitle != null
                          ? 'Report Activity Issue'
                          : 'Report an issue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      widget.activityTitle ?? widget.moduleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20.0),
                color: textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        const Divider(height: 1.0, thickness: 0.8),

        // Body Scrollable Area
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SELECT ISSUE CATEGORY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10.0),

                // Category List
                ...List<Widget>.generate(_reasons.length, (int index) {
                  final ReportReasonOption option = _reasons[index];
                  final bool isSelected = _selectedReason == option.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedReason = option.id);
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08)
                              : cardColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : borderColor.withValues(alpha: 0.6),
                            width: isSelected ? 1.4 : 0.8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0, right: 10.0),
                              child: Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 16.0,
                                color: isSelected
                                    ? AppColors.primary
                                    : textSecondary.withValues(alpha: 0.6),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    option.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.0,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? textPrimary
                                          : textPrimary.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    option.description,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                      height: 1.3,
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
                }),

                const SizedBox(height: 16.0),

                Text(
                  'ISSUE DESCRIPTION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8.0),

                // Description Input
                TextField(
                  controller: _detailsController,
                  maxLines: 4,
                  maxLength: 500,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Describe the exact topic or step, expected behavior, and observed error...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: cardColor.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.all(14.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide(color: borderColor, width: 0.8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide(color: borderColor, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 8.0),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Footer Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 16.0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13.0),
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimaryDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.onPrimaryDark,
                            ),
                          ),
                        )
                      : Text(
                          _isUpdating ? 'Update Report' : 'Submit Report',
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
      ],
    );
  }
}
