import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';
import '../../domain/practice_exercise_model.dart';

class PracticeConsoleSheet extends StatefulWidget {
  const PracticeConsoleSheet({
    super.key,
    required this.result,
    required this.testCases,
  });

  final ExecutionResultModel result;
  final List<TestCaseModel> testCases;

  static Future<void> show(
    BuildContext context, {
    required ExecutionResultModel result,
    required List<TestCaseModel> testCases,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => PracticeConsoleSheet(
        result: result,
        testCases: testCases,
      ),
    );
  }

  @override
  State<PracticeConsoleSheet> createState() => _PracticeConsoleSheetState();
}

class _PracticeConsoleSheetState extends State<PracticeConsoleSheet> {
  String _activeTab = 'cases'; // 'cases' or 'log'
  int _selectedCaseIdx = 0;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBg = isDark ? AppColors.darkBackground : Colors.white;
    final Color cardBg = isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9);
    final Color borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A);
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    final bool isSuccess = widget.result.isSuccess;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: <Widget>[
          // Drag handle
          Container(
            width: 36.0,
            height: 4.0,
            margin: const EdgeInsets.only(top: 10.0, bottom: 6.0),
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: isSuccess ? const Color(0xFF3ECF8E) : AppColors.error,
                      size: 20.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      isSuccess ? 'All Tests Passed' : 'Execution Notice',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800,
                        color: isSuccess ? const Color(0xFF3ECF8E) : AppColors.error,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Dual sub-tabs: Test Cases & Compiler Log
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 'cases'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeTab == 'cases'
                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: _activeTab == 'cases'
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4.0,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Test Cases (${widget.result.passedTestCases}/${widget.result.totalTestCases})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: _activeTab == 'cases' ? FontWeight.w700 : FontWeight.w500,
                          color: _activeTab == 'cases' ? textPrimary : textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 'log'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeTab == 'log'
                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: _activeTab == 'log'
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4.0,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Compiler Terminal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          fontWeight: _activeTab == 'log' ? FontWeight.w700 : FontWeight.w500,
                          color: _activeTab == 'log' ? textPrimary : textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12.0),

          // Content body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
              child: _activeTab == 'cases'
                  ? _buildTestCasesTab(cardBg, borderColor, textPrimary, textSecondary)
                  : _buildTerminalTab(cardBg, borderColor, textPrimary, textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCasesTab(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (widget.testCases.isEmpty) {
      return Center(
        child: Text('No test cases defined', style: TextStyle(color: textSecondary)),
      );
    }

    final TestCaseModel tc = widget.testCases[_selectedCaseIdx.clamp(0, widget.testCases.length - 1)];
    final String stdoutLine = widget.result.stdout.isNotEmpty
        ? widget.result.stdout.join('\n')
        : (widget.result.isSuccess ? tc.expectedOutput : 'No stdout recorded');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Case Selector Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(widget.testCases.length, (int idx) {
              final bool isSelected = _selectedCaseIdx == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text('Case ${idx + 1}'),
                  selected: isSelected,
                  onSelected: (bool val) {
                    if (val) setState(() => _selectedCaseIdx = idx);
                  },
                  labelStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: borderColor),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14.0),

        // Input Box
        Text(
          'Input:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            tc.input,
            style: GoogleFonts.jetBrainsMono(fontSize: 12.0, color: textPrimary),
          ),
        ),

        const SizedBox(height: 12.0),

        // Expected Output Box
        Text(
          'Expected Output:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            tc.expectedOutput,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.0,
              color: const Color(0xFF3ECF8E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 12.0),

        // Actual Output
        Text(
          'Actual Output (stdout):',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            stdoutLine,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.0,
              color: widget.result.isSuccess ? const Color(0xFF3ECF8E) : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Socratic Hint Banner if error occurred
        if (widget.result.socraticHint != null && widget.result.socraticHint!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16.0),
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: const Color(0xFF3ECF8E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFF3ECF8E).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF3ECF8E), size: 18.0),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Socratic AI Mentor Hint',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3ECF8E),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        widget.result.socraticHint!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.0,
                          height: 1.45,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTerminalTab(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor),
      ),
      child: SelectableText(
        widget.result.rawLog,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12.0,
          height: 1.5,
          color: widget.result.isSuccess ? const Color(0xFF3ECF8E) : const Color(0xFFF87171),
        ),
      ),
    );
  }
}
