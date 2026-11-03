import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../common_widgets/language_icon.dart';
import '../../../constants/app_colors.dart';
import '../data/assessment_repository.dart';
import '../data/code_execution_service.dart';
import '../domain/assessment_report_args.dart';
import '../domain/practice_exercise_model.dart';
import '../data/supabase_assessment_repository.dart';
import '../domain/assessment_model.dart';
import 'widgets/markdown_content_view.dart';
import 'widgets/practice_code_editor.dart';
import 'widgets/report_assessment_sheet.dart';
import 'widgets/submissions_history_view.dart';
import '../domain/submission_history_model.dart';

class AssessmentAttemptScreen extends StatefulWidget {
  const AssessmentAttemptScreen({
    super.key,
    required this.assessmentId,
    this.assessmentRepository = const SupabaseAssessmentRepository(),
  });

  final String assessmentId;
  final AssessmentRepository assessmentRepository;

  @override
  State<AssessmentAttemptScreen> createState() =>
      _AssessmentAttemptScreenState();
}

class _AssessmentAttemptScreenState extends State<AssessmentAttemptScreen> {
  AssessmentModel? _assessment;
  bool _isLoading = true;

  int _activeChallengeIdx = 0;
  final Map<String, String> _userCodes = <String, String>{};
  final TextEditingController _codeController = TextEditingController();

  // Active view: 'problem', 'editor', 'console', 'history'
  String _activeTab = 'problem';

  // Past submissions per challenge (History tab)
  final Map<String, List<SubmissionHistoryModel>> _historyByChallenge =
      <String, List<SubmissionHistoryModel>>{};
  bool _isLoadingHistory = false;

  // Timer state
  Timer? _countdownTimer;
  int _secsLeft = 3600;
  int _totalDurationSecs = 3600;

  // Test execution states
  bool _isRunningTests = false;
  final Map<String, List<Map<String, dynamic>>> _testResultsByChallenge =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, bool> _challengePassedMap = <String, bool>{};

