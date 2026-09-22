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

  Future<void> _handleRunTests() async {
    if (_isExecuting) return;
    HapticFeedback.lightImpact();
    setState(() => _isExecuting = true);

    final TestCaseModel? primaryCase =
        (_challenge?.testCases.isNotEmpty == true)
            ? _challenge!.testCases.first
            : null;

    final String stdin = primaryCase?.input ?? '';
    final String expectedOutput = primaryCase?.expectedOutput ?? '';
    final int totalCases = _challenge?.testCases.length ?? 1;

    final ExecutionResultModel result = await CodeExecutionService.execute(
      code: _codeController.text,
      language: _selectedLanguage,
      stdin: stdin,
      expectedOutput: expectedOutput,
      totalTestCases: totalCases,
      apiBaseUrl: dotenv.env['API_BASE_URL'],
    );

    if (mounted) {
      setState(() => _isExecuting = false);
      PracticeConsoleSheet.show(
        context,
        result: result,
        testCases: _challenge?.testCases ?? const <TestCaseModel>[],
      );
    }
  }

  Future<void> _handleSubmitSolution() async {
    if (_isExecuting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExecuting = true);

    final TestCaseModel? primaryCase =
        (_challenge?.testCases.isNotEmpty == true)
            ? _challenge!.testCases.first
            : null;

    final String stdin = primaryCase?.input ?? '';
    final String expectedOutput = primaryCase?.expectedOutput ?? '';
    final int totalCases = _challenge?.testCases.length ?? 1;

    final ExecutionResultModel result = await CodeExecutionService.execute(
      code: _codeController.text,
      language: _selectedLanguage,
      stdin: stdin,
      expectedOutput: expectedOutput,
      totalTestCases: totalCases,
      apiBaseUrl: dotenv.env['API_BASE_URL'],
    );

    if (!mounted) return;
    setState(() => _isExecuting = false);

    if (!result.isSuccess) {
      PracticeConsoleSheet.show(
        context,
        result: result,
        testCases: _challenge?.testCases ?? const <TestCaseModel>[],
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

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
        onBackToModule: () {
          Navigator.of(context).pop();
          context.pop();
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
            context.pop();
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
      );
    }

    final PracticeExerciseModel? ch = _challenge;
    if (ch == null) {
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
          child: Text(
            'Challenge not found',
            style: TextStyle(color: textSecondary),
          ),
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
                  child: Text(display,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),

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
          // Segmented Sub-Nav: [ Description ] <-> [ Code Editor ] <-> [ Submissions ]
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
                    : SubmissionsHistoryView(
                        submissions: _submissions,
                        isLoading: _isLoadingSubmissions,
                        onRefresh: _loadSubmissions,
                        onRestoreCode: _restoreHistoricalCode,
                      )),
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
        ],
      ),
    );
  }
}
