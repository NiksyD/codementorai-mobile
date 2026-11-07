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
      description:
          'Starter code won\'t compile, or test runner hangs / crashes.',
    ),
    ReportReasonOption(
      id: 'inaccurate_content',
      title: 'Inaccurate or misleading content',
      description:
          'Explanations, algorithms, or test assertions contain factual errors.',
    ),
    ReportReasonOption(
      id: 'copyright_plagiarism',
      title: 'Plagiarism or copyright violation',
      description:
          'Material copied directly from another author without attribution.',
    ),
    ReportReasonOption(
      id: 'inappropriate_content',
      title: 'Inappropriate or offensive content',
      description:
          'Contains profanity, discriminatory language, or harmful text.',
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
    final Color backgroundColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: _isSuccess
              ? _buildSuccessView(isDark, textPrimary, textSecondary)
              : _buildFormView(
                  isDark: isDark,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 32.0, 20.0, 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.check_rounded, size: 22.0, color: textPrimary),
              const SizedBox(width: 8.0),
              Text(
                _isUpdating ? 'Report updated' : 'Report submitted',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            _isUpdating
                ? 'Your existing report for this ${widget.activityTitle != null ? 'activity' : 'module'} now has your latest description.'
                : 'Thank you for helping keep CodeMentorAI accurate. Our moderation team has received this report.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
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
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final OutlineInputBorder fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: borderColor),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10.0, bottom: 4.0),
            width: 36.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 4.0, 4.0, 8.0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.activityTitle != null
                          ? 'Report an activity issue'
                          : 'Report an issue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      widget.activityTitle ?? widget.moduleTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, size: 22.0),
                color: textSecondary,
                constraints: const BoxConstraints(
                  minWidth: 48.0,
                  minHeight: 48.0,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Divider(height: 1.0, thickness: 1.0, color: borderColor),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 8.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'What is wrong?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4.0),
                for (final ReportReasonOption option in _reasons)
                  Semantics(
                    button: true,
                    selected: _selectedReason == option.id,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedReason = option.id);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56.0),
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: borderColor),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 1.0,
                                right: 12.0,
                              ),
                              child: Icon(
                                _selectedReason == option.id
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 20.0,
                                color: _selectedReason == option.id
                                    ? textPrimary
                                    : textSecondary,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    option.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.0,
                                      fontWeight: _selectedReason == option.id
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    option.description,
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
                      ),
                    ),
                  ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Describe the issue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${_detailsController.text.length} / 500',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: _detailsController,
                  maxLines: 4,
                  maxLength: 500,
                  onChanged: (_) => setState(() {
                    if (_errorMessage != null) _errorMessage = null;
                  }),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    color: textPrimary,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Which topic or step, what you expected, and what happened instead',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                    ),
                    counterText: '',
                    filled: false,
                    contentPadding: const EdgeInsets.all(14.0),
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(color: textPrimary, width: 1.5),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 8.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16.0,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
          child: Row(
            children: <Widget>[
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(64.0, 48.0),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: SizedBox(
                  height: 48.0,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
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
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18.0,
                            height: 18.0,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          )
                        : Text(
                            _isUpdating ? 'Update report' : 'Submit report',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                            ),
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
