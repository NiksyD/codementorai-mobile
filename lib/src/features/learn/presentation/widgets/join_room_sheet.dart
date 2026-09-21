import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

class JoinRoomSheet extends StatefulWidget {
  const JoinRoomSheet({
    super.key,
    required this.onJoin,
    this.initialAdmissionData,
  });

  final Future<Map<String, dynamic>> Function(String code) onJoin;
  final Map<String, dynamic>? initialAdmissionData;

  static Future<bool?> show(
    BuildContext context, {
    required Future<Map<String, dynamic>> Function(String code) onJoin,
    Map<String, dynamic>? initialAdmissionData,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext ctx) => JoinRoomSheet(
        onJoin: onJoin,
        initialAdmissionData: initialAdmissionData,
      ),
    );
  }

  @override
  State<JoinRoomSheet> createState() => _JoinRoomSheetState();
}

class _JoinRoomSheetState extends State<JoinRoomSheet> {
  static const int _codeLength = 6;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _admissionPendingData;

  @override
  void initState() {
    super.initState();
    if (widget.initialAdmissionData != null) {
      _admissionPendingData = widget.initialAdmissionData;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _fullCode => _codeController.text.trim().toUpperCase();

  Future<void> _submit(String code) async {
    final String clean = code.trim().toUpperCase();
    if (clean.length < 5) {
      setState(() => _errorMessage = 'Please enter a valid 6-character room code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final Map<String, dynamic> result = await widget.onJoin(clean);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      HapticFeedback.mediumImpact();
      if (result['isPending'] == true || result['status'] == 'pending') {
        setState(() {
          _admissionPendingData = result['classroom'] is Map
              ? Map<String, dynamic>.from(result['classroom'] as Map)
              : <String, dynamic>{
                  'name': 'Room',
                  'section': 'General',
                };
        });
      } else {
        // Enrolled immediately
        Navigator.pop(context, true);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = result['error'] as String? ?? 'Failed to join room.';
      });
    }
  }

  void _onCodeChanged(String value) {
    setState(() => _errorMessage = null);

    if (value.length == _codeLength) {
      _submit(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final EdgeInsets keyboardInsets = MediaQuery.of(context).viewInsets;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
      child: Container(
        padding: EdgeInsets.only(bottom: keyboardInsets.bottom),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Drag handle
                Center(
                  child: Container(
                    width: 36.0,
                    height: 4.0,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),

                if (_admissionPendingData != null)
                  _buildAdmissionPendingView(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  )
                else
                  _buildJoinInputView(
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinInputView({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Join a Room',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.0,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20.0),
              color: textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          'Enter the 6-character code provided by your mentor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 24.0),

        // 6-digit segmented inputs with unified backspace & focus handling
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Invisible real TextField capturing keyboard input, IME, and backspacing natively
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: double.infinity,
                  height: 54.0,
                  child: TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    autofocus: true,
                    maxLength: _codeLength,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      _UpperCaseTextFormatter(),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onCodeChanged,
                  ),
                ),
              ),

              // Segmented visual digit boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(_codeLength, (int i) {
                  final String code = _fullCode;
                  final String char = i < code.length ? code[i] : '';
                  final bool hasVal = char.isNotEmpty;
                  final bool isCurrentFocus = _focusNode.hasFocus &&
                      (i == code.length ||
                          (i == _codeLength - 1 && code.length == _codeLength));

                  return Container(
                    width: 46.0,
                    height: 54.0,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(
                        color: isCurrentFocus
                            ? AppColors.primary
                            : (hasVal
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : borderColor),
                        width: isCurrentFocus ? 1.8 : 1.0,
                      ),
                    ),
                    child: Text(
                      char,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w800,
                        color: hasVal ? AppColors.primary : textPrimary,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.error_outline_rounded, size: 15.0, color: Colors.redAccent),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24.0),

        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: _isLoading || _fullCode.length < 5
                ? null
                : () => _submit(_fullCode),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Submit Code',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdmissionPendingView({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final String roomName = _admissionPendingData!['name'] as String? ?? 'Room';
    final String section = _admissionPendingData!['section'] as String? ?? 'General';
    final String mentor = _admissionPendingData!['mentorName'] as String? ?? 'Mentor';

    return Column(
      children: <Widget>[
        // Title
        Text(
          roomName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18.0,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                section,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              'Mentor: $mentor',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20.0),

        // Stepper Status (Matching Web 1:1)
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 26.0,
                    height: 26.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 15.0,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Admission Request Sent',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Join code verified successfully',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(left: 12.0),
                width: 1.5,
                height: 16.0,
                color: borderColor,
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 26.0,
                    height: 26.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 10.0,
                        height: 10.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Waiting for Mentor Approval',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      Text(
                        'You will get instant access once approved',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        Text(
          'Feel free to close this window. You can check your dashboard anytime for admission status updates.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.0,
            height: 1.45,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 20.0),

        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              foregroundColor: textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
                side: BorderSide(color: borderColor),
              ),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

