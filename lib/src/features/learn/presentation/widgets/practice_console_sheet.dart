import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';
import '../../domain/practice_exercise_model.dart';

class PracticeConsoleSheet extends StatefulWidget {
  const PracticeConsoleSheet({
    super.key,
    this.result,
    required this.testCases,
    this.onRunCode,
    this.onSubmitSolution,
  });

  final ExecutionResultModel? result;
  final List<TestCaseModel> testCases;
  final VoidCallback? onRunCode;
  final VoidCallback? onSubmitSolution;

  static Future<void> show(
    BuildContext context, {
    ExecutionResultModel? result,
    required List<TestCaseModel> testCases,
    VoidCallback? onRunCode,
    VoidCallback? onSubmitSolution,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => PracticeConsoleSheet(
        result: result,
        testCases: testCases,
        onRunCode: onRunCode,
        onSubmitSolution: onSubmitSolution,
      ),
    );
  }

  @override
  State<PracticeConsoleSheet> createState() => _PracticeConsoleSheetState();
}

class _PracticeConsoleSheetState extends State<PracticeConsoleSheet> {
  late String _activeTab; // 'testcases', 'results', or 'log'
  int _selectedCaseIdx = 0;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      if (widget.result!.isCompileError) {
        _activeTab = 'log';
      } else {
        _activeTab = 'results';
      }
    } else {
      _activeTab = 'testcases';
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

    final bool hasRun = widget.result != null;
    final bool isSuccess = widget.result?.isSuccess ?? false;

    final List<(String, String, String?)> tabs = <(String, String, String?)>[
      (
        'testcases',
        'Testcase',
        widget.testCases.isNotEmpty ? '${widget.testCases.length}' : null,
      ),
      ('results', 'Test result', null),
      ('log', 'Console', null),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Container(
              width: 36.0,
              height: 4.0,
              margin: const EdgeInsets.only(top: 10.0, bottom: 4.0),
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 0.0, 4.0, 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Console and tests',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.2,
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
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < tabs.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 22.0),
                    Semantics(
                      button: true,
                      selected: _activeTab == tabs[i].$1,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeTab = tabs[i].$1);
                        },
                        child: Container(
                          height: 48.0,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _activeTab == tabs[i].$1
                                    ? textPrimary
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (tabs[i].$1 == 'results' &&
                                  hasRun) ...<Widget>[
                                Icon(
                                  isSuccess
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  size: 16.0,
                                  color: isSuccess
                                      ? textSecondary
                                      : AppColors.error,
                                ),
                                const SizedBox(width: 3.0),
                              ],
                              Text(
                                tabs[i].$2,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  fontWeight: _activeTab == tabs[i].$1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _activeTab == tabs[i].$1
                                      ? textPrimary
                                      : textSecondary,
                                ),
                              ),
                              if (tabs[i].$3 != null) ...<Widget>[
                                const SizedBox(width: 5.0),
                                Text(
                                  tabs[i].$3!,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 16.0),
                child: _activeTab == 'testcases'
                    ? _buildTestcasesTab(
                        borderColor,
                        textPrimary,
                        textSecondary,
                        isDark,
                      )
                    : (_activeTab == 'results'
                          ? _buildResultsTab(
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isDark,
                              hasRun,
                              isSuccess,
                            )
                          : _buildTerminalTab(
                              borderColor,
                              textPrimary,
                              textSecondary,
                              isDark,
                              hasRun,
                              isSuccess,
                            )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A label over a code box. The box is the only tinted thing.
  Widget _codeBlock({
    required String label,
    required String text,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
    Color? textColor,
    Color? boxBorder,
  }) {
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
        const SizedBox(height: 4.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceLowest
                : AppColors.lightSurfaceCard,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: boxBorder ?? borderColor),
          ),
          child: SelectableText(
            text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              height: 1.45,
              color: textColor ?? textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _caseTabs({
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    List<bool?>? passed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List<Widget>.generate(widget.testCases.length, (int idx) {
            final bool isSelected = _selectedCaseIdx == idx;
            final bool? ok = passed != null && idx < passed.length
                ? passed[idx]
                : null;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCaseIdx = idx);
              },
              child: Container(
                height: 44.0,
                margin: const EdgeInsets.only(right: 18.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? textPrimary : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (ok != null) ...<Widget>[
                      Icon(
                        ok ? Icons.check_rounded : Icons.close_rounded,
                        size: 15.0,
                        color: ok ? textSecondary : AppColors.error,
                      ),
                      const SizedBox(width: 4.0),
                    ],
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Case ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? textPrimary : textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: '${idx + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.0,
                              color: isSelected ? textPrimary : textSecondary,
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
        ),
      ),
    );
  }

  /// Testcase inputs and expected output.
  Widget _buildTestcasesTab(
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    if (widget.testCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'No test cases defined',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: textSecondary,
            ),
          ),
        ),
      );
    }

    final int safeIdx = _selectedCaseIdx.clamp(0, widget.testCases.length - 1);
    final TestCaseModel tc = widget.testCases[safeIdx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _caseTabs(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          borderColor: borderColor,
        ),
        const SizedBox(height: 14.0),
        _codeBlock(
          label: 'Input',
          text: tc.input.isEmpty ? '(empty input)' : tc.input,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          isDark: isDark,
        ),
        const SizedBox(height: 14.0),
        _codeBlock(
          label: 'Expected output',
          text: tc.expectedOutput,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          isDark: isDark,
        ),
        const SizedBox(height: 18.0),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Run tests to check your code against every case.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            if (widget.onRunCode != null) ...<Widget>[
              const SizedBox(width: 12.0),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onRunCode!();
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18.0),
                label: Text(
                  'Run Tests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  minimumSize: const Size(48.0, 44.0),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// What happened on the last run, case by case.
  Widget _buildResultsTab(
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    bool hasRun,
    bool isSuccess,
  ) {
    if (!hasRun) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          children: <Widget>[
            Text(
              'No results yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Run your code to see how it does on each test case.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textSecondary,
              ),
            ),
            if (widget.onRunCode != null) ...<Widget>[
              const SizedBox(height: 14.0),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onRunCode!();
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18.0),
                label: Text(
                  'Run Code',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  minimumSize: const Size(48.0, 44.0),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (widget.testCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'No test cases defined',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: textSecondary,
            ),
          ),
        ),
      );
    }

    final int safeIdx = _selectedCaseIdx.clamp(0, widget.testCases.length - 1);
    final TestCaseModel tc = widget.testCases[safeIdx];
    final TestCaseResultModel? activeCr =
        widget.result!.caseResults.length > safeIdx
        ? widget.result!.caseResults[safeIdx]
        : null;
    final bool currentCasePassed = activeCr != null
        ? activeCr.passed
        : isSuccess;
    final String actualOutputText = activeCr != null
        ? activeCr.actual
        : (widget.result!.stdout.isNotEmpty
              ? widget.result!.stdout.join('\n')
              : (isSuccess ? tc.expectedOutput : 'No stdout recorded'));

    final String verdict = isSuccess
        ? 'Accepted'
        : (widget.result!.isCompileError
              ? 'Compilation error'
              : 'Wrong answer');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              isSuccess ? Icons.check_rounded : Icons.close_rounded,
              size: 20.0,
              color: isSuccess ? textPrimary : AppColors.error,
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: verdict,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                        color: isSuccess ? textPrimary : AppColors.error,
                      ),
                    ),
                    TextSpan(
                      text:
                          '   ${widget.result!.passedTestCases} of ${widget.result!.totalTestCases} passed',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.result!.runtime != null)
              Text(
                '${widget.result!.runtime}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.0,
                  color: textSecondary,
                ),
              ),
          ],
        ),
        if (isSuccess && widget.onSubmitSolution != null) ...<Widget>[
          const SizedBox(height: 12.0),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'All tests passed. Submit your solution to complete this exercise.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onSubmitSolution!();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: isDark
                      ? AppColors.onPrimaryDark
                      : Colors.white,
                  elevation: 0,
                  minimumSize: const Size(48.0, 44.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                  'Submit solution',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12.0),
        _caseTabs(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          borderColor: borderColor,
          passed: List<bool?>.generate(widget.testCases.length, (int idx) {
            final TestCaseResultModel? cr =
                widget.result!.caseResults.length > idx
                ? widget.result!.caseResults[idx]
                : null;
            return cr?.passed ?? isSuccess;
          }),
        ),
        const SizedBox(height: 14.0),
        _codeBlock(
          label: 'Input',
          text: tc.input.isEmpty ? '(empty input)' : tc.input,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          isDark: isDark,
        ),
        const SizedBox(height: 14.0),
        _codeBlock(
          label: currentCasePassed
              ? 'Actual output'
              : 'Actual output (does not match)',
          text: actualOutputText,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          isDark: isDark,
          textColor: currentCasePassed ? textPrimary : AppColors.error,
          boxBorder: currentCasePassed ? borderColor : AppColors.error,
        ),
        const SizedBox(height: 14.0),
        _codeBlock(
          label: 'Expected output',
          text: tc.expectedOutput,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTerminalTab(
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    bool hasRun,
    bool isSuccess,
  ) {
    final String content = hasRun && widget.result != null
        ? widget.result!.rawLog
        : 'Console is idle. Run your code to see compiler logs and output.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceLowest
            : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: borderColor),
      ),
      child: SelectableText(
        content,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12.5,
          height: 1.5,
          color: hasRun && !isSuccess
              ? AppColors.error
              : (hasRun ? textPrimary : textSecondary),
        ),
      ),
    );
  }
}
