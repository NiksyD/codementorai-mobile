import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/select_filter.dart';
import '../../../common_widgets/shimmer_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/currency_formatter.dart';
import '../data/code_execution_service.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/module_detail_model.dart';
import '../domain/pathway_model.dart';
import '../domain/practice_exercise_model.dart';
import '../domain/submission_history_model.dart';
import 'widgets/challenge_completion_modal.dart';
import 'widgets/markdown_content_view.dart';
import 'widgets/module_preview_sheet.dart';
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
  bool _isLocked = false;
  double _modulePrice = 0.0;
  String _moduleTitle = 'Module';
  String _selectedLanguage = 'java';
  String _activeTab =
      'description'; // 'description', 'editor', 'testcases', or 'submissions'
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
    final List<SubmissionHistoryModel> list = await widget.pathwayRepository
        .getExerciseSubmissions(
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

    // Check module paid & purchase status (1:1 Web parity)
    bool isLocked = false;
    double price = 0.0;
    String modTitle = 'Module';

    final ModuleDetailModel? mod = await widget.pathwayRepository
        .getModuleDetails(widget.moduleId, userId);
    if (mod != null) {
      price = mod.price > 0 ? mod.price : 0.84;
      modTitle = mod.title;
      if (!mod.isPurchased) {
        isLocked = true;
      }
    }

    final PracticeExerciseModel? ch = await widget.pathwayRepository
        .getChallengeExercise(widget.moduleId, widget.challengeId, userId);

    if (mounted) {
      setState(() {
        _challenge = ch;
        _isLocked = isLocked;
        _modulePrice = price;
        _moduleTitle = modTitle;
        _isLoading = false;
        if (ch != null) {
          final String initialLang = ch.languages.isNotEmpty
              ? ch.languages.first
              : 'java';
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
    AppToast.showInfo(context, 'Restored code from attempt into editor.');
  }

  void _switchLanguage(String newLang) {
    if (newLang == _selectedLanguage) return;
    HapticFeedback.selectionClick();

    _userCodeByLanguage[_selectedLanguage] = _codeController.text;

    final String nextCode =
        _userCodeByLanguage[newLang] ?? _challenge?.starterCodes[newLang] ?? '';

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
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

    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

    final String? createdSubId = await widget.pathwayRepository
        .submitChallengeExercise(
          userId,
          widget.moduleId,
          widget.challengeId,
          _codeController.text,
          _selectedLanguage,
          passed: result.isSuccess,
        );

    // Refresh submissions list in background
    _loadSubmissions(forceLoading: true);

    if (mounted) {
      ChallengeCompletionModal.show(
        context,
        challengeTitle: _challenge?.title ?? 'Skill Challenge',
        targetTime: _challenge?.targetTime ?? 'O(N)',
        targetSpace: _challenge?.targetSpace ?? 'O(1)',
        solved: result.isSuccess,
        testSummary: '${result.passedTestCases} of ${result.totalTestCases} test cases passed',
        onViewAiReview:
            createdSubId != null &&
                createdSubId.isNotEmpty &&
                createdSubId != 'success'
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color cardBg = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

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

    if (_isLocked && !_isLoading) {
      final double effectivePrice = _modulePrice > 0 ? _modulePrice : 0.84;
      final int priceCoins = CurrencyFormatter.coinsFromUsd(effectivePrice);
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420.0),
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 36.0,
                        color: textSecondary,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'Unlock Coding Challenges',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22.0,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'This benchmark challenge in $_moduleTitle requires CodeCoins or module unlock.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          color: textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18.0,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              'Good to know: all guided practice exercises in this module are free to access.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),
                      SizedBox(
                        width: double.infinity,
                        height: 48.0,
                        child: ElevatedButton(
                          onPressed: () async {
                            final user =
                                Supabase.instance.client.auth.currentUser;
                            final String userId = user?.id ?? '';
                            final PathwayModel tempPathway = PathwayModel(
                              id: widget.moduleId,
                              title: _moduleTitle,
                              description: '',
                              language: 'java',
                              stack: const <String>['java'],
                              status: 'Not Started',
                              completion: 0,
                              totalModules: 1,
                              currentModule: '',
                              price: effectivePrice,
                            );

                            if (!context.mounted) return;
                            await ModulePreviewSheet.show(
                              context,
                              module: tempPathway,
                              onEnroll: (String tier) async {
                                final String? error = await widget
                                    .pathwayRepository
                                    .unlockModuleWithCoins(
                                      userId,
                                      widget.moduleId,
                                    );
                                if (!mounted) return;
                                final BuildContext currentCtx = this.context;
                                if (error == null) {
                                  setState(() {
                                    _isLocked = false;
                                  });
                                  if (currentCtx.mounted) {
                                    AppToast.showSuccess(
                                      currentCtx,
                                      'Coding challenges unlocked successfully!',
                                    );
                                  }
                                } else if (currentCtx.mounted) {
                                  AppToast.showError(currentCtx, error);
                                }
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: isDark
                                ? AppColors.onPrimaryDark
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.monetization_on_outlined,
                                size: 18.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                'Unlock module for $priceCoins CodeCoins',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      SizedBox(
                        width: double.infinity,
                        height: 48.0,
                        child: OutlinedButton(
                          onPressed: _popOrFallback,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: Text(
                            'Back to Module & Free Practice',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: <Widget>[
            // Language: plain text when there is one, a filter sheet when there are several
            if (ch.languages.length <= 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Text(
                    _languageName(_selectedLanguage),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ),
              )
            else
              Center(
                child: SelectFilter(
                  title: 'Language',
                  height: 40.0,
                  options: <SelectOption>[
                    for (final String lang in ch.languages)
                      SelectOption(id: lang, label: _languageName(lang)),
                  ],
                  selectedId: _selectedLanguage,
                  onSelected: _switchLanguage,
                ),
              ),

            // Copy code button (1:1 Web parity)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20.0),
              color: textSecondary,
              tooltip: 'Copy solution code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _codeController.text));
                HapticFeedback.lightImpact();
                AppToast.showSuccess(context, 'Code copied to clipboard');
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
            // Sub-navigation: plain text tabs with an underline, like the rest of the app
            _buildSubNav(
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(top: BorderSide(color: borderColor, width: 1.0)),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                )
                              : const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20.0,
                                ),
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
                          onPressed: _isExecuting
                              ? null
                              : _handleSubmitSolution,
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
                            foregroundColor: isDark
                                ? AppColors.onPrimaryDark
                                : Colors.white,
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

  String _languageName(String lang) {
    const Map<String, String> names = <String, String>{
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'php': 'PHP',
      'cpp': 'C++',
      'csharp': 'C#',
      'sql': 'SQL',
    };
    return names[lang] ??
        (lang.length <= 2
            ? lang.toUpperCase()
            : lang[0].toUpperCase() + lang.substring(1));
  }

  Widget _buildSubNav({
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final List<(String, String)> tabs = <(String, String)>[
      ('description', 'Description'),
      ('editor', 'Editor'),
      ('testcases', 'Test Cases'),
      ('submissions', 'History'),
    ];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: tabs[i].$2,
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
                          if (tabs[i].$1 == 'submissions' &&
                              _submissions.isNotEmpty)
                            TextSpan(
                              text: '  ${_submissions.length}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.0,
                                color: textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Target complexity: one plain line, no card
          Container(
            padding: const EdgeInsets.only(bottom: 14.0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.speed_rounded, size: 18.0, color: textSecondary),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'Target  ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: textSecondary,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${ch.targetTime} time · ${ch.targetSpace} space',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13.0,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
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

          // Worked examples from the test cases, unless the description already has its own
          if (ch.testCases.isNotEmpty &&
              !ch.description.toLowerCase().contains('example')) ...<Widget>[
            const SizedBox(height: 24.0),
            Text(
              'Examples',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            for (int idx = 0; idx < ch.testCases.take(3).length; idx++)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 14.0),
                padding: const EdgeInsets.only(left: 14.0),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: borderColor, width: 2.0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Example ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: '${idx + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.0,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ch.testCases[idx].input.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8.0),
                      _codeBlock(
                        label: 'Input',
                        text: ch.testCases[idx].input,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                    ],
                    const SizedBox(height: 8.0),
                    _codeBlock(
                      label: 'Output',
                      text: ch.testCases[idx].expectedOutput,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      borderColor: borderColor,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// A label over a code or output box. The box is the only tinted thing; the colours carry no meaning.
  Widget _codeBlock({
    required String label,
    required String text,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    bool selectable = false,
    Color? textColor,
    Color? boxBorder,
  }) {
    final TextStyle style = GoogleFonts.jetBrainsMono(
      fontSize: 12.5,
      color: textColor ?? textPrimary,
      height: 1.45,
    );
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
          child: selectable
              ? SelectableText(text, style: style)
              : Text(text, style: style),
        ),
      ],
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: textSecondary,
            ),
          ),
        ),
      );
    }

    final int safeIdx = _selectedTestCaseIdx.clamp(0, ch.testCases.length - 1);
    final TestCaseModel tc = ch.testCases[safeIdx];
    final bool hasRun = _lastResult != null;

    final TestCaseResultModel? activeCr =
        hasRun && _lastResult!.caseResults.length > safeIdx
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
                    : (_lastResult!.isSuccess
                          ? tc.expectedOutput
                          : 'No stdout recorded'))
              : '');

    final String resultLine = !hasRun
        ? ''
        : _lastResult!.isSuccess
        ? 'Passed ${_lastResult!.passedTestCases} of ${_lastResult!.totalTestCases}'
        : (_lastResult!.isCompileError
              ? 'Compilation error'
              : 'Failed ${_lastResult!.passedTestCases} of ${_lastResult!.totalTestCases}');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'Test cases  ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: '${ch.testCases.length}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasRun)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _lastResult!.isSuccess
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      size: 16.0,
                      color: _lastResult!.isSuccess
                          ? textPrimary
                          : AppColors.error,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      resultLine,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: _lastResult!.isSuccess
                            ? textPrimary
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4.0),

          // Case selector: plain text tabs. After a run each shows a check or a cross.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(ch.testCases.length, (int idx) {
                final bool isSelected = safeIdx == idx;
                final TestCaseResultModel? cr =
                    hasRun && _lastResult!.caseResults.length > idx
                    ? _lastResult!.caseResults[idx]
                    : null;
                final bool? thisPassed =
                    cr?.passed ?? (hasRun ? _lastResult!.isSuccess : null);

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTestCaseIdx = idx);
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
                        if (hasRun && thisPassed != null) ...<Widget>[
                          Icon(
                            thisPassed
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            size: 15.0,
                            color: thisPassed ? textSecondary : AppColors.error,
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
                                  color: isSelected
                                      ? textPrimary
                                      : textSecondary,
                                ),
                              ),
                              TextSpan(
                                text: '${idx + 1}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13.0,
                                  color: isSelected
                                      ? textPrimary
                                      : textSecondary,
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
          Divider(height: 1.0, thickness: 1.0, color: borderColor),
          const SizedBox(height: 14.0),

          _codeBlock(
            label: 'Input',
            text: tc.input.isEmpty ? '(empty input)' : tc.input,
            selectable: true,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          const SizedBox(height: 14.0),
          _codeBlock(
            label: 'Expected output',
            text: tc.expectedOutput,
            selectable: true,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          const SizedBox(height: 14.0),
          if (hasRun)
            _codeBlock(
              label: currentCasePassed
                  ? 'Actual output'
                  : 'Actual output (does not match)',
              text: actualOutputText,
              selectable: true,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              textColor: currentCasePassed ? textPrimary : AppColors.error,
              boxBorder: currentCasePassed ? borderColor : AppColors.error,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.play_arrow_rounded,
                  size: 18.0,
                  color: textSecondary,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Press Run Tests below to test your solution against this case.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),

          // Hint when a case fails
          if (hasRun && !currentCasePassed) ...<Widget>[
            const SizedBox(height: 18.0),
            Container(
              padding: const EdgeInsets.only(left: 14.0),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: borderColor, width: 2.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Mentor guidance',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    activeCr?.error ??
                        (_lastResult!.socraticHint != null &&
                                _lastResult!.socraticHint!.isNotEmpty
                            ? _lastResult!.socraticHint!
                            : 'Your program did not produce the expected output. Review constraints and assertions.'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      color: textSecondary,
                      height: 1.45,
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
