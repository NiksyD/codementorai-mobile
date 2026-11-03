import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Real-time password strength meter with a requirements checklist.
/// Shared by Register and Reset Password so both screens behave the same.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  static const int minLength = 8;

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9]');

  /// True when [value] satisfies every requirement in the checklist.
  static bool meetsRequirements(String value) =>
      value.length >= minLength &&
      _upper.hasMatch(value) &&
      _lower.hasMatch(value) &&
      (_digit.hasMatch(value) || _symbol.hasMatch(value));

  bool get _hasMinLength => password.length >= minLength;
  bool get _hasUpperAndLower =>
      _upper.hasMatch(password) && _lower.hasMatch(password);
  bool get _hasNumberOrSymbol =>
      _digit.hasMatch(password) || _symbol.hasMatch(password);

  /// Score from 0 (empty) to 4 (strong).
  int get score {
    if (password.isEmpty) return 0;
    int value = 0;
    if (_hasMinLength) value += 1;
    if (_hasUpperAndLower) value += 1;
    if (_digit.hasMatch(password)) value += 1;
    if (_symbol.hasMatch(password) || password.length >= 12) value += 1;
    return value;
  }

  static const List<String> _labels = <String>[
    'Too short',
    'Weak',
    'Fair',
    'Good',
    'Strong',
  ];

  Color _colorFor(int s) {
    switch (s) {
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.info;
      case 4:
        return AppColors.primary;
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color trackColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final int s = score;
    final Color meterColor = _colorFor(s);
    final String label = _labels[s];

    return Semantics(
      container: true,
      label: 'Password strength: $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 4-bar strength indicator
          Row(
            children: List<Widget>.generate(4, (int index) {
              final bool isFilled = index < s;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5.0,
                  margin: EdgeInsets.only(right: index < 3 ? 5.0 : 0.0),
                  decoration: BoxDecoration(
                    color: isFilled ? meterColor : trackColor,
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Password strength',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: meterColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Requirements checklist
          _CriteriaItem(
            isValid: _hasMinLength,
            label: 'At least $minLength characters',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 6.0),
          _CriteriaItem(
            isValid: _hasUpperAndLower,
            label: 'Uppercase and lowercase letters',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 6.0),
          _CriteriaItem(
            isValid: _hasNumberOrSymbol,
            label: 'At least one number or symbol',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _CriteriaItem extends StatelessWidget {
  const _CriteriaItem({
    required this.isValid,
    required this.label,
    required this.textPrimary,
    required this.textSecondary,
  });

  final bool isValid;
  final String label;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          isValid
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16.0,
          color: isValid ? AppColors.primary : textSecondary,
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            isValid ? '$label (met)' : label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: isValid ? FontWeight.w600 : FontWeight.w500,
              color: isValid ? textPrimary : textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
