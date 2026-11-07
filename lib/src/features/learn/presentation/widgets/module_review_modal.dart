import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class ModuleReviewModal extends StatefulWidget {
  const ModuleReviewModal({
    super.key,
    required this.moduleTitle,
    required this.onSubmitReview,
  });

  final String moduleTitle;
  final Future<bool> Function(int rating, String comment) onSubmitReview;

  static Future<bool?> show(
    BuildContext context, {
    required String moduleTitle,
    required Future<bool> Function(int rating, String comment) onSubmitReview,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ModuleReviewModal(
        moduleTitle: moduleTitle,
        onSubmitReview: onSubmitReview,
      ),
    );
  }

  @override
  State<ModuleReviewModal> createState() => _ModuleReviewModalState();
}

class _ModuleReviewModalState extends State<ModuleReviewModal> {
  static const Map<int, String> _ratingDescriptors = <int, String>{
    1: 'Poor',
    2: 'Below Average',
    3: 'Average',
    4: 'Good',
    5: 'Excellent',
  };

  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final String comment = _commentController.text.trim();
    if (_rating < 1) {
      setState(() => _errorMessage = 'Please select a star rating.');
      return;
    }
    if (comment.isEmpty) {
      setState(() => _errorMessage = 'Please leave a brief review comment.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();
    final bool ok = await widget.onSubmitReview(_rating, comment);

    if (!mounted) return;

    if (ok) {
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to submit review. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBg = isDark
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

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final OutlineInputBorder fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: borderColor),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36.0,
                    height: 4.0,
                    margin: const EdgeInsets.only(bottom: 10.0),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Rate and review',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            widget.moduleTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              color: textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Text(
                  'Your rating',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4.0),
                Row(
                  children: <Widget>[
                    for (int star = 1; star <= 5; star++)
                      Semantics(
                        button: true,
                        selected: star == _rating,
                        label: '$star star${star == 1 ? '' : 's'}',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _rating = star;
                              if (_errorMessage != null) _errorMessage = null;
                            });
                          },
                          child: SizedBox(
                            width: 48.0,
                            height: 48.0,
                            child: Icon(
                              star <= _rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: star <= _rating
                                  ? textPrimary
                                  : textSecondary,
                              size: 32.0,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '$_rating',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.0,
                                color: textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: ' of 5  ·  ${_ratingDescriptors[_rating]}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Your review',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${_commentController.text.length} / 500',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: _commentController,
                  maxLength: 500,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
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
                        'What did you learn? How helpful was the mentor’s guidance?',
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
                if (_isSuccess) ...<Widget>[
                  const SizedBox(height: 8.0),
                  Row(
                    children: <Widget>[
                      Icon(Icons.check_rounded, size: 18.0, color: textPrimary),
                      const SizedBox(width: 6.0),
                      Text(
                        'Review submitted. Thank you.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16.0),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
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
                          onPressed:
                              (_isSubmitting ||
                                  _isSuccess ||
                                  _commentController.text.trim().isEmpty)
                              ? null
                              : _handleSubmit,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                )
                              : Text(
                                  'Submit review',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
