import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../data/code_execution_service.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/practice_exercise_model.dart';
import '../domain/submission_history_model.dart';
import 'widgets/challenge_completion_modal.dart';
import 'widgets/markdown_content_view.dart';
import 'widgets/module_review_modal.dart';
import 'widgets/practice_code_editor.dart';
import 'widgets/practice_console_sheet.dart';
import 'widgets/report_module_sheet.dart';
import 'widgets/submissions_history_view.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.moduleId,
    required this.challengeId,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final String moduleId;
  final String challengeId;
  final PathwayRepository pathwayRepository;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  PracticeExerciseModel? _challenge;
  bool _isLoading = true;
  String _selectedLanguage = 'java';
  String _activeTab = 'description'; // 'description', 'editor', 'testcases', or 'submissions'
  bool _isExecuting = false;
  ExecutionResultModel? _lastResult;
  int _selectedTestCaseIdx = 0;

  List<SubmissionHistoryModel> _submissions = <SubmissionHistoryModel>[];
  bool _isLoadingSubmissions = false;

  final SyntaxHighlightingTextEditingController _codeController =
      SyntaxHighlightingTextEditingController(language: 'java');
  final Map<String, String> _userCodeByLanguage = <String, String>{};
  String _initialCodeForCurrentLang = '';

  @override
  void initState() {
    super.initState();
    _loadChallenge();
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
    final List<SubmissionHistoryModel> list =
        await widget.pathwayRepository.getExerciseSubmissions(
      userId: userId,
      moduleId: widget.moduleId,
      exerciseId: widget.challengeId,
    );

    if (mounted) {
      setState(() {
        _submissions = list;
        _isLoadingSubmissions = false;
      });
    }
  }

  Future<void> _loadChallenge() async {
    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

    final PracticeExerciseModel? ch = await widget.pathwayRepository
        .getChallengeExercise(widget.moduleId, widget.challengeId, userId);

    if (mounted) {
      setState(() {
        _challenge = ch;
        _isLoading = false;
        if (ch != null) {
          final String initialLang =
              ch.languages.isNotEmpty ? ch.languages.first : 'java';
          _selectedLanguage = initialLang;
          _codeController.language = initialLang;
          final String starter = ch.starterCodes[initialLang] ?? '';
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
      _codeController.language = _selectedLanguage;
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

    _userCodeByLanguage[_selectedLanguage] = _codeController.text;

    final String nextCode = _userCodeByLanguage[newLang] ??
        _challenge?.starterCodes[newLang] ??
        '';

    setState(() {
      _selectedLanguage = newLang;
      _codeController.language = newLang;
      _codeController.text = nextCode;
      _initialCodeForCurrentLang = _challenge?.starterCodes[newLang] ?? '';
    });
  }

  Future<void> _handleResetCode() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceCard
            : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Text(
          'Reset Solution Template?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will revert your editor code back to the initial challenge starter template.',
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
      final String starter = _challenge?.starterCodes[_selectedLanguage] ?? '';
      setState(() {
        _codeController.text = starter;
        _userCodeByLanguage[_selectedLanguage] = starter;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _handleBackNavigation() {
    final bool isDirty =
        _codeController.text.trim() != _initialCodeForCurrentLang.trim();
    if (isDirty) {
      showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceCard
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(
            'Unsaved Solution Code',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'You have modified solution code. Are you sure you want to leave without submitting?',
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
                _popOrFallback();
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
      _popOrFallback();
    }
  }

  void _popOrFallback() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/modules/${widget.moduleId}');
    }
  }

  Future<void> _handleRunTests() async {
    if (_isExecuting) return;
    HapticFeedback.lightImpact();
    setState(() => _isExecuting = true);

    final List<TestCaseModel> testCases =
        _challenge?.testCases ?? const <TestCaseModel>[];

    final ExecutionResultModel result = await CodeExecutionService.execute(
      code: _codeController.text,
      language: _selectedLanguage,
      testCases: testCases,
      apiBaseUrl: dotenv.env['WEB_API_URL'] ?? dotenv.env['API_BASE_URL'],
    );

    if (mounted) {
      setState(() {
        _isExecuting = false;
        _lastResult = result;
      });
      PracticeConsoleSheet.show(
        context,
        result: result,
        testCases: testCases,
        onRunCode: _handleRunTests,
        onSubmitSolution: _handleSubmitSolution,
      );
    }
  }

  Future<void> _handleSubmitSolution() async {
    if (_isExecuting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExecuting = true);

    final List<TestCaseModel> testCases =
        _challenge?.testCases ?? const <TestCaseModel>[];

    final ExecutionResultModel result = await CodeExecutionService.execute(
      code: _codeController.text,
      language: _selectedLanguage,
      testCases: testCases,
      apiBaseUrl: dotenv.env['WEB_API_URL'] ?? dotenv.env['API_BASE_URL'],
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
        testCases: testCases,
        onRunCode: _handleRunTests,
        onSubmitSolution: _handleSubmitSolution,
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

    final String? createdSubId =
        await widget.pathwayRepository.submitChallengeExercise(
      userId,
      widget.moduleId,
      widget.challengeId,
      _codeController.text,
      _selectedLanguage,
    );

    // Refresh submissions list in background
    _loadSubmissions(forceLoading: true);

    if (mounted) {
      ChallengeCompletionModal.show(
        context,
        challengeTitle: _challenge?.title ?? 'Skill Challenge',
        targetTime: _challenge?.targetTime ?? 'O(N)',
        targetSpace: _challenge?.targetSpace ?? 'O(1)',
        onViewAiReview: createdSubId != null && createdSubId.isNotEmpty && createdSubId != 'success'
            ? () {
                Navigator.of(context).pop();
                context.push('/learn/activity/$createdSubId');
              }
            : null,
        onBackToModule: () {
          Navigator.of(context).pop();
          _popOrFallback();
        },
        onRateModule: () async {
          Navigator.of(context).pop();
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) return;
          final bool? submitted = await ModuleReviewModal.show(
            context,
            moduleTitle: _challenge?.title ?? 'Module Challenge',
            onSubmitReview: (int rating, String comment) async {
              return await widget.pathwayRepository.submitModuleReview(
                moduleId: widget.moduleId,
                userId: user.id,
                rating: rating,
                comment: comment,
              );
            },
          );
          if (submitted == true && mounted) {
            AppToast.showSuccess(context, 'Review posted!');
            _popOrFallback();
          }
        },
      );
    }
  }

  Color _getDifficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return const Color(0xFF3ECF8E);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return AppColors.error;
      default:
        return const Color(0xFF3ECF8E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color cardBg = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (_isLoading) {
      return PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            _popOrFallback();
          }
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: textPrimary,
              onPressed: _popOrFallback,
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
                  SkeletonBox(
                    width: double.infinity,
                    height: 180.0,
                    borderRadius: 16.0,
                  ),
                  SizedBox(height: 16.0),
                  SkeletonBox(
                    width: double.infinity,
                    height: 240.0,
                    borderRadius: 16.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final PracticeExerciseModel? ch = _challenge;
    if (ch == null) {
      return PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            _popOrFallback();
          }
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: textPrimary,
              onPressed: _popOrFallback,
            ),
          ),
          body: Center(
            child: Text(
              'Challenge not found',
              style: TextStyle(color: textSecondary),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
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
          ch.title,
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
          if (ch.languages.length <= 1)
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              color: cardBg,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
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
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16.0,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
              itemBuilder: (BuildContext ctx) => ch.languages.map((String lang) {
                final String display = lang == 'javascript'
                    ? 'JavaScript'
                    : lang == 'php'
                        ? 'PHP'
                        : lang == 'cpp'
                            ? 'C++'
                            : lang == 'csharp'
                                ? 'C#'
                                : lang.length <= 2
                                    ? lang.toUpperCase()
                                    : lang[0].toUpperCase() + lang.substring(1);
                return PopupMenuItem<String>(
                  value: lang,
                  child: Text(display,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),

          // Copy code button (1:1 Web parity)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20.0),
            color: textSecondary,
            tooltip: 'Copy solution code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _codeController.text));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const <Widget>[
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18.0),
                      SizedBox(width: 8.0),
                      Text('Code copied to clipboard'),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: textSecondary,
            tooltip: 'Reset code template',
            onPressed: _handleResetCode,
          ),

          // Report activity issue
          IconButton(
            icon: const Icon(Icons.flag_outlined, size: 20.0),
            color: textSecondary,
            tooltip: 'Report activity issue',
            onPressed: () {
              ReportModuleSheet.show(
                context,
                moduleId: widget.moduleId,
                moduleTitle: ch.title,
                activityId: widget.challengeId,
                activityTitle: ch.title,
                pathwayRepository: widget.pathwayRepository,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Segmented Sub-Nav: [ Description ] <-> [ Code Editor ] <-> [ Test Cases ] <-> [ Submissions ]
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: borderColor.withValues(alpha: 0.6),
                  width: 1.0,
                ),
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
                    ch,
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
                            ch,
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
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: borderColor.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
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
                            testCases: ch.testCases,
                            onRunCode: _handleRunTests,
                            onSubmitSolution: _handleSubmitSolution,
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

                  // Run Tests Button
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44.0,
                      child: OutlinedButton.icon(
                        onPressed: _isExecuting ? null : _handleRunTests,
                        icon: _isExecuting
                            ? const SizedBox(
                                width: 14.0,
                                height: 14.0,
                                child: CircularProgressIndicator(strokeWidth: 2.0),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 20.0),
                        label: Text(
                          'Run Tests',
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

                  // Submit Solution Button
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 44.0,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isExecuting ? null : _handleSubmitSolution,
                        icon: const Icon(Icons.verified_rounded, size: 18.0),
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
    PracticeExerciseModel ch,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
  ) {
    final Color diffColor = _getDifficultyColor(ch.difficulty);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // SLA Benchmark & Difficulty Card (Essential for Challenges!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    ch.difficulty,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: diffColor,
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Text(
                      'SLA: ${ch.targetTime} time · ${ch.targetSpace} space',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),

          // Problem Description Blocks
          MarkdownContentView(
            markdown: ch.description,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            cardBg: cardBg,
            borderColor: borderColor,
          ),

          // Examples & Test Cases (1:1 with Web BrowserIde)
          if (ch.testCases.isNotEmpty) ...<Widget>[
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
            ...ch.testCases.take(3).toList().asMap().entries.map((entry) {
              final int idx = entry.key;
              final TestCaseModel tc = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161618) : cardBg,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF26262B) : borderColor,
                  ),
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
                            ? const Color(0xFF1E1E22)
                            : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11.0),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF26262B) : borderColor,
                            width: 0.8,
                          ),
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
                      padding: const EdgeInsets.all(12.0),
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
                                    ? const Color(0xFF121214)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF26262B) : borderColor,
                                ),
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
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF121214)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: isDark ? const Color(0xFF26262B) : borderColor,
                              ),
                            ),
                            child: Text(
                              tc.expectedOutput,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                color: const Color(0xFF10B981),
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
    PracticeExerciseModel ch,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color cardBg,
    Color borderColor,
  ) {
    if (ch.testCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No test cases defined for this challenge.',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final int safeIdx = _selectedTestCaseIdx.clamp(0, ch.testCases.length - 1);
    final TestCaseModel tc = ch.testCases[safeIdx];
    final bool hasRun = _lastResult != null;

    final TestCaseResultModel? activeCr = hasRun && _lastResult!.caseResults.length > safeIdx
        ? _lastResult!.caseResults[safeIdx]
        : null;

    final bool currentCasePassed = activeCr != null
        ? activeCr.passed
        : (hasRun ? _lastResult!.isSuccess : false);

    final String actualOutputText = activeCr != null
        ? activeCr.actual
        : (hasRun
            ? (_lastResult!.stdout.isNotEmpty
                ? _lastResult!.stdout.join('\n')
                : (_lastResult!.isSuccess ? tc.expectedOutput : 'No stdout recorded'))
            : '');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header info & status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'TEST CASES (${ch.testCases.length})',
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
                    color: (_lastResult!.isSuccess ? const Color(0xFF10B981) : AppColors.error).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: (_lastResult!.isSuccess ? const Color(0xFF10B981) : AppColors.error).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 6.0,
                        height: 6.0,
                        margin: const EdgeInsets.only(right: 6.0),
                        decoration: BoxDecoration(
                          color: _lastResult!.isSuccess ? const Color(0xFF10B981) : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        _lastResult!.isSuccess
                            ? 'Passed (${_lastResult!.passedTestCases}/${_lastResult!.totalTestCases})'
                            : (_lastResult!.isCompileError
                                ? 'Compilation Error'
                                : 'Failed (${_lastResult!.passedTestCases}/${_lastResult!.totalTestCases})'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: _lastResult!.isSuccess ? const Color(0xFF10B981) : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Case Selector Pills (Sleek minimalist horizontal selector)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(ch.testCases.length, (int idx) {
                final bool isSelected = safeIdx == idx;
                final TestCaseResultModel? cr = hasRun && _lastResult!.caseResults.length > idx
                    ? _lastResult!.caseResults[idx]
                    : null;
                final bool? thisPassed = cr?.passed ?? (hasRun ? _lastResult!.isSuccess : null);

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTestCaseIdx = idx);
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF26262B) : const Color(0xFFE2E8F0))
                            : (isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? const Color(0xFF3C3C44) : const Color(0xFFCBD5E1))
                              : (isDark ? const Color(0xFF26262B) : borderColor.withValues(alpha: 0.5)),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (hasRun && thisPassed != null) ...<Widget>[
                            Container(
                              width: 6.5,
                              height: 6.5,
                              margin: const EdgeInsets.only(right: 6.0),
                              decoration: BoxDecoration(
                                color: thisPassed ? const Color(0xFF10B981) : AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Text(
                            'Case ${idx + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? textPrimary : textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14.0),

          // Unified Test Case Card (Clean neutral simplicity pattern)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161618) : Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: isDark ? const Color(0xFF26262B) : borderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Input Block
                Text(
                  'INPUT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 6.0),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121214) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isDark ? const Color(0xFF222226) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: SelectableText(
                    tc.input.isEmpty ? '(empty input)' : tc.input,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),

                // Expected Output Block
                Text(
                  'EXPECTED OUTPUT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 6.0),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121214) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isDark ? const Color(0xFF222226) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: SelectableText(
                    tc.expectedOutput,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),

                // Actual Output (stdout)
                if (hasRun) ...<Widget>[
                  const SizedBox(height: 14.0),
                  Text(
                    'ACTUAL OUTPUT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: currentCasePassed ? const Color(0xFF10B981) : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: currentCasePassed
                          ? const Color(0xFF10B981).withValues(alpha: 0.08)
                          : AppColors.error.withValues(alpha: 0.08),
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
                        height: 1.45,
                      ),
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 14.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121214) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isDark ? const Color(0xFF222226) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 16.0,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            'Click "Run Tests" below to test your solution against this case.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
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
          ),

          // Socratic Hint if failed
          if (hasRun && !currentCasePassed) ...<Widget>[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161618) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Mentor Guidance',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          activeCr?.error ??
                              (_lastResult!.socraticHint != null && _lastResult!.socraticHint!.isNotEmpty
                                  ? _lastResult!.socraticHint!
                                  : 'Your program did not produce the expected output. Review constraints and assertions.'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: textSecondary,
                            height: 1.4,
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
      ),
    );
  }
}
