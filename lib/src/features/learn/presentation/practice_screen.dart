import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/code_execution_service.dart';
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
  String _activeTab = 'description'; // 'description', 'editor', 'testcases', or 'submissions'
  bool _isExecuting = false;
  ExecutionResultModel? _lastResult;
  int _selectedTestCaseIdx = 0;

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

  Future<void> _loadSubmissions({bool forceLoading = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';
    if (userId.isEmpty) return;

    if (_submissions.isEmpty || forceLoading) {
      setState(() => _isLoadingSubmissions = true);
    }
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
            ? AppColors.darkSurfaceCard
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
              ? AppColors.darkSurfaceCard
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

  Future<void> _handleRunCode() async {
    if (_isExecuting) return;
    HapticFeedback.lightImpact();
    setState(() => _isExecuting = true);

    final TestCaseModel? primaryCase = (_exercise?.testCases.isNotEmpty == true)
        ? _exercise!.testCases.first
        : null;

    final String stdin = primaryCase?.input ?? '';
    final String expectedOutput = primaryCase?.expectedOutput ?? '42';
    final int totalCases = _exercise?.testCases.length ?? 1;

    final ExecutionResultModel result = await CodeExecutionService.execute(
      code: _codeController.text,
      language: _selectedLanguage,
      stdin: stdin,
      expectedOutput: expectedOutput,
      totalTestCases: totalCases,
      apiBaseUrl: dotenv.env['API_BASE_URL'],
    );

    if (mounted) {
      setState(() {
        _isExecuting = false;
        _lastResult = result;
      });
      PracticeConsoleSheet.show(
        context,
        result: result,
        testCases: _exercise?.testCases ?? const <TestCaseModel>[],
        onRunCode: _handleRunCode,
      );
    }
  }

  Future<void> _handleSubmitSolution() async {
    if (_isExecuting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExecuting = true);

    final TestCaseModel? primaryCase = (_exercise?.testCases.isNotEmpty == true)
        ? _exercise!.testCases.first
        : null;

    final String stdin = primaryCase?.input ?? '';
    final String expectedOutput = primaryCase?.expectedOutput ?? '42';
    final int totalCases = _exercise?.testCases.length ?? 1;

    final ExecutionResultModel result = await CodeExecutionService.execute(
      code: _codeController.text,
      language: _selectedLanguage,
      stdin: stdin,
      expectedOutput: expectedOutput,
      totalTestCases: totalCases,
      apiBaseUrl: dotenv.env['API_BASE_URL'],
    );

    if (!mounted) return;
    setState(() {
      _isExecuting = false;
      _lastResult = result;
    });

    if (!result.isSuccess) {
      PracticeConsoleSheet.show(
        context,
        result: result,
        testCases: _exercise?.testCases ?? const <TestCaseModel>[],
        onRunCode: _handleRunCode,
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
    _loadSubmissions(forceLoading: true);

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
          // Segmented Sub-Nav: [ Description ] <-> [ Code Editor ] <-> [ Test Cases ] <-> [ Submissions ]
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.8),
              ),
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
                    label: 'Editor',
                    icon: Icons.code_rounded,
                    isSelected: _activeTab == 'editor',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildSubNavTab(
                    id: 'testcases',
                    label: 'Test Cases',
                    icon: Icons.checklist_rounded,
                    isSelected: _activeTab == 'testcases',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                Expanded(
                  child: _buildSubNavTab(
                    id: 'submissions',
                    label: _submissions.isNotEmpty
                        ? 'History (${_submissions.length})'
                        : 'History',
                    icon: Icons.history_rounded,
                    isSelected: _activeTab == 'submissions',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Main View
          Expanded(
            child: _activeTab == 'description'
                ? _buildDescriptionView(
                    ex,
                    isDark,
                    textPrimary,
                    textSecondary,
                    cardBg,
                    borderColor,
                  )
                : (_activeTab == 'editor'
                    ? PracticeCodeEditor(
                        controller: _codeController,
                        language: _selectedLanguage,
                      )
                    : (_activeTab == 'testcases'
                        ? _buildTestCasesView(
                            ex,
                            isDark,
                            textPrimary,
                            textSecondary,
                            cardBg,
                            borderColor,
                          )
                        : SubmissionsHistoryView(
                            submissions: _submissions,
                            isLoading: _isLoadingSubmissions,
                            onRefresh: _loadSubmissions,
                            onRestoreCode: _restoreHistoricalCode,
                          ))),
          ),

          // Floating Bottom Action Dock
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: <Widget>[
                  // Quick Test Cases / Console Drawer Button
                  Container(
                    margin: const EdgeInsets.only(right: 10.0),
                    child: SizedBox(
                      height: 44.0,
                      width: 44.0,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          PracticeConsoleSheet.show(
                            context,
                            result: _lastResult,
                            testCases: ex.testCases,
                            onRunCode: _handleRunCode,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          foregroundColor: textSecondary,
                        ),
                        child: const Icon(Icons.terminal_rounded, size: 20.0),
                      ),
                    ),
                  ),

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
                          foregroundColor:
                              isDark ? AppColors.onPrimaryDark : Colors.white,
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
              size: 15.0,
              color: isSelected ? AppColors.primary : textSecondary,
            ),
            const SizedBox(width: 5.0),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Problem Description Blocks
          MarkdownContentView(
            markdown: ex.description,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            cardBg: cardBg,
            borderColor: borderColor,
          ),

          // Examples & Test Cases (1:1 with Web BrowserIde)
          if (ex.testCases.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24.0),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.playlist_add_check_rounded,
                  size: 18.0,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'EXAMPLES & TEST CASES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            ...ex.testCases.take(3).toList().asMap().entries.map((entry) {
              final int idx = entry.key;
              final TestCaseModel tc = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(13.0),
                        ),
                        border: Border(
                          bottom: BorderSide(color: borderColor, width: 0.8),
                        ),
                      ),
                      child: Text(
                        'Example ${idx + 1}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (tc.input.isNotEmpty) ...<Widget>[
                            Text(
                              'Input:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkBackground
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                tc.input,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10.0),
                          ],
                          Text(
                            'Output:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF3ECF8E),
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkBackground
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              tc.expectedOutput,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                color: const Color(0xFF3ECF8E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTestCasesView(
    PracticeExerciseModel ex,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
  ) {
    if (ex.testCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No test cases defined for this exercise.',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final int safeIdx = _selectedTestCaseIdx.clamp(0, ex.testCases.length - 1);
    final TestCaseModel tc = ex.testCases[safeIdx];
    final bool hasRun = _lastResult != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'TEST CASES (${ex.testCases.length})',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
              if (hasRun)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: (_lastResult!.isSuccess ? const Color(0xFF3ECF8E) : AppColors.error).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    _lastResult!.isSuccess
                        ? 'Passed (${_lastResult!.passedTestCases}/${_lastResult!.totalTestCases})'
                        : 'Failed (${_lastResult!.passedTestCases}/${_lastResult!.totalTestCases})',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: _lastResult!.isSuccess ? const Color(0xFF3ECF8E) : AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Case Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(ex.testCases.length, (int idx) {
                final bool isSelected = safeIdx == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text('Case ${idx + 1}'),
                    selected: isSelected,
                    onSelected: (bool val) {
                      if (val) setState(() => _selectedTestCaseIdx = idx);
                    },
                    labelStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
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
          const SizedBox(height: 16.0),

          // Input Block
          Text(
            'Input',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: borderColor),
            ),
            child: SelectableText(
              tc.input.isEmpty ? '(empty input)' : tc.input,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12.0,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14.0),

          // Expected Output Block
          Text(
            'Expected Output',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: borderColor),
            ),
            child: SelectableText(
              tc.expectedOutput,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12.0,
                color: const Color(0xFF3ECF8E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14.0),

          // Actual Output / Status
          if (hasRun) ...<Widget>[
            Text(
              'Actual Output (stdout)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 6.0),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: borderColor),
              ),
              child: SelectableText(
                _lastResult!.stdout.isNotEmpty
                    ? _lastResult!.stdout.join('\n')
                    : (_lastResult!.isSuccess ? tc.expectedOutput : 'No stdout recorded'),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.0,
                  color: _lastResult!.isSuccess ? const Color(0xFF3ECF8E) : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18.0,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      'Ready to validate. Tap "Run Code" below to run your code against this case.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
