import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';
import '../../data/assessment_repository.dart';

class AssessmentReportReasonOption {
  const AssessmentReportReasonOption({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class ReportAssessmentSheet extends StatefulWidget {
  const ReportAssessmentSheet({
    super.key,
    required this.assessmentId,
    required this.assessmentTitle,
    required this.assessmentRepository,
    required this.userId,
  });

  final String assessmentId;
  final String assessmentTitle;
  final AssessmentRepository assessmentRepository;
  final String userId;

  static Future<bool?> show(
    BuildContext context, {
    required String assessmentId,
    required String assessmentTitle,
    required AssessmentRepository assessmentRepository,
    required String userId,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ReportAssessmentSheet(
        assessmentId: assessmentId,
        assessmentTitle: assessmentTitle,
        assessmentRepository: assessmentRepository,
        userId: userId,
      ),
    );
  }

  @override
  State<ReportAssessmentSheet> createState() => _ReportAssessmentSheetState();
}

class _ReportAssessmentSheetState extends State<ReportAssessmentSheet> {
  static const List<AssessmentReportReasonOption> _reasons =
      <AssessmentReportReasonOption>[
    AssessmentReportReasonOption(
      id: 'broken_code',
      title: 'Broken code or test runner failure',
      description: 'An exercise starter, test case, or solution cannot be run or executed properly.',
    ),
    AssessmentReportReasonOption(
      id: 'inaccurate_content',
      title: 'Inaccurate or outdated problem statement',
      description: 'The constraints, input/output requirements, or code comments contain errors.',
    ),
    AssessmentReportReasonOption(
      id: 'copyright_plagiarism',
      title: 'Plagiarism or copyright violation',
      description: 'The assessment challenges copy external competition materials without attribution.',
    ),
    AssessmentReportReasonOption(
      id: 'inappropriate_content',
      title: 'Inappropriate or offensive content',
      description: 'The content violates community guidelines or platform safety standards.',
    ),
    AssessmentReportReasonOption(
      id: 'other',
      title: 'Other technical or assessment issue',
      description: 'Feedback that does not fit into the categories above.',
    ),
  ];

  String _selectedReason = 'broken_code';
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;
  bool _isExistingReport = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveReport();
  }

  Future<void> _loadActiveReport() async {
    final Map<String, dynamic>? active =
        await widget.assessmentRepository.getActiveAssessmentReport(
      assessmentId: widget.assessmentId,
      userId: widget.userId,
    );
    if (active != null && mounted) {
      setState(() {
        _isExistingReport = true;
        final String? r = active['report_reason']?.toString();
        if (r != null && _reasons.any((AssessmentReportReasonOption opt) => opt.id == r)) {
          _selectedReason = r;
        }
        final String? d = active['report_details']?.toString();
        if (d != null && d.isNotEmpty) {
          _detailsController.text = d;
        }
      });
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final String details = _detailsController.text.trim();
    if (details.isEmpty) {
      setState(() => _errorMessage = 'Please describe the issue in detail.');
      return;
    }

    if (widget.userId.isEmpty) {
      setState(() => _errorMessage = 'Please log in to submit a report.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final bool success = await widget.assessmentRepository.submitAssessmentReport(
      assessmentId: widget.assessmentId,
      userId: widget.userId,
      reason: _selectedReason,
      details: details,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'Failed to submit report. Please try again.';
      });
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          border: Border.all(color: borderColor),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Grab Handle
              Center(
                child: Container(
                  width: 38.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),

              // Title Row
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 4.0, 16.0, 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Report Assessment',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17.0,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            widget.assessmentTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded, size: 20.0),
                      color: textSecondary,
                      padding: const EdgeInsets.all(4.0),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1.0,
                color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    .withValues(alpha: 0.6),
              ),

              // Scrollable Form Fields
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 8.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Reason Header
                      Text(
                        'WHAT IS THE ISSUE?',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      // Reason List
                      ..._reasons.map((AssessmentReportReasonOption r) {
                        final bool isSelected = _selectedReason == r.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedReason = r.id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : (isDark
                                      ? AppColors.darkBackground
                                      : AppColors.lightSurfaceCard),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : borderColor,
                                width: isSelected ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18.0,
                                  color: isSelected ? AppColors.primary : textSecondary,
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        r.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2.0),
                                      Text(
                                        r.description,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.0,
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
                      }),
                      const SizedBox(height: 12.0),

                      // Detailed Description Header
                      Text(
                        'DETAILS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      TextField(
                        controller: _detailsController,
                        maxLines: 3,
                        maxLength: 500,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Please provide specific steps or details...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            color: textSecondary.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightSurfaceCard,
                          contentPadding: const EdgeInsets.all(12.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...<Widget>[
                        const SizedBox(height: 6.0),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons with SafeArea consideration
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          side: BorderSide(color: borderColor),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: isDark
                              ? AppColors.onPrimaryDark
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16.0,
                                height: 16.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isExistingReport
                                    ? 'Update Report'
                                    : 'Submit Report',
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
          ),
        ),
      ),
    );
  }
}