  bool _isSubmitting = false;
  String _submitStage = '';

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadAssessment() async {
    final AssessmentModel? asm =
        await widget.assessmentRepository.getAssessmentById(widget.assessmentId);

    if (!mounted) return;

    if (asm == null) {
      setState(() => _isLoading = false);
      AppToast.showError(context, 'Unable to load assessment details');
      return;
    }

    // Gate: the assessment must be unlocked (or owned) before an attempt can start.
    final String uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final Set<String> unlockedIds =
        await widget.assessmentRepository.getUnlockedAssessmentIds(uid);
    if (!mounted) return;
    final bool canAttempt =
        unlockedIds.contains(asm.id) || (uid.isNotEmpty && asm.mentorId == uid);
    if (!canAttempt) {
      setState(() => _isLoading = false);
      AppToast.showError(context, 'Unlock this assessment to start your attempt');
      if (context.canPop()) context.pop();
      return;
    }

    final int duration = (asm.durationMins > 0 ? asm.durationMins : 60) * 60;

    // Seed code per challenge
    for (final AssessmentChallengeModel ch in asm.challenges) {
      _userCodes[ch.id] = ch.starterCode.isNotEmpty
          ? ch.starterCode
          : '// Implement your solution here\n';
    }

    setState(() {
      _assessment = asm;
      _isLoading = false;
      _secsLeft = duration;
      _totalDurationSecs = duration;
      if (asm.challenges.isNotEmpty) {
        _setEditorText(_userCodes[asm.challenges.first.id] ?? '');
      }
    });

    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_secsLeft <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _secsLeft = 0);
          AppToast.showInfo(context, 'Time expired! Auto-submitting assessment.');
          _handleConfirmSubmit();
        }
      } else {
        if (mounted) {
          setState(() => _secsLeft--);
        }
      }
    });
  }

  String _formatTime(int totalSecs) {
    final int m = totalSecs ~/ 60;
    final int s = totalSecs % 60;
    final String mm = m.toString().padLeft(2, '0');
    final String ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Color _getTimerColor() {
    if (_secsLeft < 300) return const Color(0xFFEF4444);
    if (_secsLeft < 600) return const Color(0xFFF59E0B);
    return AppColors.primary;
  }

  AssessmentChallengeModel? get _currentChallenge {
    if (_assessment == null || _assessment!.challenges.isEmpty) return null;
    if (_activeChallengeIdx >= _assessment!.challenges.length) return null;
    return _assessment!.challenges[_activeChallengeIdx];
  }

  Future<void> _loadHistory({bool force = false}) async {
    final AssessmentChallengeModel? ch = _currentChallenge;
    final String userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (ch == null || userId.isEmpty) return;
    if (!force && _historyByChallenge.containsKey(ch.id)) return;

    setState(() => _isLoadingHistory = true);
    final List<SubmissionHistoryModel> list =
        await widget.assessmentRepository.getChallengeSubmissions(
      userId: userId,
      challengeId: ch.id,
    );
    if (!mounted) return;
    setState(() {
      _historyByChallenge[ch.id] = list;
      _isLoadingHistory = false;
    });
  }

  void _restoreHistoricalCode(String code, String language) {
    final AssessmentChallengeModel? ch = _currentChallenge;
    if (ch == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _setEditorText(code);
      _userCodes[ch.id] = code;
      _activeTab = 'editor';
    });
    AppToast.showSuccess(context, 'Code restored to editor');
  }

  /// Replaces the editor content with a valid cursor position. Assigning
  /// `controller.text` leaves the selection at -1, which later breaks the
  /// editor's auto-indent logic.
  void _setEditorText(String text) {
    _codeController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _selectChallenge(int idx) {
    if (_assessment == null ||
        idx < 0 ||
        idx >= _assessment!.challenges.length ||
        idx == _activeChallengeIdx) {
      return;
    }
    HapticFeedback.selectionClick();

    // Close the keyboard so the text input connection is not mid-edit while the
    // editor content is swapped for the next problem.
    FocusManager.instance.primaryFocus?.unfocus();

    // Save current code
    final AssessmentChallengeModel? curr = _currentChallenge;
    if (curr != null) {
      _userCodes[curr.id] = _codeController.text;
    }

    final AssessmentChallengeModel next = _assessment!.challenges[idx];
    setState(() {
      _activeChallengeIdx = idx;
      _setEditorText(_userCodes[next.id] ?? next.starterCode);
    });
    if (_activeTab == 'history') _loadHistory();
  }

  void _handleCodeChanged(String newCode) {
    final AssessmentChallengeModel? curr = _currentChallenge;
    if (curr != null) {
      _userCodes[curr.id] = newCode;
    }
  }

  /// Runs a challenge's test cases in the real sandbox (same service the module
  /// challenge screen uses).
  Future<ExecutionResultModel> _executeChallenge(
    AssessmentChallengeModel ch,
    String code,
  ) {
    final List<TestCaseModel> cases = ch.testCases.asMap().entries.map(
      (MapEntry<int, Map<String, dynamic>> e) {
        final Map<String, dynamic> tc = e.value;
        return TestCaseModel(
          input: (tc['input'] ?? tc['test_input'] ?? '').toString(),
          expectedOutput:
              (tc['output'] ?? tc['expected'] ?? tc['test_expected_output'] ?? '')
                  .toString(),
          orderIndex: e.key + 1,
        );
      },
    ).toList();

    return CodeExecutionService.execute(
      code: code,
      language: ch.language,
      testCases: cases,
      apiBaseUrl: dotenv.env['WEB_API_URL'] ?? dotenv.env['API_BASE_URL'],
    );
  }

  /// One short line explaining why a run failed (the first error message),
  /// so a failing score can be checked against the real compiler output.
  String? _errorSummary(ExecutionResultModel r) {
    if (r.isSuccess) return null;
    final List<String> sources = <String>[
      if (r.caseResults.isNotEmpty) r.caseResults.first.error ?? '',
      if (r.caseResults.isNotEmpty) r.caseResults.first.actual,
      r.rawLog,
    ];
    for (final String source in sources) {
      final List<String> lines = source
          .split('\n')
          .map((String l) => l.trim())
          .where((String l) =>
              l.isNotEmpty && !l.startsWith('>') && !l.startsWith('Status:'))
          .toList();
      if (lines.isEmpty) continue;
      final String line = lines.firstWhere(
        (String l) => l.toLowerCase().contains('error'),
        orElse: () => lines.first,
      );
      return line.length > 180 ? '${line.substring(0, 180)}...' : line;
    }
    return null;
  }

  String _verdictFor(ExecutionResultModel r) {
    if (r.isSuccess) return 'Accepted';
    // The runner itself failed (network, unsupported language): that is not a
    // verdict on the learner's code.
    if (r.errorTitle == 'Execution Error' ||
        r.errorTitle == 'Unsupported Language') {
      return 'Could Not Run';
    }
    if (r.isCompileError) return 'Compilation Error';
    if (r.isRuntimeError) return 'Runtime Error';
    return 'Wrong Answer';
  }

  Future<void> _handleRunSampleTests() async {
    final AssessmentChallengeModel? ch = _currentChallenge;
    if (ch == null || _isRunningTests) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isRunningTests = true;
      _activeTab = 'console';
    });

    final ExecutionResultModel result =
        await _executeChallenge(ch, _codeController.text);

    final List<Map<String, dynamic>> results = result.caseResults
        .map((TestCaseResultModel c) => <String, dynamic>{
              'input': c.input,
              'expected': c.expected,
              'actual': c.error ?? c.actual,
              'passed': c.passed,
              'timeMs': int.tryParse(
                      (c.runtime ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0,
            })
        .toList();
    if (results.isEmpty) {
      results.add(<String, dynamic>{
        'input': '-',
        'expected': '-',
        'actual': result.errorTitle ?? result.rawLog,
        'passed': result.isSuccess,
        'timeMs': 0,
      });
    }

    if (!mounted) return;

    setState(() {
      _isRunningTests = false;
      _testResultsByChallenge[ch.id] = results;
      _challengePassedMap[ch.id] = result.isSuccess;
    });

    if (result.isSuccess) {
      HapticFeedback.mediumImpact();
      AppToast.showSuccess(context, 'All sample tests passed!');
    } else {
      AppToast.showInfo(context, 'Some tests failed. Check console.');
    }
  }

  Future<void> _showExitConfirmation() async {
    HapticFeedback.selectionClick();
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkSurfaceCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                size: 24.0,
              ),
              const SizedBox(width: 8.0),
              Text(
                'Exit Exam Early?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Exiting now will pause your examination and your benchmark score will not be submitted.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Continue Exam',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                elevation: 0,
              ),
              child: Text(
                'Exit Exam',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      context.pop();
    }
  }

  Future<void> _showSubmitConfirmation() async {
    HapticFeedback.selectionClick();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final int totalChallenges = _assessment?.challenges.length ?? 1;
    final int completedCount =
        _challengePassedMap.values.where((bool v) => v).length;

    final bool? shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(22.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.primary,
                      size: 24.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Submit Final Assessment?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17.0,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Text(
                  'Once submitted, your solutions will be evaluated by the benchmark engine to generate your readiness scorecard.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16.0),

                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Completed',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.0,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          Text(
                            '$completedCount of $totalChallenges Tasks',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            'Time Left',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.0,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          Text(
                            _formatTime(_secsLeft),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: _getTimerColor(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),

                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Text(
                          'Back to Exam',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: isDark
                              ? AppColors.onPrimaryDark
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.send_rounded, size: 16.0),
                            const SizedBox(width: 6.0),
                            Text(
                              'Confirm Submit',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSubmit == true) {
      await _handleConfirmSubmit();
    }
  }

  Future<void> _handleConfirmSubmit() async {
    if (_isSubmitting) return;

    final AssessmentModel? asm = _assessment;
    if (asm == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    final String userId = user?.id ?? '';

    setState(() => _isSubmitting = true);
    _countdownTimer?.cancel();

    // Save current code
    final AssessmentChallengeModel? curr = _currentChallenge;
    if (curr != null) {
      _userCodes[curr.id] = _codeController.text;
    }

    // Evaluate every challenge for real, one by one (web parity: /api/execute per challenge)
    final List<Map<String, dynamic>> submissions = <Map<String, dynamic>>[];
    final List<AssessmentChallengeResult> results = <AssessmentChallengeResult>[];
    int totalPassed = 0;

    for (int i = 0; i < asm.challenges.length; i++) {
      final AssessmentChallengeModel ch = asm.challenges[i];
      final String code = _userCodes[ch.id] ?? ch.starterCode;
      if (mounted) {
        setState(() => _submitStage = 'Evaluating ${i + 1} of ${asm.challenges.length}…');
      }

      bool passed = false;
      String verdict = 'Wrong Answer';
      int passedCases = 0;
      int totalCases = 0;
      String? detail;

      final bool untouched = code.trim().isEmpty || code.trim() == ch.starterCode.trim();
      if (untouched) {
        verdict = code.trim().isEmpty ? 'No Submission' : 'Unchanged Starter Code';
      } else {
        final ExecutionResultModel r = await _executeChallenge(ch, code);
        passed = r.isSuccess;
        verdict = _verdictFor(r);
        passedCases = r.passedTestCases;
        totalCases = r.totalTestCases;
        detail = _errorSummary(r);
      }

      if (passed) totalPassed++;

      submissions.add(<String, dynamic>{
        'challenge_id': ch.id,
        'code': code,
        'language': ch.language,
        'passed': passed,
        'verdict': verdict,
      });
      results.add(AssessmentChallengeResult(
        challenge: ch,
        code: code,
        language: ch.language,
        passed: passed,
        verdict: verdict,
        passedCases: passedCases,
        totalCases: totalCases,
        detail: detail,
      ));
    }

    final int total = asm.challenges.isNotEmpty ? asm.challenges.length : 1;
    final int finalScore = ((totalPassed / total) * 100).round();
    final int timeSpentSecs = _totalDurationSecs - _secsLeft;

    if (mounted) setState(() => _submitStage = 'Saving your submission…');

    Map<String, String> submissionIds = <String, String>{};
    if (userId.isNotEmpty) {
      submissionIds = await widget.assessmentRepository.submitAssessmentAttempt(
            assessmentId: asm.id,
            userId: userId,
            score: finalScore,
            timeSpentSecs: timeSpentSecs > 0 ? timeSpentSecs : 1,
            challengeSubmissions: submissions,
          ) ??
          <String, String>{};
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _submitStage = '';
    });

    final AssessmentReportArgs args = AssessmentReportArgs(
      assessment: asm,
      score: finalScore,
      timeSpentSecs: timeSpentSecs,
      results: results
          .map((AssessmentChallengeResult r) => AssessmentChallengeResult(
                challenge: r.challenge,
                code: r.code,
                language: r.language,
                passed: r.passed,
                verdict: r.verdict,
                passedCases: r.passedCases,
                totalCases: r.totalCases,
                submissionId: submissionIds[r.challenge.id],
                detail: r.detail,
              ))
          .toList(),
    );

    context.pushReplacement('/assessments/${asm.id}/report', extra: args);
  }

  Future<void> _handleReport() async {
    final AssessmentModel? asm = _assessment;
    if (asm == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppToast.showError(context, 'Please log in to submit a report');
      return;
    }

    final bool? reported = await ReportAssessmentSheet.show(
      context,
      assessmentId: asm.id,
      assessmentTitle: asm.title,
      assessmentRepository: widget.assessmentRepository,
      userId: user.id,
    );

    if (reported == true && mounted) {
      AppToast.showSuccess(context, 'Report submitted for review');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final AssessmentModel? asm = _assessment;
    final AssessmentChallengeModel? ch = _currentChallenge;

    if (asm == null || ch == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Text(
            'Assessment not found.',
            style: GoogleFonts.plusJakartaSans(color: textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // ── Top Header Bar ──
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard
                    : AppColors.lightSurfaceCard,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Exit exam button
                  GestureDetector(
                    onTap: _showExitConfirmation,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 18.0,
                          color: textPrimary,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          'Exit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Language & Title
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          LanguageIcon(
                            language: asm.stack.isNotEmpty
                                ? asm.stack.first
                                : 'javascript',
                            size: 16.0,
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Text(
                              asm.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right: Flag + Timer
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed: _handleReport,
                        icon: const Icon(Icons.flag_outlined, size: 18.0),
                        color: textSecondary.withValues(alpha: 0.6),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: _getTimerColor().withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: _getTimerColor().withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.timer_outlined,
                              size: 13.0,
                              color: _getTimerColor(),
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              _formatTime(_secsLeft),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w800,
                                color: _getTimerColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Problem Switcher Strip (P1, P2, ...) ──
            Container(
              height: 42.0,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: asm.challenges.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 8.0),
                itemBuilder: (context, index) {
                  final AssessmentChallengeModel c = asm.challenges[index];
                  final bool isSelected = index == _activeChallengeIdx;
                  final bool isPassed = _challengePassedMap[c.id] == true;

                  return Center(
                    child: GestureDetector(
                      onTap: () => _selectChallenge(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 5.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkSurfaceCard
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : borderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (isPassed) ...<Widget>[
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12.0,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF3ECF8E),
                              ),
                              const SizedBox(width: 4.0),
                            ],
                            Text(
                              'P${index + 1}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? (isDark
                                        ? AppColors.onPrimaryDark
                                        : Colors.white)
                                    : textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Segmented View Switcher: Problem | Editor | Console ──
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard
                    : AppColors.lightSurfaceCard,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: <Widget>[
                  _buildSegmentButton(
                    id: 'problem',
                    label: 'Problem',
                    icon: Icons.description_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8.0),
                  _buildSegmentButton(
                    id: 'editor',
                    label: 'Editor',
                    icon: Icons.code_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8.0),
                  _buildSegmentButton(
                    id: 'console',
                    label: 'Console',
                    icon: Icons.terminal_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8.0),
                  _buildSegmentButton(
                    id: 'history',
                    label: (_historyByChallenge[ch.id]?.isNotEmpty ?? false)
                        ? 'History (${_historyByChallenge[ch.id]!.length})'
                        : 'History',
                    icon: Icons.history_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // ── Main Body Content ──
            Expanded(
              child: IndexedStack(
                index: _activeTab == 'problem'
                    ? 0
                    : (_activeTab == 'editor'
                        ? 1
                        : (_activeTab == 'console' ? 2 : 3)),
                children: <Widget>[
                  // Tab 0: Problem View
                  _buildProblemView(ch, isDark, textPrimary, textSecondary),

                  // Tab 1: Code Editor View
                  _buildEditorView(ch, isDark),

                  // Tab 2: Console / Test Cases View
                  _buildConsoleView(ch, isDark, textPrimary, textSecondary),

                  // Tab 3: Past submissions for this challenge
                  SubmissionsHistoryView(
                    submissions:
                        _historyByChallenge[ch.id] ?? const <SubmissionHistoryModel>[],
                    isLoading: _isLoadingHistory,
                    onRefresh: () => _loadHistory(force: true),
                    onRestoreCode: _restoreHistoricalCode,
                  ),
                ],
              ),
            ),

            // ── Bottom Action Bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard
                    : AppColors.lightSurfaceCard,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: <Widget>[
                    // Run sample tests
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isRunningTests ? null : _handleRunSampleTests,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          side: BorderSide(color: borderColor),
                        ),
                        child: _isRunningTests
                            ? const SizedBox(
                                width: 16.0,
                                height: 16.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 17.0,
                                    color: Color(0xFF3ECF8E),
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    'Run Tests',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 10.0),

                    // Submit Exam
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isSubmitting ? null : _showSubmitConfirmation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: isDark
                              ? AppColors.onPrimaryDark
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const SizedBox(
                                    width: 16.0,
                                    height: 16.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  if (_submitStage.isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 8.0),
                                    Flexible(
                                      child: Text(
                                        _submitStage,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(Icons.send_rounded, size: 15.0),
                                  const SizedBox(width: 5.0),
                                  Text(
                                    'Submit Exam',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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

  Widget _buildSegmentButton({
    required String id,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final bool isSelected = _activeTab == id;
    final Color activeColor = AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTab = id);
          if (id == 'history') _loadHistory();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 14.0,
                color: isSelected
                    ? activeColor
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 4.0),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? activeColor
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProblemView(
    AssessmentChallengeModel ch,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Task Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  'TASK ${_activeChallengeIdx + 1}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Title
          Text(
            ch.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12.0),

          // Problem Statement Markdown
          MarkdownContentView(
            markdown: ch.problemStatement.isNotEmpty
                ? ch.problemStatement
                : 'No problem statement provided.',
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            cardBg: isDark
                ? AppColors.darkSurfaceCard
                : AppColors.lightSurfaceCard,
            borderColor: borderColor,
          ),
          const SizedBox(height: 20.0),

          // Sample Test Cases
          if (ch.testCases.isNotEmpty) ...<Widget>[
            Text(
              'SAMPLE ASSERTIONS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8.0),
            ...ch.testCases.asMap().entries.map((entry) {
              final int idx = entry.key;
              final Map<String, dynamic> tc = entry.value;
              final String input =
                  tc['input']?.toString() ?? tc['test_input']?.toString() ?? '';
              final String output = tc['output']?.toString() ??
                  tc['expected']?.toString() ??
                  tc['test_expected_output']?.toString() ??
                  '';

              return Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceCard
                      : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sample ${idx + 1}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: <Widget>[
                        Text(
                          'Input: ',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.0,
                            color: textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            input,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Row(
                      children: <Widget>[
                        Text(
                          'Expected: ',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.0,
                            color: textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            output,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3ECF8E),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildEditorView(AssessmentChallengeModel ch, bool isDark) {
    return Column(
      children: <Widget>[
        Expanded(
          child: PracticeCodeEditor(
            // A fresh editor state per problem avoids carrying over stale
            // focus / scroll / selection from the previous one.
            key: ValueKey<String>(ch.id),
            controller: _codeController,
            language: ch.language,
            onChanged: _handleCodeChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleView(
    AssessmentChallengeModel ch,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final List<Map<String, dynamic>>? results = _testResultsByChallenge[ch.id];

    if (results == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.terminal_rounded,
                size: 40.0,
                color: textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10.0),
              Text(
                'No Test Results Yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Tap "Run Tests" below to evaluate your solution against sample assertions.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool allPassed = results.every((r) => r['passed'] == true);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Status banner
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: allPassed
                  ? const Color(0xFF3ECF8E).withValues(alpha: 0.12)
                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: allPassed
                    ? const Color(0xFF3ECF8E).withValues(alpha: 0.3)
                    : const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  allPassed
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: allPassed
                      ? const Color(0xFF3ECF8E)
                      : const Color(0xFFEF4444),
                  size: 20.0,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    allPassed
                        ? 'All sample test cases passed successfully!'
                        : 'Some assertions failed. Verify your logic and retry.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: allPassed
                          ? const Color(0xFF3ECF8E)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // Assertion cards
          ...results.asMap().entries.map((entry) {
            final int idx = entry.key;
            final Map<String, dynamic> r = entry.value;
            final bool passed = r['passed'] == true;
            final Color itemColor = passed
                ? const Color(0xFF3ECF8E)
                : const Color(0xFFEF4444);

            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard
                    : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Sample Assertion ${idx + 1}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          passed ? 'PASSED (${r['timeMs']}ms)' : 'FAILED',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: itemColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Input:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.0,
                      color: textSecondary,
                    ),
                  ),
                  Text(
                    r['input']?.toString() ?? '',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Expected Output:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.0,
                      color: textSecondary,
                    ),
                  ),
                  Text(
                    r['expected']?.toString() ?? '',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      color: const Color(0xFF3ECF8E),
                    ),
                  ),
                  if (!passed) ...<Widget>[
                    const SizedBox(height: 4.0),
                    Text(
                      'Actual Output:',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.0,
                        color: textSecondary,
                      ),
                    ),
                    Text(
                      r['actual']?.toString() ?? '',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.0,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
