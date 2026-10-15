import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../domain/assessment_model.dart';
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

      return dbAssessments.map((Map<String, dynamic> a) {
        final String id = a['id']?.toString() ?? '';
        final bool isSaved = librarySet.contains(id);
        return AssessmentModel.fromJson(a, isInLibrary: isSaved);
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
  Future<bool> submitAssessmentAttempt({
    required String assessmentId,
    required String userId,
    required int score,
    required int timeSpentSecs,
    required List<Map<String, dynamic>> challengeSubmissions,
  }) async {
    if (assessmentId.isEmpty || userId.isEmpty) return false;

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

      // 2.5 Record in user_assessment_attempts for CRA Competency scoring
      try {
        await _supabase.from('user_assessment_attempts').insert(<String, dynamic>{
          'user_id': userId,
          'assessment_id': assessmentId,
          'status': 'graded',
          'score': score,
          'submitted_at': DateTime.now().toIso8601String(),
          'graded_at': DateTime.now().toIso8601String(),
        });
      } catch (attErr) {
        debugPrint('Non-critical attempt insert error: $attErr');
      }

      // 3. Insert submissions for each challenge if provided
      for (final Map<String, dynamic> item in challengeSubmissions) {
        try {
          final String? challengeId = item['challenge_id']?.toString();
          final String code = item['code']?.toString() ?? '';
          final String lang = item['language']?.toString() ?? 'javascript';
          final bool passed = item['passed'] == true;

          await _supabase.from('submissions').insert(<String, dynamic>{
            'learner_id': userId,
            'assessment_id': assessmentId,
            if (challengeId != null && challengeId.isNotEmpty)
              'challenge_id': challengeId,
            'code': code,
            'language': lang,
            'verdict': passed ? 'accepted' : 'wrong_answer',
            'submitted_at': DateTime.now().toIso8601String(),
          });
        } catch (subErr) {
          debugPrint('Error inserting challenge submission log: $subErr');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error submitting assessment attempt: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserAssessmentAttempts(String userId) async {
    if (userId.isEmpty) return <Map<String, dynamic>>[];

    try {
      final dynamic attemptsData = await _supabase
          .from('user_assessment_attempts')
          .select('assessment_id, status, score')
          .eq('user_id', userId);

      if (attemptsData is List && attemptsData.isNotEmpty) {
        return attemptsData.cast<Map<String, dynamic>>();
      }

      // Fallback: check user_assessment_library best_score
      final dynamic libData = await _supabase
          .from('user_assessment_library')
          .select('assessment_id, status, best_score')
          .eq('user_id', userId);

      if (libData is List && libData.isNotEmpty) {
        return libData.map<Map<String, dynamic>>((dynamic item) {
          final Map<String, dynamic> m = item as Map<String, dynamic>;
          return <String, dynamic>{
            'assessment_id': m['assessment_id'],
            'status': m['status'] ?? 'completed',
            'score': m['best_score'],
          };
        }).toList();
      }

      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('Error fetching user assessment attempts: $e');
      return <Map<String, dynamic>>[];
    }
  }
}
