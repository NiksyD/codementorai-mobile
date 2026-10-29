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
    final Color sheetBg = isDark ? AppColors.darkBackground : Colors.white;
    final Color cardBg = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final bool hasRun = widget.result != null;
    final bool isSuccess = widget.result?.isSuccess ?? false;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
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
                      Icons.code_rounded,
                      color: textSecondary,
                      size: 20.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Console & Tests',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
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

          // 3 sub-tabs matching My Activity Screen segment switcher: Testcase | Test Result | Console
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18.0),
            padding: const EdgeInsets.all(3.0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: <Widget>[
                // Tab 1: Testcase
                Expanded(
                  child: _buildConsoleTabButton(
                    tabId: 'testcases',
                    icon: Icons.checklist_rounded,
                    label: 'Testcase',
                    count: widget.testCases.isNotEmpty ? widget.testCases.length : null,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 3.0),

                // Tab 2: Test Result
                Expanded(
                  child: _buildConsoleTabButton(
                    tabId: 'results',
                    icon: Icons.fact_check_rounded,
                    label: 'Test Result',
                    statusDotColor: hasRun
                        ? (isSuccess ? const Color(0xFF10B981) : AppColors.error)
                        : null,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 3.0),

                // Tab 3: Console
                Expanded(
                  child: _buildConsoleTabButton(
                    tabId: 'log',
                    icon: Icons.terminal_rounded,
                    label: 'Console',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
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
              child: _activeTab == 'testcases'
                  ? _buildTestcasesTab(cardBg, borderColor, textPrimary, textSecondary, isDark)
                  : (_activeTab == 'results'
                      ? _buildResultsTab(cardBg, borderColor, textPrimary, textSecondary, isDark, hasRun, isSuccess)
                      : _buildTerminalTab(cardBg, borderColor, textPrimary, textSecondary, hasRun, isSuccess)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleTabButton({
    required String tabId,
    required IconData icon,
    required String label,
    int? count,
    Color? statusDotColor,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isSelected = _activeTab == tabId;
    final Color selectedBg = isDark ? AppColors.darkSurface : Colors.white;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = tabId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9.0),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 14.0,
              color: isSelected ? AppColors.primary : textSecondary,
            ),
            const SizedBox(width: 4.5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? textPrimary : textSecondary,
                ),
              ),
            ),
            if (count != null) ...<Widget>[
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(999.0),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : textSecondary,
                  ),
                ),
              ),
            ],
            if (statusDotColor != null) ...<Widget>[
              const SizedBox(width: 5.0),
              Container(
                width: 6.5,
                height: 6.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusDotColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ── TAB 1: Testcase inputs & expected output browsing ─────────────────────
  Widget _buildTestcasesTab(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    if (widget.testCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text('No test cases defined', style: TextStyle(color: textSecondary)),
        ),
      );
    }

    final int safeIdx = _selectedCaseIdx.clamp(0, widget.testCases.length - 1);
    final TestCaseModel tc = widget.testCases[safeIdx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Case selector pills (clean neutral selector, matching Web)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(widget.testCases.length, (int idx) {
              final bool isSelected = _selectedCaseIdx == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text('Case ${idx + 1}'),
                  selected: isSelected,
                  onSelected: (bool val) {
                    if (val) setState(() => _selectedCaseIdx = idx);
                  },
                  labelStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppColors.primary : AppColors.primaryVariant)
                        : textSecondary,
                  ),
                  selectedColor: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.12),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : borderColor,
                      width: 1.0,
                    ),
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
          child: SelectableText(
            tc.input.isEmpty ? '(empty input)' : tc.input,
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
          child: SelectableText(
            tc.expectedOutput,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.0,
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 16.0),

        // Idle run prompt
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 18.0,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  'Tap "Run Tests" to evaluate your code against all test cases.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ),
              if (widget.onRunCode != null) ...<Widget>[
                const SizedBox(width: 12.0),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onRunCode!();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 15.0),
                  label: const Text('Run Tests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                    minimumSize: const Size(0, 36.0),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// ── TAB 2: Execution Results Comparison (1:1 with Web BrowserIde) ─────────
  Widget _buildResultsTab(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    bool hasRun,
    bool isSuccess,
  ) {
    if (!hasRun) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: <Widget>[
              Icon(Icons.science_outlined, size: 36.0, color: textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 10.0),
              Text(
                'Run your code to view test execution results.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.0, color: textSecondary),
              ),
              if (widget.onRunCode != null) ...<Widget>[
                const SizedBox(height: 14.0),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onRunCode!();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18.0),
                  label: const Text('Run Code', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (widget.testCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text('No test cases defined', style: TextStyle(color: textSecondary)),
        ),
      );
    }

    final int safeIdx = _selectedCaseIdx.clamp(0, widget.testCases.length - 1);
    final TestCaseModel tc = widget.testCases[safeIdx];

    final TestCaseResultModel? activeCr = widget.result!.caseResults.length > safeIdx
        ? widget.result!.caseResults[safeIdx]
        : null;

    final bool currentCasePassed = activeCr != null
        ? activeCr.passed
        : isSuccess;

    final String actualOutputText = activeCr != null
        ? activeCr.actual
        : (widget.result!.stdout.isNotEmpty ? widget.result!.stdout.join('\n') : (isSuccess ? tc.expectedOutput : 'No stdout recorded'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── 1. Execution Verdict Status Banner ──────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: isSuccess
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: isSuccess
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 18.0,
                color: isSuccess ? const Color(0xFF10B981) : AppColors.error,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  isSuccess
                      ? 'Accepted (${widget.result!.passedTestCases}/${widget.result!.totalTestCases} passed)'
                      : (widget.result!.isCompileError
                          ? 'Compilation Error'
                          : 'Wrong Answer (${widget.result!.passedTestCases}/${widget.result!.totalTestCases} passed)'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSuccess ? const Color(0xFF10B981) : AppColors.error,
                  ),
                ),
              ),
              if (widget.result!.runtime != null)
                Text(
                  'Runtime: ${widget.result!.runtime}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isSuccess ? const Color(0xFF10B981) : AppColors.error,
                  ),
                ),
            ],
          ),
        ),

        // ── 2. "Submit Solution →" Prompt Banner ────────────────────────────
        if (isSuccess && widget.onSubmitSolution != null) ...<Widget>[
          const SizedBox(height: 10.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'All tests passed! Submit solution to complete this exercise.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onSubmitSolution!();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Submit Solution →',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12.0),

        // ── 3. Case Selector Pills with Status Indicators ───────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(widget.testCases.length, (int idx) {
              final bool isSelected = _selectedCaseIdx == idx;
              final TestCaseResultModel? cr = widget.result!.caseResults.length > idx
                  ? widget.result!.caseResults[idx]
                  : null;
              final bool thisPassed = cr?.passed ?? isSuccess;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  showCheckmark: false,
                  avatar: Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.only(left: 4.0),
                    decoration: BoxDecoration(
                      color: thisPassed ? const Color(0xFF10B981) : AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: Text('Case ${idx + 1}'),
                  selected: isSelected,
                  onSelected: (bool val) {
                    if (val) setState(() => _selectedCaseIdx = idx);
                  },
                  labelStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppColors.primary : AppColors.primaryVariant)
                        : textSecondary,
                  ),
                  selectedColor: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.12),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : borderColor,
                      width: 1.0,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14.0),

        // ── 4. Input Box ───────────────────────────────────────────────────
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
          child: SelectableText(
            tc.input.isEmpty ? '(empty input)' : tc.input,
            style: GoogleFonts.jetBrainsMono(fontSize: 12.0, color: textPrimary),
          ),
        ),

        const SizedBox(height: 12.0),

        // ── 5. Actual Output Box ───────────────────────────────────────────
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
            color: currentCasePassed
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: currentCasePassed
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: SelectableText(
            actualOutputText,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.0,
              color: currentCasePassed ? const Color(0xFF10B981) : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12.0),

        // ── 6. Expected Output Box ─────────────────────────────────────────
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
          child: SelectableText(
            tc.expectedOutput,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.0,
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerminalTab(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool hasRun,
    bool isSuccess,
  ) {
    final String content = hasRun && widget.result != null
        ? widget.result!.rawLog
        : 'Terminal idle. Run your code to inspect compiler logs and output.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor),
      ),
      child: SelectableText(
        content,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12.0,
          height: 1.5,
          color: hasRun
              ? (isSuccess ? const Color(0xFF10B981) : const Color(0xFFF87171))
              : textSecondary,
        ),
      ),
    );
  }
}
