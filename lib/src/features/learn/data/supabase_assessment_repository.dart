import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/network/api_client.dart';
import '../domain/assessment_model.dart';
import '../domain/submission_history_model.dart';
import 'assessment_repository.dart';

class SupabaseAssessmentRepository implements AssessmentRepository {
  const SupabaseAssessmentRepository({this.client});

  final supabase.SupabaseClient? client;

  supabase.SupabaseClient get _supabase =>
      client ?? supabase.Supabase.instance.client;

  static final ValueNotifier<Set<String>> bookmarkedAssessmentIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});

  @override
  Future<List<AssessmentModel>> getPublishedAssessments(String userId) async {
    try {
      // 1. Fetch published assessments with mentor profile and challenges
      final dynamic rawData = await _supabase
          .from('assessments')
          .select('''
            id,
            title,
            description,
            stack,
            difficulty,
            duration_mins,
            passing_score,
            max_attempts,
            status,
            price_coins,
            mentor_id,
            profiles:mentor_id(user_first_name, user_last_name, user_avatar_url),
            challenges:assessment_challenges(id, title, problem_statement, starter_code, language, difficulty, test_cases)
          ''')
          .eq('status', 'published')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> dbAssessments =
          (rawData as List<dynamic>).cast<Map<String, dynamic>>();

      // 2. Fetch user's saved assessment library
      final Set<String> librarySet = <String>{};
      if (userId.isNotEmpty) {
        try {
          final dynamic libData = await _supabase
              .from('user_assessment_library')
              .select('assessment_id')
              .eq('user_id', userId);

          if (libData is List) {
            for (final dynamic item in libData) {
              if (item is Map<String, dynamic> && item['assessment_id'] != null) {
                librarySet.add(item['assessment_id'].toString());
              }
            }
          }
          bookmarkedAssessmentIdsNotifier.value = librarySet;
        } catch (_) {}
      }

      final Set<String> unlocked =
          userId.isNotEmpty ? await getUnlockedAssessmentIds(userId) : <String>{};

      return dbAssessments.map((Map<String, dynamic> a) {
        final String id = a['id']?.toString() ?? '';
        final bool isSaved = librarySet.contains(id);
        final bool isOwner = userId.isNotEmpty && a['mentor_id']?.toString() == userId;
        return AssessmentModel.fromJson(a, isInLibrary: isSaved)
            .copyWith(isUnlocked: isOwner || unlocked.contains(id));
      }).toList();
    } catch (e) {
      debugPrint('Error fetching published assessments from Supabase: $e');
      return <AssessmentModel>[];
    }
  }

  @override
  Future<AssessmentModel?> getAssessmentById(String assessmentId) async {
    try {
      if (assessmentId.isEmpty) return null;

      final dynamic raw = await _supabase
          .from('assessments')
          .select('''
            id,
            title,
            description,
            stack,
            difficulty,
            duration_mins,
            passing_score,
            max_attempts,
            status,
            mentor_id,
            profiles:mentor_id(user_first_name, user_last_name, user_avatar_url),
            challenges:assessment_challenges(id, title, problem_statement, starter_code, language, difficulty, test_cases)
          ''')
          .eq('id', assessmentId)
          .maybeSingle();

      if (raw == null || raw is! Map<String, dynamic>) {
        return null;
      }

      final List<AssessmentChallengeModel> challenges =
          await getAssessmentChallenges(assessmentId);

      final AssessmentModel asm = AssessmentModel.fromJson(raw);
      if (challenges.isNotEmpty) {
        return asm.copyWith(
          challenges: challenges,
          challengeCount: challenges.length,
        );
      }
      return asm;
    } catch (e) {
      debugPrint('Error fetching assessment by id: $e');
      return null;
    }
  }

  @override
  Future<List<AssessmentChallengeModel>> getAssessmentChallenges(
      String assessmentId) async {
    try {
      final dynamic rawChallenges = await _supabase
          .from('assessment_challenges')
          .select('*')
          .eq('assessment_id', assessmentId)
          .order('order_index', ascending: true);

      final List<Map<String, dynamic>> chList =
          (rawChallenges as List<dynamic>).cast<Map<String, dynamic>>();

      return chList
          .map((Map<String, dynamic> c) =>
              AssessmentChallengeModel.fromJson(c))
          .toList();
    } catch (e) {
      debugPrint('Error fetching assessment challenges: $e');
      return <AssessmentChallengeModel>[];
    }
  }

  @override
  Future<bool> toggleAssessmentBookmark(
    String userId,
    String assessmentId,
    bool isBookmarked,
  ) async {
    if (userId.isEmpty || assessmentId.isEmpty) return false;

    try {
      if (isBookmarked) {
        await _supabase.from('user_assessment_library').upsert(
          <String, dynamic>{
            'user_id': userId,
            'assessment_id': assessmentId,
            'status': 'enrolled',
            'saved_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,assessment_id',
        );
        final Set<String> updated =
            Set<String>.from(bookmarkedAssessmentIdsNotifier.value)
              ..add(assessmentId);
        bookmarkedAssessmentIdsNotifier.value = updated;
      } else {
        await _supabase
            .from('user_assessment_library')
            .delete()
            .eq('user_id', userId)
            .eq('assessment_id', assessmentId);
        final Set<String> updated =
            Set<String>.from(bookmarkedAssessmentIdsNotifier.value)
              ..remove(assessmentId);
        bookmarkedAssessmentIdsNotifier.value = updated;
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling assessment bookmark: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getActiveAssessmentReport({
    required String assessmentId,
    required String userId,
  }) async {
    try {
      if (assessmentId.isEmpty || userId.isEmpty) return null;

      final dynamic res = await _supabase
          .from('assessment_reports')
          .select('report_id, report_reason, report_details')
          .eq('assessment_id', assessmentId)
          .eq('user_id', userId)
          .inFilter('report_status', <String>['pending', 'investigating'])
          .limit(1);

      if (res is List && res.isNotEmpty) {
        final dynamic first = res.first;
        if (first is Map<String, dynamic>) {
          return first;
        }
      }
      return null;
    } catch (e) {
      debugPrint('getActiveAssessmentReport error: $e');
      return null;
    }
  }

  @override
  Future<bool> submitAssessmentReport({
    required String assessmentId,
    required String userId,
    required String reason,
    required String details,
  }) async {
    if (userId.isEmpty || assessmentId.isEmpty || details.trim().isEmpty) {
      return false;
    }

    try {
      // Check if user already has an active pending or investigating report
      final dynamic existing = await _supabase
          .from('assessment_reports')
          .select('report_id')
          .eq('assessment_id', assessmentId)
          .eq('user_id', userId)
          .inFilter('report_status', <String>['pending', 'investigating'])
          .limit(1);

      if (existing is List && existing.isNotEmpty) {
        final dynamic first = existing.first;
        if (first is Map<String, dynamic> && first['report_id'] != null) {
          // Update existing report
          final String reportId = first['report_id'].toString();
          await _supabase.from('assessment_reports').update(<String, dynamic>{
            'report_reason': reason,
            'report_details': details.trim(),
            'report_created_at': DateTime.now().toIso8601String(),
          }).eq('report_id', reportId);
          return true;
        }
      }

      // Insert new report
      await _supabase.from('assessment_reports').insert(<String, dynamic>{
        'assessment_id': assessmentId,
        'user_id': userId,
        'report_reason': reason,
        'report_details': details.trim(),
        'report_status': 'pending',
        'report_created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error submitting assessment report: $e');
      return false;
    }
  }

  @override
  Future<Map<String, String>?> submitAssessmentAttempt({
    required String assessmentId,
    required String userId,
    required int score,
    required int timeSpentSecs,
    required List<Map<String, dynamic>> challengeSubmissions,
  }) async {
    if (assessmentId.isEmpty || userId.isEmpty) return null;

    final Map<String, String> submissionIds = <String, String>{};

    try {
      // 1. Fetch current best score from library if exists
      int bestScore = score;
      final dynamic existingLib = await _supabase
          .from('user_assessment_library')
          .select('best_score')
          .eq('assessment_id', assessmentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLib is Map<String, dynamic> &&
          existingLib['best_score'] != null) {
        final int prev = existingLib['best_score'] as int? ?? 0;
        if (prev > bestScore) {
          bestScore = prev;
        }
      }

      // 2. Update/upsert user_assessment_library
      await _supabase.from('user_assessment_library').upsert(
        <String, dynamic>{
          'user_id': userId,
          'assessment_id': assessmentId,
          'status': 'completed',
          'best_score': bestScore,
          'saved_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,assessment_id',
      );

      // 3. Insert submissions for each challenge if provided
      for (final Map<String, dynamic> item in challengeSubmissions) {
        try {
          final String? challengeId = item['challenge_id']?.toString();
          final String code = item['code']?.toString() ?? '';
          final String lang = item['language']?.toString() ?? 'javascript';
          final bool passed = item['passed'] == true;

          if (challengeId == null || challengeId.isEmpty) continue;

          final String verdictText = item['verdict']?.toString() ??
              (passed ? 'Accepted' : 'Wrong Answer');

          // Live schema columns (same as the module submit flow and web /api/submit)
          final dynamic inserted = await _supabase.from('submissions').insert(<String, dynamic>{
            'user_id': userId,
            'item_id': challengeId,
            'sub_code': code,
            'sub_language': lang.toLowerCase(),
            'sub_status': passed ? 'accepted' : 'wrong_answer',
            'sub_verdict': <String, dynamic>{'verdict': verdictText},
            'sub_submitted_at': DateTime.now().toUtc().toIso8601String(),
          }).select('sub_id').maybeSingle();

          final String subId =
              inserted is Map ? (inserted['sub_id']?.toString() ?? '') : '';
          if (subId.isNotEmpty) {
            submissionIds[challengeId] = subId;
            _triggerAcfEvaluation(subId);
          }
        } catch (subErr) {
          debugPrint('Error inserting challenge submission log: $subErr');
        }
      }

      // 4. Record the attempt for CRA scoring. The snapshot lists each problem
      // with its test result and submission id (same shape as the web), which is
      // what the readiness calculation reads. It needs the submission ids, so it
      // is written after the submissions.
      try {
        final int passingScore = await _getPassingScore(assessmentId);
        final DateTime submittedAt = DateTime.now().toUtc();
        final List<Map<String, dynamic>> problems = <Map<String, dynamic>>[
          for (final Map<String, dynamic> item in challengeSubmissions)
            <String, dynamic>{
              'id': item['challenge_id']?.toString() ?? '',
              'language': item['language']?.toString() ?? 'javascript',
              'passed': item['passed'] == true,
              'submissionId': submissionIds[item['challenge_id']?.toString()],
            },
        ];
        await _supabase.from('user_assessment_attempts').insert(<String, dynamic>{
          'user_id': userId,
          'assessment_id': assessmentId,
          'status': 'completed',
          'score': score,
          'passing_score': passingScore,
          'is_passed': score >= passingScore,
          'duration_seconds': timeSpentSecs,
          'snapshot': <String, dynamic>{
            'assessmentId': assessmentId,
            'passingScore': passingScore,
            'overallScore': score,
            'isPassed': score >= passingScore,
            'passedCount': problems.where((Map<String, dynamic> p) => p['passed'] == true).length,
            'totalCount': problems.length,
            'submittedAt': submittedAt.toIso8601String(),
            'challenges': problems,
          },
          'submitted_at': submittedAt.toIso8601String(),
        });
      } catch (attErr) {
        debugPrint('Non-critical attempt insert error: $attErr');
      }

      return submissionIds;
    } catch (e) {
      debugPrint('Error submitting assessment attempt: $e');
      return null;
    }
  }

  /// Adds `cra_problems` to each attempt: the snapshot's problems joined with the
  /// AI correctness and efficiency ratings of their submissions (web: craData.ts).
  /// A problem whose submission has no AI review yet gets null ratings, which the
  /// calculation treats as pending. The raw snapshot is dropped afterwards.
  Future<void> _attachCraProblems(List<Map<String, dynamic>> attempts) async {
    List<dynamic> challengesOf(Map<String, dynamic> a) {
      final dynamic snap = a['snapshot'];
      final dynamic c = snap is Map ? snap['challenges'] : null;
      return c is List ? c : const <dynamic>[];
    }

    final Set<String> ids = <String>{
      for (final Map<String, dynamic> a in attempts)
        for (final dynamic c in challengesOf(a))
          if (c is Map && (c['submissionId']?.toString() ?? '').isNotEmpty)
            c['submissionId'].toString(),
    };

    final Map<String, Map<String, dynamic>> ratings =
        <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      try {
        final dynamic rows = await _supabase
            .from('submissions')
            .select('sub_id, ai_audits(audit_findings)')
            .inFilter('sub_id', ids.toList());
        if (rows is List) {
          for (final dynamic r in rows) {
            if (r is! Map) continue;
            final dynamic audit = r['ai_audits'] is List
                ? ((r['ai_audits'] as List).isEmpty
                    ? null
                    : (r['ai_audits'] as List).first)
                : r['ai_audits'];
            final dynamic f = audit is Map ? audit['audit_findings'] : null;
            ratings[r['sub_id'].toString()] = <String, dynamic>{
              'correctness': f is Map ? f['correctness'] : null,
              'efficiency': f is Map ? f['efficiency'] : null,
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching AI ratings for readiness: $e');
      }
    }

    for (final Map<String, dynamic> a in attempts) {
      final List<dynamic> challenges = challengesOf(a);
      a.remove('snapshot');
      if (challenges.isEmpty) continue;
      a['cra_problems'] = <Map<String, dynamic>>[
        for (int i = 0; i < challenges.length; i++)
          if (challenges[i] is Map)
            () {
              final Map<dynamic, dynamic> c = challenges[i] as Map;
              final String subId = c['submissionId']?.toString() ?? '';
              final Map<String, dynamic>? rating =
                  subId.isEmpty ? null : ratings[subId];
              return <String, dynamic>{
                'id': c['id']?.toString() ?? '${a['id']}-$i',
                'hasSubmission': subId.isNotEmpty,
                'passedTests': c['passed'] == true,
                'correctness': rating?['correctness'],
                'efficiency': rating?['efficiency'],
                'topics': c['topics'] is List ? c['topics'] : const <dynamic>[],
              };
            }(),
      ];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserAssessmentAttempts(String userId) async {
    if (userId.isEmpty) return <Map<String, dynamic>>[];

    try {
      final dynamic attemptsData = await _supabase
          .from('user_assessment_attempts')
          .select('id, assessment_id, status, score, is_passed, submitted_at, snapshot')
          .eq('user_id', userId);

      final List<Map<String, dynamic>> attempts = attemptsData is List
          ? attemptsData.cast<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      await _attachCraProblems(attempts);

      // Web parity: assessments with no scored attempt row fall back to their
      // user_assessment_library best_score (merged per assessment).
      final Set<String> scored = attempts
          .where((Map<String, dynamic> a) => a['score'] is num)
          .map((Map<String, dynamic> a) => a['assessment_id']?.toString() ?? '')
          .toSet();

      final dynamic libData = await _supabase
          .from('user_assessment_library')
          .select('assessment_id, status, best_score')
          .eq('user_id', userId);

      if (libData is List) {
        for (final dynamic item in libData) {
          final Map<String, dynamic> m = item as Map<String, dynamic>;
          final String aId = m['assessment_id']?.toString() ?? '';
          if (aId.isEmpty || scored.contains(aId) || m['best_score'] is! num) continue;
          attempts.add(<String, dynamic>{
            'assessment_id': m['assessment_id'],
            'status': m['status'] ?? 'completed',
            'score': m['best_score'],
          });
        }
      }

      return attempts;
    } catch (e) {
      debugPrint('Error fetching user assessment attempts: $e');
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Future<Set<String>> getUnlockedAssessmentIds(String userId) async {
    final Set<String> ids = <String>{};
    if (userId.isEmpty) return ids;

    // 1. Paid unlocks (coin transactions)
    try {
      final dynamic txs = await _supabase
          .from('coin_transactions')
          .select('reference_id')
          .eq('user_id', userId)
          .eq('tx_type', 'assessment_unlock');
      if (txs is List) {
        for (final dynamic t in txs) {
          final String ref = (t as Map<String, dynamic>)['reference_id']?.toString() ?? '';
          if (ref.isNotEmpty) ids.add(ref);
        }
      }
    } catch (e) {
      debugPrint('Error fetching assessment unlock transactions: $e');
    }

    // 2. Already attempted (grandfathered)
    try {
      final dynamic attempts = await _supabase
          .from('user_assessment_attempts')
          .select('assessment_id')
          .eq('user_id', userId);
      if (attempts is List) {
        for (final dynamic a in attempts) {
          final String id = (a as Map<String, dynamic>)['assessment_id']?.toString() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      }
    } catch (_) {}

    // 3. Library rows that progressed past a plain save (a bookmark alone does not unlock)
    try {
      final dynamic lib = await _supabase
          .from('user_assessment_library')
          .select('assessment_id, status')
          .eq('user_id', userId)
          .inFilter('status', <String>['in_progress', 'completed']);
      if (lib is List) {
        for (final dynamic l in lib) {
          final String id = (l as Map<String, dynamic>)['assessment_id']?.toString() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      }
    } catch (_) {}

    return ids;
  }

  @override
  Future<int> getWalletBalance(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final Map<String, dynamic>? wallet = await _supabase
          .from('user_wallets')
          .select('balance_coins')
          .eq('user_id', userId)
          .maybeSingle();
      final dynamic coins = wallet?['balance_coins'];
      return coins is num ? coins.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<String?> unlockAssessment({
    required String userId,
    required AssessmentModel assessment,
  }) async {
    if (userId.isEmpty) return 'Please log in to unlock assessments';

    try {
      // Single write path: the database function charges the learner (custom price,
      // or the 49-coin platform fee), logs the transaction, pays the mentor and
      // records the library row. Clients cannot write wallets directly (RLS).
      await _supabase.rpc<dynamic>('process_assessment_purchase_coins', params: <String, dynamic>{
        'p_learner_id': userId,
        'p_assessment_id': assessment.id,
      });
      return null;
    } catch (e) {
      final String msg = e.toString();
      if (msg.contains('INSUFFICIENT_COINS')) {
        return 'Insufficient CodeCoins to unlock this assessment.';
      }
      debugPrint('Error unlocking assessment: $e');
      // Debug builds show the real database error so setup problems are obvious.
      if (kDebugMode) {
        final String raw = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
        return 'Unlock failed: ${raw.length > 220 ? '${raw.substring(0, 220)}...' : raw}';
      }
      return 'Could not unlock the assessment. Please try again.';
    }
  }

  @override
  Future<List<SubmissionHistoryModel>> getChallengeSubmissions({
    required String userId,
    required String challengeId,
  }) async {
    if (userId.isEmpty || challengeId.isEmpty) return <SubmissionHistoryModel>[];
    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await _supabase
            .from('submissions')
            .select('*, ai_audits(audit_findings)')
            .eq('user_id', userId)
            .eq('item_id', challengeId)
            .order('sub_submitted_at', ascending: false);
      } catch (_) {
        rows = await _supabase
            .from('submissions')
            .select('*')
            .eq('user_id', userId)
            .eq('item_id', challengeId)
            .order('sub_submitted_at', ascending: false);
      }
      return rows
          .map((Map<String, dynamic> r) => SubmissionHistoryModel.fromJson(r))
          .toList();
    } catch (e) {
      debugPrint('Error fetching challenge submissions: $e');
      return <SubmissionHistoryModel>[];
    }
  }

  Future<int> _getPassingScore(String assessmentId) async {
    try {
      final Map<String, dynamic>? row = await _supabase
          .from('assessments')
          .select('passing_score')
          .eq('id', assessmentId)
          .maybeSingle();
      final dynamic v = row?['passing_score'];
      return v is num ? v.toInt() : 70;
    } catch (_) {
      return 70;
    }
  }

  /// Fire-and-forget AI (ACF) review generation for a saved submission, same
  /// endpoint chain the module challenge flow uses (Go backend, then web fallback).
  void _triggerAcfEvaluation(String subId) {
    const ApiClient apiClient = ApiClient();
    unawaited(() async {
      try {
        final dynamic res = await apiClient.get(
          '/api/submissions/$subId/feedback',
          timeout: const Duration(seconds: 10),
        );
        if (res is Map &&
            (res.containsKey('acf_composite_score') ||
                res.containsKey('correctness'))) {
          return;
        }
      } catch (_) {}
      try {
        await apiClient.getWeb(
          '/api/submissions/$subId/feedback',
          timeout: const Duration(seconds: 30),
        );
      } catch (_) {}
    }());
  }
}
