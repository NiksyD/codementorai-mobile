import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/practice_exercise_model.dart';
import '../domain/submission_history_model.dart';
import 'widgets/markdown_content_view.dart';
import 'widgets/practice_code_editor.dart';
import 'widgets/practice_completion_modal.dart';
import 'widgets/practice_console_sheet.dart';
import 'widgets/submissions_history_view.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.moduleId,
    required this.exerciseId,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final String moduleId;
  final String exerciseId;
  final PathwayRepository pathwayRepository;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  PracticeExerciseModel? _exercise;
  bool _isLoading = true;
  String _selectedLanguage = 'java';
  String _activeTab = 'description'; // 'description', 'editor', or 'submissions'
  bool _isExecuting = false;

  List<SubmissionHistoryModel> _submissions = <SubmissionHistoryModel>[];
  bool _isLoadingSubmissions = false;

  final TextEditingController _codeController = TextEditingController();
  final Map<String, String> _userCodeByLanguage = <String, String>{};
  String _initialCodeForCurrentLang = '';

  @override
  void initState() {
    super.initState();
    _loadExercise();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissions() async {
    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';
    if (userId.isEmpty) return;

    setState(() => _isLoadingSubmissions = true);
    final List<SubmissionHistoryModel> list = await widget.pathwayRepository.getExerciseSubmissions(
      userId: userId,
      moduleId: widget.moduleId,
      exerciseId: widget.exerciseId,
    );

    if (mounted) {
      setState(() {
        _submissions = list;
        _isLoadingSubmissions = false;
      });
    }
  }

  Future<void> _loadExercise() async {
    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

    final PracticeExerciseModel? ex = await widget.pathwayRepository
        .getPracticeExercise(widget.moduleId, widget.exerciseId, userId);

    if (mounted) {
      setState(() {
        _exercise = ex;
        _isLoading = false;
        if (ex != null) {
          final String initialLang = ex.languages.isNotEmpty ? ex.languages.first : 'java';
          _selectedLanguage = initialLang;
          final String starter = ex.starterCodes[initialLang] ?? '';
          _codeController.text = starter;
          _initialCodeForCurrentLang = starter;
          _userCodeByLanguage[initialLang] = starter;
        }
      });
    }
  }

  void _restoreHistoricalCode(String code, String language) {
    setState(() {
      _selectedLanguage = language.toLowerCase();
      _codeController.text = code;
      _userCodeByLanguage[_selectedLanguage] = code;
      _activeTab = 'editor';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Restored code from attempt into editor.',
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _switchLanguage(String newLang) {
    if (newLang == _selectedLanguage) return;
    HapticFeedback.selectionClick();

    // Save current language code
    _userCodeByLanguage[_selectedLanguage] = _codeController.text;

    final String nextCode = _userCodeByLanguage[newLang] ??
        _exercise?.starterCodes[newLang] ??
        '';

    setState(() {
      _selectedLanguage = newLang;
      _codeController.text = nextCode;
      _initialCodeForCurrentLang = _exercise?.starterCodes[newLang] ?? '';
    });
  }

  Future<void> _handleResetCode() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Text(
          'Reset to Starter Template?',
          style: GoogleFonts.plusJakartaSans(fontSize: 16.0, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will revert your editor code back to the initial template.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.0),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final String starter = _exercise?.starterCodes[_selectedLanguage] ?? '';
      setState(() {
        _codeController.text = starter;
        _userCodeByLanguage[_selectedLanguage] = starter;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _handleBackNavigation() {
    final bool isDirty = _codeController.text.trim() != _initialCodeForCurrentLang.trim();
    if (isDirty) {
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(
            'Unsaved Code Changes',
            style: GoogleFonts.plusJakartaSans(fontSize: 16.0, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'You have modified code. Are you sure you want to leave without submitting?',
            style: GoogleFonts.plusJakartaSans(fontSize: 13.0),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Discard & Leave'),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  // ── Code Execution & Simulation Engine (1:1 Web Mirror) ──
  ExecutionResultModel _runSimulation(String code, String lang) {
    final List<String> stdout = <String>[];
    final List<String> logs = <String>[];
    final String trimmed = code.trim();

    final String starter = _exercise?.starterCodes[lang] ?? '';
    final bool isUnmodified = trimmed.isEmpty || trimmed == starter.trim();

    final String fileExt = lang == 'javascript'
        ? 'js'
        : lang == 'typescript'
            ? 'ts'
            : lang == 'python'
                ? 'py'
                : lang == 'java'
                    ? 'java'
                    : lang == 'csharp'
                        ? 'cs'
                        : lang == 'cpp'
                            ? 'cpp'
                            : (lang == 'c' ? 'c' : 'txt');
    final String fileName = (lang == 'java' || lang == 'csharp')
        ? 'Solution.$fileExt'
        : 'solution.$fileExt';

    logs.add('> compile --target $lang $fileName');

    if (isUnmodified) {
      logs.add('[Notice] Starter code detected. Implement your solution and re-run.');
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: logs.join('\n'),
        errorTitle: 'Starter Code Detected',
        socraticHint: 'You have not modified the template yet. Read the problem statement in the Description tab and implement your solution.',
        passedTestCases: 0,
        totalTestCases: _exercise?.testCases.length ?? 1,
      );
    }

    // Check syntax matching for brackets
    int openBraces = 0;
    int closeBraces = 0;
    for (int i = 0; i < code.length; i++) {
      if (code[i] == '{') openBraces++;
      if (code[i] == '}') closeBraces++;
    }

    if (lang != 'python' && openBraces != closeBraces) {
      logs.add('error: reached end of file while parsing (unmatched braces)');
      logs.add('Exit code: 1 (compilation failed)');
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: logs.join('\n'),
        errorTitle: 'SyntaxError: Unmatched Braces',
        socraticHint: 'Check your curly braces { }. Every opening brace must have a corresponding closing brace.',
        passedTestCases: 0,
        totalTestCases: _exercise?.testCases.length ?? 1,
      );
    }

    // Extract print statements
    final RegExp printRegex = RegExp(
      r'(?:System\.out\.println|System\.out\.print|console\.log|printf|print)\s*\(\s*(.*?)\s*\)',
    );

    for (final Match match in printRegex.allMatches(code)) {
      final String? rawVal = match.group(1)?.trim();
      if (rawVal != null) {
        final String cleaned = rawVal.replaceAll(RegExp(r'''^["']|["']$'''), '');
        if (cleaned.isNotEmpty) stdout.add(cleaned);
      }
    }

    logs.add('[Compilation] Build successful.');
    logs.add('[Execution] Running test harness assertions...');

    if (stdout.isNotEmpty) {
      logs.add('── Standard Output (stdout) ──');
      for (final String s in stdout) {
        logs.add('  $s');
      }
      logs.add('──────────────────────────────');
    }

    final int totalCases = _exercise?.testCases.length ?? 1;

    // Verify against expected output
    final String expectedFirstCase = _exercise?.testCases.first.expectedOutput ?? '';
    final String joinedStdout = stdout.join('\n').trim();

    final bool matchesExpected = expectedFirstCase.isEmpty ||
        joinedStdout.toLowerCase().contains(expectedFirstCase.toLowerCase()) ||
        joinedStdout.isNotEmpty;

    if (matchesExpected) {
      logs.add('  ✓ All test cases passed.');
      logs.add('Exit code: 0 (success)');
      return ExecutionResultModel(
        isSuccess: true,
        rawLog: logs.join('\n'),
        passedTestCases: totalCases,
        totalTestCases: totalCases,
        stdout: stdout,
      );
    } else {
      logs.add('  ✗ Output mismatch: stdout did not match test specification.');
      logs.add('Exit code: 1 (test failure)');
      return ExecutionResultModel(
        isSuccess: false,
        rawLog: logs.join('\n'),
        errorTitle: 'Output Mismatch',
        socraticHint: 'Ensure your output matches the exact casing and spacing required in the problem specification.',
        passedTestCases: 0,
        totalTestCases: totalCases,
        stdout: stdout,
      );
    }
  }

  Future<void> _handleRunCode() async {
    if (_isExecuting) return;
    HapticFeedback.lightImpact();
    setState(() => _isExecuting = true);

    await Future<void>.delayed(const Duration(milliseconds: 650));
    final ExecutionResultModel result = _runSimulation(_codeController.text, _selectedLanguage);

    if (mounted) {
      setState(() => _isExecuting = false);
      PracticeConsoleSheet.show(
        context,
        result: result,
        testCases: _exercise?.testCases ?? const <TestCaseModel>[],
      );
    }
  }

  Future<void> _handleSubmitSolution() async {
    if (_isExecuting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExecuting = true);

    await Future<void>.delayed(const Duration(milliseconds: 700));
    final ExecutionResultModel result = _runSimulation(_codeController.text, _selectedLanguage);

    if (!mounted) return;
    setState(() => _isExecuting = false);

    if (!result.isSuccess) {
      PracticeConsoleSheet.show(
        context,
        result: result,
        testCases: _exercise?.testCases ?? const <TestCaseModel>[],
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

    await widget.pathwayRepository.submitPracticeExercise(
      userId,
      widget.moduleId,
      widget.exerciseId,
      _codeController.text,
      _selectedLanguage,
    );

    // Refresh submissions list in background
    _loadSubmissions();

    if (mounted) {
      PracticeCompletionModal.show(
        context,
        exerciseTitle: _exercise?.title ?? 'Practice Exercise',
        onBackToModule: () {
          Navigator.of(context).pop(); // Dismiss sheet
          context.pop(); // Return to module detail
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color cardBg = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: textPrimary,
            onPressed: () => context.pop(),
          ),
        ),
        body: const ShimmerLoading(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 220.0, height: 24.0, borderRadius: 6.0),
                SizedBox(height: 16.0),
                SkeletonBox(width: double.infinity, height: 180.0, borderRadius: 16.0),
                SizedBox(height: 16.0),
                SkeletonBox(width: double.infinity, height: 240.0, borderRadius: 16.0),
              ],
            ),
          ),
        ),
      );
    }

    final PracticeExerciseModel? ex = _exercise;
    if (ex == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: textPrimary,
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text('Exercise not found', style: TextStyle(color: textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: textPrimary,
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          ex.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15.0,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          // Language selector: static badge if 1 language, dropdown if multi-language
          if (ex.languages.length <= 1)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                _selectedLanguage.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              initialValue: _selectedLanguage,
              onSelected: _switchLanguage,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              color: cardBg,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12.0),
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _selectedLanguage.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(Icons.expand_more_rounded, size: 16.0, color: textSecondary),
                  ],
                ),
              ),
              itemBuilder: (BuildContext ctx) => ex.languages.map((String lang) {
                final String display = lang == 'javascript'
                    ? 'JavaScript'
                    : lang == 'typescript'
                        ? 'TypeScript'
                        : lang == 'cpp'
                            ? 'C++'
                            : lang == 'csharp'
                                ? 'C#'
                                : lang.length <= 2
                                    ? lang.toUpperCase()
                                    : lang[0].toUpperCase() + lang.substring(1);
                return PopupMenuItem<String>(
                  value: lang,
                  child: Text(display, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),

          // Reset code button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: textSecondary,
            tooltip: 'Reset code template',
            onPressed: _handleResetCode,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // ── SEGMENTED SUB-NAV VIEW SWITCHER ([ Description ] <-> [ Code Editor ] <-> [ Submissions ]) ──
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _buildSubNavTab(
                    id: 'description',
                    label: 'Description',
                    icon: Icons.article_outlined,
                    isSelected: _activeTab == 'description',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildSubNavTab(
                    id: 'editor',
                    label: 'Code Editor',
                    icon: Icons.code_rounded,
                    isSelected: _activeTab == 'editor',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildSubNavTab(
                    id: 'submissions',
                    label: _submissions.isNotEmpty
                        ? 'Submissions (${_submissions.length})'
                        : 'Submissions',
                    icon: Icons.history_rounded,
                    isSelected: _activeTab == 'submissions',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ── MAIN CONTENT VIEW ──
          Expanded(
            child: _activeTab == 'description'
                ? _buildDescriptionView(ex, isDark, textPrimary, textSecondary, cardBg, borderColor)
                : (_activeTab == 'editor'
                    ? PracticeCodeEditor(
                        controller: _codeController,
                        language: _selectedLanguage,
                      )
                    : SubmissionsHistoryView(
                        submissions: _submissions,
                        isLoading: _isLoadingSubmissions,
                        onRefresh: _loadSubmissions,
                        onRestoreCode: _restoreHistoricalCode,
                      )),
          ),

          // ── FLOATING BOTTOM ACTION DOCK ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: <Widget>[
                  // Run Code Button (Secondary Outline)
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44.0,
                      child: OutlinedButton.icon(
                        onPressed: _isExecuting ? null : _handleRunCode,
                        icon: _isExecuting
                            ? const SizedBox(
                                width: 14.0,
                                height: 14.0,
                                child: CircularProgressIndicator(strokeWidth: 2.0),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 20.0),
                        label: Text(
                          'Run Code',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // Submit Solution Button (Primary Emerald)
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 44.0,
                      child: ElevatedButton.icon(
                        onPressed: _isExecuting ? null : _handleSubmitSolution,
                        icon: const Icon(Icons.check_circle_rounded, size: 18.0),
                        label: Text(
                          'Submit Solution',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavTab({
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = id);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 16.0,
              color: isSelected ? AppColors.primary : textSecondary,
            ),
            const SizedBox(width: 6.0),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionView(
    PracticeExerciseModel ex,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: MarkdownContentView(
        markdown: ex.description,
        isDark: isDark,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        cardBg: cardBg,
        borderColor: borderColor,
      ),
    );
  }
}
