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
      setState(() => _errorMessage = 'Please enter a valid 6-character hub code.');
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
                  'name': 'Hub',
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
    final Color bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final EdgeInsets keyboardInsets = MediaQuery.of(context).viewInsets;

    return Container(
      padding: EdgeInsets.only(bottom: keyboardInsets.bottom),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: borderColor,
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
              'Join a hub',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 22.0),
              constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
              color: textSecondary,
            ),
          ],
        ),
        Text(
          'Enter the 6-character code your mentor gave you.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.0,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 20.0),

        // Six boxes over one hidden text field that handles typing, paste and backspace.
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(_codeLength, (int i) {
                  final String code = _fullCode;
                  final String char = i < code.length ? code[i] : '';
                  final bool isCurrentFocus = _focusNode.hasFocus &&
                      (i == code.length ||
                          (i == _codeLength - 1 && code.length == _codeLength));

                  return Container(
                    width: 46.0,
                    height: 56.0,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isCurrentFocus ? textPrimary : borderColor,
                        width: isCurrentFocus ? 2.0 : 1.0,
                      ),
                    ),
                    child: Text(
                      char,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
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
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1.0),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 16.0,
                    color: AppColors.error,
                  ),
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
          ),
        ],

        const SizedBox(height: 20.0),

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
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : Text(
                    'Join hub',
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
    final String roomName = _admissionPendingData!['name'] as String? ?? 'Hub';
    final String section = _admissionPendingData!['section'] as String? ?? 'General';
    final String mentor = _admissionPendingData!['mentorName'] as String? ?? 'Mentor';

    Widget step(IconData icon, String title, String body, bool done) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: 20.0,
          color: done ? AppColors.primary : textSecondary,
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          roomName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          'Section $section · $mentor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 16.0),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: <Widget>[
              step(
                Icons.check_circle_outline_rounded,
                'Request sent',
                'Your code was verified.',
                true,
              ),
              const SizedBox(height: 16.0),
              step(
                Icons.hourglass_empty_rounded,
                'Waiting for your mentor',
                'You get access as soon as they approve you.',
                false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),
        Text(
          'You can close this window. The status shows on your Hubs screen.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            height: 1.45,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 16.0),
        SizedBox(
          width: double.infinity,
          height: 48.0,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrimary,
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
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

