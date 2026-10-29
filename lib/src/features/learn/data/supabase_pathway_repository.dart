import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/network/api_client.dart';
import '../domain/activity_submission_review_model.dart';
import '../domain/learn_dashboard_data.dart';
import '../domain/module_detail_model.dart';
import '../domain/pathway_model.dart';
import '../domain/module_review_model.dart';
import '../domain/practice_exercise_model.dart';
import '../domain/room_model.dart';
import '../domain/submission_history_model.dart';
import 'pathway_repository.dart';

class SupabasePathwayRepository implements PathwayRepository {
  const SupabasePathwayRepository({
    this.client,
    this.apiClient = const ApiClient(),
  });

  final supabase.SupabaseClient? client;
  final ApiClient apiClient;
  static LearnDashboardData? cachedData;
  static final Map<String, ModuleDetailModel> _moduleDetailsCache =
      <String, ModuleDetailModel>{};
  static final ValueNotifier<Set<String>> bookmarkedIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});
  /// Bumped after every successful practice/challenge submission so that
  /// IndexedStack-cached screens (Dashboard, Modules) know to reload.
  static final ValueNotifier<int> catalogRefreshNotifier =
      ValueNotifier<int>(0);

  @override
  ModuleDetailModel? getCachedModuleDetails(String moduleId) =>
      _moduleDetailsCache[moduleId];

  supabase.SupabaseClient get _supabase =>
      client ?? supabase.Supabase.instance.client;

  @override
  Future<LearnDashboardData> getLearnDashboardData(String userId) async {
    // 1. Fetch live published modules (Go Backend with Supabase Fallback)
    List<Map<String, dynamic>> rawModules = <Map<String, dynamic>>[];
    try {
      final dynamic apiResult = await apiClient.get('/api/modules');
      if (apiResult is List) {
        rawModules = apiResult.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Direct fallback to Supabase PostgreSQL table
    }

    if (rawModules.isEmpty) {
      try {
        final List<Map<String, dynamic>> dbModules = await _supabase
            .from('modules')
            .select('*, profiles:mentor_id(user_first_name, user_last_name, user_avatar_url)')
            .eq('mod_status', 'published')
            .order('mod_created_at', ascending: false);

        rawModules = dbModules;
      } catch (_) {
        // Handle offline / empty
      }
    }

    // 2. Fetch topics for each module
    final Map<String, List<Map<String, dynamic>>> topicsByTrack =
        <String, List<Map<String, dynamic>>>{};
    // topicId -> trackId (needed to map activity back to module)
    final Map<String, String> topicIdToTrackId = <String, String>{};
    final List<String> allTopicIds = <String>[];
    try {
      final List<Map<String, dynamic>> allTopics = await _supabase
          .from('topics')
          .select('topic_id, track_id, topic_title, topic_order_index')
          .order('topic_order_index', ascending: true);

      for (final Map<String, dynamic> t in allTopics) {
        final String trackId = t['track_id'] as String? ?? '';
        final String topicId = t['topic_id'] as String? ?? '';
        topicsByTrack.putIfAbsent(trackId, () => <Map<String, dynamic>>[]).add(t);
        if (topicId.isNotEmpty) {
          topicIdToTrackId[topicId] = trackId;
          allTopicIds.add(topicId);
        }
      }
    } catch (_) {
      // Non-blocking
    }

    // 2b. Fetch all practice activities and build per-module totals
    // actId -> trackId
    final Map<String, String> actIdToTrackId = <String, String>{};
    // trackId -> total practice activity count
    final Map<String, int> moduleTotalPractice = <String, int>{};
    final Map<String, String> actIdToTitle = <String, String>{};
    final Map<String, String> actIdToDifficulty = <String, String>{};
    final Map<String, String> trackIdToTitle = <String, String>{};

    for (final dynamic m in rawModules) {
      if (m is Map<String, dynamic>) {
        final String modId = m['mod_id']?.toString() ?? '';
        final String modTitle = m['mod_title']?.toString() ?? '';
        if (modId.isNotEmpty && modTitle.isNotEmpty) {
          trackIdToTitle[modId] = modTitle;
        }
      }
    }

    if (allTopicIds.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> allActivities = await _supabase
            .from('activities')
            .select('act_id, topic_id, track_id, act_type, act_category, act_difficulty, act_status, act_title')
            .filter('topic_id', 'in', allTopicIds);

        for (final Map<String, dynamic> a in allActivities) {
          final String actStatus =
              (a['act_status'] as String? ?? 'published').toLowerCase();
          if (actStatus == 'hidden') continue;
          final String actId = a['act_id'] as String? ?? '';
          final String tId = a['topic_id'] as String? ?? '';
          final String trackId = topicIdToTrackId[tId] ?? '';
          final String actTitle = a['act_title'] as String? ?? '';
          final String cat = (a['act_category'] as String? ?? '').toLowerCase();
          final String? rawDiff = a['act_difficulty'] as String?;
          final String diff = cat == 'challenge' ? (rawDiff ?? 'Medium') : '';

          if (actId.isNotEmpty) {
            if (actTitle.isNotEmpty) actIdToTitle[actId] = actTitle;
            actIdToDifficulty[actId] = diff;
          }
          if (actId.isEmpty || trackId.isEmpty) continue;
          actIdToTrackId[actId] = trackId;
          moduleTotalPractice[trackId] =
              (moduleTotalPractice[trackId] ?? 0) + 1;
        }

        // Also include direct module-level challenges
        final List<String> allModIds = rawModules
            .map((dynamic m) => (m as Map<String, dynamic>)['mod_id'] as String? ?? '')
            .where((String s) => s.isNotEmpty)
            .toList();

        if (allModIds.isNotEmpty) {
          final List<Map<String, dynamic>> directActs = await _supabase
              .from('activities')
              .select('act_id, track_id, act_status, act_title, act_category, act_difficulty')
              .filter('track_id', 'in', allModIds);

          for (final Map<String, dynamic> a in directActs) {
            final String actStatus =
                (a['act_status'] as String? ?? 'published').toLowerCase();
            if (actStatus == 'hidden') continue;
            final String actId = a['act_id'] as String? ?? '';
            final String trackId = a['track_id'] as String? ?? '';
            final String actTitle = a['act_title'] as String? ?? '';
            final String cat = (a['act_category'] as String? ?? '').toLowerCase();
            final String? rawDiff = a['act_difficulty'] as String?;
            final String diff = cat == 'challenge' ? (rawDiff ?? 'Medium') : '';

            if (actId.isNotEmpty) {
              if (actTitle.isNotEmpty && !actIdToTitle.containsKey(actId)) {
                actIdToTitle[actId] = actTitle;
              }
              if (!actIdToDifficulty.containsKey(actId)) {
                actIdToDifficulty[actId] = diff;
              }
            }
            if (actId.isEmpty || trackId.isEmpty || actIdToTrackId.containsKey(actId)) continue;
            actIdToTrackId[actId] = trackId;
            moduleTotalPractice[trackId] =
                (moduleTotalPractice[trackId] ?? 0) + 1;
          }
        }
      } catch (_) {
        // Non-blocking
      }
    }

    // 3. Fetch User Bookmarks (user_practice_saves)
    final Set<String> bookmarkedIds = <String>{};
    try {
      final List<Map<String, dynamic>> dbSaves = await _supabase
          .from('user_practice_saves')
          .select('track_id')
          .eq('user_id', userId);

      for (final Map<String, dynamic> row in dbSaves) {
        final String? tId = row['track_id'] as String?;
        if (tId != null) bookmarkedIds.add(tId);
      }
      bookmarkedIdsNotifier.value = Set<String>.from(bookmarkedIds);
    } catch (_) {
      // Non-blocking
    }

    // 4. Fetch User Practice Progress & Enrollments (user_practice_progress)
    final Set<String> enrolledIds = <String>{};
    final Map<String, int> dbProgressMap = <String, int>{};
    try {
      final List<Map<String, dynamic>> progressRows = await _supabase
          .from('user_practice_progress')
          .select('track_id, upp_completion')
          .eq('user_id', userId);

      for (final Map<String, dynamic> row in progressRows) {
        final String? tId = row['track_id'] as String?;
        if (tId != null) {
          enrolledIds.add(tId);
          dbProgressMap[tId] = (row['upp_completion'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {
      // Non-blocking
    }

    // 4b. Fetch accepted submissions to compute live per-module progress
    // trackId -> solved count
    final Map<String, int> moduleSolvedPractice = <String, int>{};
    try {
      final List<Map<String, dynamic>> acceptedSubs = await _supabase
          .from('submissions')
          .select('item_id')
          .eq('user_id', userId)
          .inFilter('sub_status', const <String>['accepted', 'passed', 'Accepted', 'Passed']);

      for (final Map<String, dynamic> row in acceptedSubs) {
        final String? itemId = row['item_id'] as String?;
        if (itemId == null || itemId.isEmpty) continue;
        final String? trackId = actIdToTrackId[itemId];
        if (trackId != null && trackId.isNotEmpty) {
          moduleSolvedPractice[trackId] =
              (moduleSolvedPractice[trackId] ?? 0) + 1;
        }
      }
    } catch (_) {
      // Non-blocking
    }

    // 5. Fetch User Streaks
    int currentStreak = 0;
    try {
      final List<Map<String, dynamic>> streakRows = await _supabase
          .from('user_streaks')
          .select('current_streak')
          .eq('user_id', userId)
          .limit(1);

      if (streakRows.isNotEmpty) {
        currentStreak = (streakRows.first['current_streak'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      // Non-blocking
    }

    // 6. Fetch Submissions stats and recent activity submissions
    int easySolved = 0;
    int mediumSolved = 0;
    int hardSolved = 0;
    final List<DashboardSubmission> dashboardSubmissions = <DashboardSubmission>[];
    try {
      List<Map<String, dynamic>> subRows = <Map<String, dynamic>>[];
      try {
        subRows = await _supabase
            .from('submissions')
            .select(
              'sub_id, item_id, sub_language, sub_code, sub_status, sub_verdict, sub_submitted_at, ai_audits(audit_findings)',
            )
            .eq('user_id', userId)
            .order('sub_submitted_at', ascending: false)
            .limit(100);
      } catch (_) {
        // Fallback without embedded relation if join fails
        subRows = await _supabase
            .from('submissions')
            .select(
              'sub_id, item_id, sub_language, sub_code, sub_status, sub_verdict, sub_submitted_at',
            )
            .eq('user_id', userId)
            .order('sub_submitted_at', ascending: false)
            .limit(100);
      }

      final Map<String, dynamic> auditScoresBySubId = <String, dynamic>{};
      final Map<String, Map<String, dynamic>> auditFindingsBySubId = <String, Map<String, dynamic>>{};
      final List<String> subIdsNeedingAudit = <String>[];
      for (final Map<String, dynamic> s in subRows) {
        final String sId = s['sub_id']?.toString() ?? '';
        final dynamic audits = s['ai_audits'];
        dynamic score;
        Map<String, dynamic>? findingsMap;
        if (audits is List && audits.isNotEmpty && audits.first is Map) {
          final dynamic findings = (audits.first as Map)['audit_findings'];
          if (findings is Map) {
            findingsMap = Map<String, dynamic>.from(findings);
            score = findings['acf_composite_score'] ?? findings['score'];
          }
        } else if (audits is Map && audits['audit_findings'] is Map) {
          final dynamic findings = audits['audit_findings'];
          if (findings is Map) {
            findingsMap = Map<String, dynamic>.from(findings);
            score = findings['acf_composite_score'] ?? findings['score'];
          }
        }
        if (findingsMap != null) {
          auditFindingsBySubId[sId] = findingsMap;
        }
        if (score != null) {
          auditScoresBySubId[sId] = score;
        } else if (sId.isNotEmpty) {
          subIdsNeedingAudit.add(sId);
        }
      }

      if (subIdsNeedingAudit.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> audits = await _supabase
              .from('ai_audits')
              .select('sub_id, audit_findings')
              .inFilter('sub_id', subIdsNeedingAudit);
          for (final Map<String, dynamic> a in audits) {
            final String aSubId = a['sub_id']?.toString() ?? '';
            final dynamic findings = a['audit_findings'];
            if (findings is Map) {
              final Map<String, dynamic> fMap = Map<String, dynamic>.from(findings);
              auditFindingsBySubId[aSubId] = fMap;
              final dynamic sc =
                  findings['acf_composite_score'] ?? findings['score'];
              if (sc != null) {
                auditScoresBySubId[aSubId] = sc;
              }
            }
          }
        } catch (_) {
          // Non-blocking
        }
      }

      // Batch resolve missing activities for submissions if any item_id is missing from actIdToTitle
      final List<String> missingActIds = subRows
          .map((Map<String, dynamic> s) => s['item_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty && !actIdToTitle.containsKey(id))
          .toSet()
          .toList();

      if (missingActIds.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> missingActs = await _supabase
              .from('activities')
              .select('act_id, act_title, act_category, act_difficulty, topic_id, track_id')
              .inFilter('act_id', missingActIds);

          final Set<String> neededTopicIds = <String>{};
          for (final Map<String, dynamic> a in missingActs) {
            final String aId = a['act_id']?.toString() ?? '';
            if (aId.isEmpty) continue;
            final String aTitle = a['act_title'] as String? ?? '';
            final String cat = (a['act_category'] as String? ?? '').toLowerCase();
            final String? rawDiff = a['act_difficulty'] as String?;
            final String diff = cat == 'challenge' ? (rawDiff ?? 'Medium') : '';

            if (aTitle.isNotEmpty) actIdToTitle[aId] = aTitle;
            actIdToDifficulty[aId] = diff;

            final String directTrackId = a['track_id'] as String? ?? '';
            if (directTrackId.isNotEmpty) {
              actIdToTrackId[aId] = directTrackId;
            } else {
              final String topId = a['topic_id'] as String? ?? '';
              if (topId.isNotEmpty) {
                if (topicIdToTrackId.containsKey(topId)) {
                  actIdToTrackId[aId] = topicIdToTrackId[topId]!;
                } else {
                  neededTopicIds.add(topId);
                }
              }
            }
          }

          if (neededTopicIds.isNotEmpty) {
            final List<Map<String, dynamic>> missingTopics = await _supabase
                .from('topics')
                .select('topic_id, track_id')
                .inFilter('topic_id', neededTopicIds.toList());

            final Set<String> neededModIds = <String>{};
            for (final Map<String, dynamic> t in missingTopics) {
              final String topId = t['topic_id']?.toString() ?? '';
              final String trkId = t['track_id']?.toString() ?? '';
              if (topId.isNotEmpty && trkId.isNotEmpty) {
                topicIdToTrackId[topId] = trkId;
                if (!trackIdToTitle.containsKey(trkId)) {
                  neededModIds.add(trkId);
                }
              }
            }

            for (final Map<String, dynamic> a in missingActs) {
              final String aId = a['act_id']?.toString() ?? '';
              final String topId = a['topic_id'] as String? ?? '';
              if (!actIdToTrackId.containsKey(aId) && topicIdToTrackId.containsKey(topId)) {
                actIdToTrackId[aId] = topicIdToTrackId[topId]!;
              }
            }

            if (neededModIds.isNotEmpty) {
              final List<Map<String, dynamic>> missingMods = await _supabase
                  .from('modules')
                  .select('mod_id, mod_title')
                  .inFilter('mod_id', neededModIds.toList());
              for (final Map<String, dynamic> m in missingMods) {
                final String mId = m['mod_id']?.toString() ?? '';
                final String mTitle = m['mod_title'] as String? ?? '';
                if (mId.isNotEmpty && mTitle.isNotEmpty) {
                  trackIdToTitle[mId] = mTitle;
                }
              }
            }
          }
        } catch (_) {
          // Non-blocking
        }
      }

      for (final Map<String, dynamic> s in subRows) {
        final String sId = s['sub_id']?.toString() ?? '';
        final String status = s['sub_status'] as String? ?? '';
        final String normStatus = DashboardSubmission.normalizeStatus(status);
        if (normStatus == 'Passed') {
          easySolved++;
        }
        final String itemId = s['item_id']?.toString() ?? '';
        final String actTitle = actIdToTitle[itemId] ?? 'Practice Challenge';
        final String trackId = actIdToTrackId[itemId] ?? '';
        final String modTitle = trackIdToTitle[trackId] ?? 'Practice Module';
        final String diff = actIdToDifficulty[itemId] ?? '';
        final Map<String, dynamic>? findings = auditFindingsBySubId[sId] ??
            (s['findings'] is Map ? Map<String, dynamic>.from(s['findings'] as Map) : null);

        dashboardSubmissions.add(
          DashboardSubmission.fromDatabase(
            row: s,
            title: actTitle,
            moduleId: trackId,
            moduleTitle: modTitle,
            difficulty: diff,
            acfScore: auditScoresBySubId[sId],
          ).copyWith(findings: findings),
        );
      }
    } catch (_) {
      // Non-blocking
    }

    // If streak was 0 from table, compute live streak from submissions (matching Web 1:1)
    if (currentStreak == 0 && dashboardSubmissions.isNotEmpty) {
      final Set<String> daySet = dashboardSubmissions
          .where((DashboardSubmission s) => s.rawDate.isNotEmpty)
          .map((DashboardSubmission s) => s.rawDate)
          .toSet();

      final DateTime today = DateTime.now();
      for (int i = 0; i < 365; i++) {
        final DateTime checkDate = today.subtract(Duration(days: i));
        final String dateKey =
            '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        if (daySet.contains(dateKey)) {
          currentStreak++;
        } else if (i == 0) {
          continue;
        } else {
          break;
        }
      }
    }

    final int calculatedActiveDays = dashboardSubmissions
        .map((DashboardSubmission s) => s.rawDate)
        .where((String d) => d.isNotEmpty)
        .toSet()
        .length;

    // 7. Map to PathwayModel list with dynamically computed live progress
    final List<PathwayModel> mappedPathways = <PathwayModel>[];
    for (final Map<String, dynamic> m in rawModules) {
      final String modId = m['mod_id'] as String? ?? '';
      final List<Map<String, dynamic>> topics = topicsByTrack[modId] ?? const <Map<String, dynamic>>[];
      final bool isEnrolled = enrolledIds.contains(modId);
      final bool isBookmarked = bookmarkedIds.contains(modId);

      // Compute live completion: solved / total * 100 (same as getModuleDetails)
      // Fallback to upp_completion from DB when the bulk activities query
      // returns empty (e.g. large IN filter exceeding URL/row limits).
      final int total = moduleTotalPractice[modId] ?? 0;
      final int solved = moduleSolvedPractice[modId] ?? 0;
      final int dynamicProgress =
          total > 0 ? ((solved / total) * 100).round() : 0;
      final int liveProgress =
          dynamicProgress > 0 ? dynamicProgress : (dbProgressMap[modId] ?? 0);

      mappedPathways.add(
        PathwayModel.fromDatabase(
          moduleData: m,
          topics: topics,
          isEnrolled: isEnrolled,
          isBookmarked: isBookmarked,
          userProgress: liveProgress,
        ),
      );
    }

    // Enrolled / Active Pathways (Marketplace Tracks - matching Web 1:1)
    final List<PathwayModel> purchased = mappedPathways
        .where((PathwayModel p) => p.isEnrolled || p.completion > 0)
        .toList();
    final List<PathwayModel> enrolledPathways =
        purchased.isNotEmpty ? purchased : mappedPathways.take(3).toList();

    // Primary active track (Hero): Prioritize in-progress track (completion > 0 && completion < 100)
    final PathwayModel? activePathway = enrolledPathways.isEmpty
        ? null
        : enrolledPathways.firstWhere(
            (PathwayModel p) => p.completion > 0 && p.completion < 100,
            orElse: () => enrolledPathways.first,
          );

    final LearnDashboardData result = LearnDashboardData(
      activePathway: activePathway,
      enrolledPathways: enrolledPathways,
      allPathways: mappedPathways,
      currentStreak: currentStreak,
      totalActiveDays: calculatedActiveDays > 0 ? calculatedActiveDays : (currentStreak > 0 ? currentStreak : 0),
      easySolved: easySolved,
      mediumSolved: mediumSolved,
      hardSolved: hardSolved,
      submissions: dashboardSubmissions,
    );

    cachedData = result;
    return result;
  }

  @override
  Future<bool> enrollModule(String userId, String moduleId) async {
    try {
      await _supabase.from('user_practice_progress').upsert(<String, dynamic>{
        'user_id': userId,
        'track_id': moduleId,
        'upp_completion': 0,
        'upp_updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,track_id');

      if (_moduleDetailsCache.containsKey(moduleId)) {
        _moduleDetailsCache[moduleId] =
            _moduleDetailsCache[moduleId]!.copyWith(isEnrolled: true);
      }
      if (cachedData != null) {
        PathwayModel markEnrolled(PathwayModel p) =>
            p.id == moduleId ? p.copyWith(isEnrolled: true) : p;

        cachedData = LearnDashboardData(
          activePathway: cachedData!.activePathway,
          enrolledPathways: cachedData!.enrolledPathways.map(markEnrolled).toList(),
          allPathways: cachedData!.allPathways.map(markEnrolled).toList(),
          currentStreak: cachedData!.currentStreak,
          totalActiveDays: cachedData!.totalActiveDays,
          easySolved: cachedData!.easySolved,
          mediumSolved: cachedData!.mediumSolved,
          hardSolved: cachedData!.hardSolved,
          recommendedChallenges: cachedData!.recommendedChallenges,
          submissions: cachedData!.submissions,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ModuleDetailModel?> getModuleDetails(String moduleId, String userId) async {
    try {
      // 1. Fetch module row with mentor info
      final List<Map<String, dynamic>> modRows = await _supabase
          .from('modules')
          .select('*, profiles:mentor_id(user_first_name, user_last_name, user_avatar_url)')
          .eq('mod_id', moduleId)
          .limit(1);

      if (modRows.isEmpty) return null;
      final Map<String, dynamic> mod = modRows.first;

      // 2. Check enrollment & progress & bookmark
      bool isEnrolled = false;
      int completion = 0;
      bool isBookmarked = bookmarkedIdsNotifier.value.contains(moduleId);

      final Set<String> solvedItemIds = <String>{};
      if (userId.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> saveRows = await _supabase
              .from('user_practice_saves')
              .select('track_id')
              .eq('user_id', userId)
              .eq('track_id', moduleId)
              .limit(1);
          if (saveRows.isNotEmpty) {
            isBookmarked = true;
          }

          final List<Map<String, dynamic>> progRows = await _supabase
              .from('user_practice_progress')
              .select('upp_completion')
              .eq('user_id', userId)
              .eq('track_id', moduleId)
              .limit(1);
          if (progRows.isNotEmpty) {
            completion = (progRows.first['upp_completion'] as num?)?.toInt() ?? 0;
            isEnrolled = true;
          }

          // Fetch user's accepted submissions to accurately flag solved activities
          final List<Map<String, dynamic>> subRows = await _supabase
              .from('submissions')
              .select('item_id')
              .eq('user_id', userId)
              .eq('sub_status', 'accepted');
          for (final Map<String, dynamic> r in subRows) {
            final String? itemId = r['item_id'] as String?;
            if (itemId != null && itemId.isNotEmpty) {
              solvedItemIds.add(itemId);
            }
          }
        } catch (_) {}
      }

      // 3. Fetch all topics for this module
      final List<Map<String, dynamic>> topicRows = await _supabase
          .from('topics')
          .select()
          .eq('track_id', moduleId)
          .order('topic_order_index', ascending: true);

      final List<String> allTopicIds = topicRows
          .map((Map<String, dynamic> t) => t['topic_id'] as String? ?? '')
          .where((String s) => s.isNotEmpty)
          .toList();

      final Map<String, List<ModuleActivityModel>> activitiesByTopicId =
          <String, List<ModuleActivityModel>>{};

      final List<ModuleActivityModel> moduleLevelChallenges = <ModuleActivityModel>[];

      // Fetch topic activities
      if (allTopicIds.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> actRows = await _supabase
              .from('activities')
              .select()
              .filter('topic_id', 'in', allTopicIds)
              .order('act_order_index', ascending: true);

          for (final Map<String, dynamic> a in actRows) {
            final String actStatus =
                (a['act_status'] as String? ?? 'published').toLowerCase();
            if (actStatus == 'hidden') continue;
            final String tId = a['topic_id'] as String? ?? '';
            final String actId = a['act_id'] as String? ?? '';
            final ModuleActivityModel act = ModuleActivityModel.fromJson(
              a,
              isCompleted: solvedItemIds.contains(actId),
            );
            activitiesByTopicId.putIfAbsent(tId, () => <ModuleActivityModel>[]).add(act);
          }
        } catch (_) {}
      }

      // Fetch module-level activities/challenges (track_id == moduleId)
      try {
        final List<Map<String, dynamic>> modActRows = await _supabase
            .from('activities')
            .select()
            .eq('track_id', moduleId)
            .order('act_order_index', ascending: true);

        for (final Map<String, dynamic> a in modActRows) {
          final String actStatus =
              (a['act_status'] as String? ?? 'published').toLowerCase();
          if (actStatus == 'hidden') continue;
          final String? tId = a['topic_id'] as String?;
          final String actId = a['act_id'] as String? ?? '';
          if (tId != null && tId.isNotEmpty) {
            final ModuleActivityModel act = ModuleActivityModel.fromJson(
              a,
              isCompleted: solvedItemIds.contains(actId),
            );
            activitiesByTopicId.putIfAbsent(tId, () => <ModuleActivityModel>[]).add(act);
          } else {
            // Module-level benchmark challenge
            final ModuleActivityModel act = ModuleActivityModel.fromJson(
              a,
              isCompleted: solvedItemIds.contains(actId),
            );
            moduleLevelChallenges.add(act);
          }
        }
      } catch (_) {}

      // Deduplicate topics by compound key (order + title) and merge activities
      final Map<String, Map<String, dynamic>> uniqueTopicMap =
          <String, Map<String, dynamic>>{};
      final Map<String, List<ModuleActivityModel>> mergedActsByCompoundKey =
          <String, List<ModuleActivityModel>>{};

      for (final Map<String, dynamic> t in topicRows) {
        final String titleKey = (t['topic_title'] as String? ?? '').trim().toLowerCase();
        final int orderKey = (t['topic_order_index'] as num?)?.toInt() ?? 0;
        final String compoundKey = '$orderKey-$titleKey';
        final String tId = t['topic_id'] as String? ?? '';
        final List<ModuleActivityModel> acts =
            activitiesByTopicId[tId] ?? <ModuleActivityModel>[];

        mergedActsByCompoundKey
            .putIfAbsent(compoundKey, () => <ModuleActivityModel>[])
            .addAll(acts);

        if (!uniqueTopicMap.containsKey(compoundKey)) {
          uniqueTopicMap[compoundKey] = t;
        } else if (acts.isNotEmpty) {
          uniqueTopicMap[compoundKey] = t;
        }
      }

      final List<ModuleTopicModel> mappedTopics = uniqueTopicMap.entries.map((MapEntry<String, Map<String, dynamic>> e) {
        final Map<String, dynamic> t = e.value;
        final List<ModuleActivityModel> acts =
            mergedActsByCompoundKey[e.key] ?? <ModuleActivityModel>[];
        final Set<String> seenActIds = <String>{};
        final List<ModuleActivityModel> uniqueActs = <ModuleActivityModel>[];
        for (final ModuleActivityModel a in acts) {
          if (!seenActIds.contains(a.id)) {
            seenActIds.add(a.id);
            uniqueActs.add(a);
          }
        }
        final bool isTopicDone = uniqueActs.isNotEmpty &&
            uniqueActs.every((ModuleActivityModel a) => a.isCompleted);
        return ModuleTopicModel.fromJson(
          t,
          activities: uniqueActs,
          isCompleted: isTopicDone,
        );
      }).toList();

      List<String> stackList = <String>[];
      final dynamic rawStack = mod['mod_stack'];
      if (rawStack is List) {
        stackList = rawStack.map((dynamic e) => e.toString().toLowerCase()).toList();
      } else if (rawStack is String && rawStack.isNotEmpty) {
        stackList = rawStack.split(',').map((String s) => s.trim().toLowerCase()).toList();
      }

      final dynamic mentorObj = mod['profiles'];
      String coachName = 'CodeMentor AI';
      String? coachAvatar;
      if (mentorObj is Map<String, dynamic>) {
        final String f = mentorObj['user_first_name'] as String? ?? '';
        final String l = mentorObj['user_last_name'] as String? ?? '';
        if (f.isNotEmpty || l.isNotEmpty) {
          coachName = '$f $l'.trim();
        }
        coachAvatar = mentorObj['user_avatar_url'] as String?;
      }

      // Compute actual completion from solved activities and challenges (1:1 with Web)
      int totalModuleActs = 0;
      int solvedModuleActs = 0;
      for (final ModuleTopicModel topic in mappedTopics) {
        for (final ModuleActivityModel act in topic.activities) {
          totalModuleActs++;
          if (act.isCompleted) {
            solvedModuleActs++;
          }
        }
      }
      for (final ModuleActivityModel ch in moduleLevelChallenges) {
        totalModuleActs++;
        if (ch.isCompleted) {
          solvedModuleActs++;
        }
      }
      int effectiveCompletion = completion;
      if (totalModuleActs > 0) {
        effectiveCompletion = ((solvedModuleActs / totalModuleActs) * 100).round();
      }

      final String rawDesc =
          mod['mod_description'] as String? ?? mod['description'] as String? ?? '';
      final String finalDesc = rawDesc.trim().isNotEmpty
          ? rawDesc.trim()
          : 'Self-paced coding practice exercises and challenges.';

      final ModuleDetailModel result = ModuleDetailModel(
        id: moduleId,
        title: mod['mod_title'] as String? ?? 'Engineering Module',
        description: finalDesc,
        stack: stackList,
        price: (mod['mod_price'] as num?)?.toDouble() ?? 0.0,
        coachName: coachName,
        coachAvatar: coachAvatar,
        rating: (mod['mod_rating'] as num?)?.toDouble() ?? 5.0,
        completion: effectiveCompletion,
        isEnrolled: isEnrolled,
        isBookmarked: isBookmarked,
        topics: mappedTopics,
        challenges: moduleLevelChallenges,
      );
      _moduleDetailsCache[moduleId] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<PathwayModel>> getAllModules(String userId) async {
    final LearnDashboardData data = await getLearnDashboardData(userId);
    return data.allPathways;
  }

  @override
  Future<bool> toggleBookmark(
    String userId,
    String moduleId,
    bool isBookmarked,
  ) async {
    if (userId.isEmpty || moduleId.isEmpty) return false;

    // Optimistic reactive broadcast to all listening screens
    final Set<String> updated = Set<String>.from(bookmarkedIdsNotifier.value);
    if (isBookmarked) {
      updated.add(moduleId);
    } else {
      updated.remove(moduleId);
    }
    bookmarkedIdsNotifier.value = updated;

    // Optimistically update module details cache if loaded
    if (_moduleDetailsCache.containsKey(moduleId)) {
      _moduleDetailsCache[moduleId] =
          _moduleDetailsCache[moduleId]!.copyWith(isBookmarked: isBookmarked);
    }

    // Optimistically update dashboard/catalog cache if loaded
    if (cachedData != null) {
      PathwayModel updateBookmark(PathwayModel p) =>
          p.id == moduleId ? p.copyWith(isBookmarked: isBookmarked) : p;

      cachedData = LearnDashboardData(
        activePathway: cachedData!.activePathway,
        enrolledPathways: cachedData!.enrolledPathways.map(updateBookmark).toList(),
        allPathways: cachedData!.allPathways.map(updateBookmark).toList(),
        currentStreak: cachedData!.currentStreak,
        totalActiveDays: cachedData!.totalActiveDays,
        easySolved: cachedData!.easySolved,
        mediumSolved: cachedData!.mediumSolved,
        hardSolved: cachedData!.hardSolved,
        recommendedChallenges: cachedData!.recommendedChallenges,
        submissions: cachedData!.submissions,
      );
    }

    try {
      if (isBookmarked) {
        await _supabase.from('user_practice_saves').upsert(<String, dynamic>{
          'user_id': userId,
          'track_id': moduleId,
          'ups_saved_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await _supabase
            .from('user_practice_saves')
            .delete()
            .eq('user_id', userId)
            .eq('track_id', moduleId);
      }
      return true;
    } catch (_) {
      // Revert optimistic update on failure
      final Set<String> reverted = Set<String>.from(bookmarkedIdsNotifier.value);
      if (isBookmarked) {
        reverted.remove(moduleId);
      } else {
        reverted.add(moduleId);
      }
      bookmarkedIdsNotifier.value = reverted;
      if (_moduleDetailsCache.containsKey(moduleId)) {
        _moduleDetailsCache[moduleId] =
            _moduleDetailsCache[moduleId]!.copyWith(isBookmarked: !isBookmarked);
      }
      return false;
    }
  }

  @override
  Future<PracticeExerciseModel?> getPracticeExercise(
    String moduleId,
    String exerciseId,
    String userId,
  ) async {
    try {
      // 1. Fetch from Supabase activities table if valid UUID
      Map<String, dynamic>? actData;
      Map<String, dynamic>? codeData;
      List<Map<String, dynamic>> testCaseRows = <Map<String, dynamic>>[];

      try {
        final List<Map<String, dynamic>> actRows = await _supabase
            .from('activities')
            .select('*, code_details(*), test_cases(*)')
            .eq('act_id', exerciseId)
            .limit(1);

        if (actRows.isNotEmpty) {
          final String status =
              (actRows.first['act_status'] as String? ?? 'published').toLowerCase();
          if (status == 'hidden') return null;
          actData = actRows.first;
          final dynamic cd = actData['code_details'];
          if (cd is List && cd.isNotEmpty) {
            codeData = cd.first as Map<String, dynamic>;
          } else if (cd is Map<String, dynamic>) {
            codeData = cd;
          }

          final dynamic tc = actData['test_cases'];
          if (tc is List) {
            testCaseRows = tc.cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {
        // Non-blocking (handles synthetic exercise IDs like node-1788166574061)
      }

      // Check if user completed this activity before
      bool isCompleted = false;
      if (userId.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> subRows = await _supabase
              .from('submissions')
              .select('sub_id')
              .eq('user_id', userId)
              .eq('item_id', exerciseId)
              .eq('sub_status', 'accepted')
              .limit(1);
          isCompleted = subRows.isNotEmpty;
        } catch (_) {}
      }

      // 2. Derive activity details or synthesize defensively
      final String title = actData?['act_title'] as String? ??
          exerciseId
              .replaceAll('-', ' ')
              .replaceAllMapped(
                RegExp(r'\b\w'),
                (Match m) => m.group(0)!.toUpperCase(),
              )
              .trim();

      final String difficulty =
          actData?['act_difficulty'] as String? ?? 'Medium';
      final String targetTime =
          codeData?['target_time'] as String? ?? 'O(1)';
      final String targetSpace =
          codeData?['target_space'] as String? ?? 'O(1)';

      // Extract starter codes if present
      final Map<String, String> starterCodes = <String, String>{};
      final dynamic rawStarters = codeData?['starter_codes'];
      if (rawStarters is Map) {
        rawStarters.forEach((dynamic k, dynamic v) {
          if (v != null && v.toString().trim().isNotEmpty) {
            starterCodes[k.toString().toLowerCase()] = v.toString();
          }
        });
      }

      bool isPlaceholder(String val) {
        final String lower = val.trim().toLowerCase();
        return lower.isEmpty ||
            lower == '// write solution here' ||
            lower == '# write solution here' ||
            lower.startsWith('// write solution here') ||
            lower.startsWith('# write solution here');
      }

      // Purge placeholder values from starterCodes map
      starterCodes.removeWhere((String k, String v) => isPlaceholder(v));

      // Determine declared languages strictly from DB code_details.languages column
      final List<String> declaredLanguages = <String>[];
      final dynamic rawLangs = codeData?['languages'];
      if (rawLangs is List) {
        for (final dynamic l in rawLangs) {
          if (l != null && l.toString().trim().isNotEmpty) {
            declaredLanguages.add(l.toString().toLowerCase());
          }
        }
      }

      // Priority 1: Module technology stack
      final List<String> modStackLangs = <String>[];
      if (moduleId.isNotEmpty) {
        final ModuleDetailModel? cachedMod = _moduleDetailsCache[moduleId];
        if (cachedMod != null && cachedMod.stack.isNotEmpty) {
          modStackLangs.addAll(cachedMod.stack);
        } else {
          try {
            final List<Map<String, dynamic>> modRows = await _supabase
                .from('modules')
                .select('mod_stack')
                .eq('mod_id', moduleId)
                .limit(1);
            if (modRows.isNotEmpty) {
              final dynamic modStack = modRows.first['mod_stack'];
              if (modStack is List) {
                for (final dynamic s in modStack) {
                  if (s != null && s.toString().trim().isNotEmpty) {
                    modStackLangs.add(s.toString().trim().toLowerCase());
                  }
                }
              } else if (modStack is String && modStack.trim().isNotEmpty) {
                modStackLangs.addAll(
                  modStack.split(',').map((String s) => s.trim().toLowerCase()).where((String s) => s.isNotEmpty),
                );
              }
            }
          } catch (_) {}
        }
      }

      const List<String> allSupported = <String>[
        'java',
        'python',
        'javascript',
        'php',
        'cpp',
        'c',
        'csharp',
      ];

      final Set<String> candidateLangs = <String>{};

      // 1. Check non-empty starter codes in DB
      for (final String l in allSupported) {
        final String? s = starterCodes[l];
        if (s != null && s.trim().isNotEmpty && !isPlaceholder(s)) {
          candidateLangs.add(l);
        }
      }

      // 2. Check declared languages in code_details
      for (final String l in declaredLanguages) {
        if (allSupported.contains(l)) candidateLangs.add(l);
      }

      // 3. Check module stack
      for (final String l in modStackLangs) {
        if (allSupported.contains(l)) candidateLangs.add(l);
      }

      // Determine primary language (prefer module stack language if available)
      String primaryLang = modStackLangs.isNotEmpty
          ? modStackLangs.first
          : (declaredLanguages.isNotEmpty ? declaredLanguages.first : 'java');
      if (!allSupported.contains(primaryLang)) {
        primaryLang = candidateLangs.isNotEmpty ? candidateLangs.first : 'java';
      }
      candidateLangs.add(primaryLang);

      final List<String> finalLanguages = <String>[
        primaryLang,
        ...candidateLangs.where((String l) => l != primaryLang),
      ];

      // Clean default boilerplate templates matching web (no hardcoded solutions)
      const Map<String, String> defaultTemplates = <String, String>{
        'java': 'public class Solution {\n    public static void main(String[] args) {\n        // TODO: Implement solution logic\n    }\n}',
        'python': 'def solve():\n    # TODO: Implement solution logic\n    pass\n\nif __name__ == "__main__":\n    solve()',
        'javascript': 'function solve() {\n  // TODO: Implement solution logic\n}\n\nsolve();',
        'php': '<?php\n\nfunction solve() {\n  // TODO: Implement solution logic\n}\n\nsolve();',
        'cpp': '#include <iostream>\nusing namespace std;\n\nint main() {\n    // TODO: Implement solution logic\n    return 0;\n}',
        'c': '#include <stdio.h>\n\nint main() {\n    // TODO: Implement solution logic\n    return 0;\n}',
        'csharp': 'using System;\n\npublic class Solution {\n    public static void Main(string[] args) {\n        // TODO: Implement solution logic\n    }\n}',
      };

      for (final String lang in finalLanguages) {
        final String? authored = starterCodes[lang];
        if (authored == null || authored.trim().isEmpty || isPlaceholder(authored)) {
          starterCodes[lang] = defaultTemplates[lang] ?? defaultTemplates['java']!;
        }
      }

      final Map<String, String> modelSolutions = <String, String>{
        'java':
            'public class Solution {\n    public static void main(String[] args) {\n        // Solution\n    }\n}',
        'python':
            'def solve():\n    pass\n\nif __name__ == "__main__":\n    solve()',
        'javascript':
            'function solve() {\n}\n\nsolve();',
        'php':
            '<?php\n\nfunction solve() {\n}\n\nsolve();',
      };

      // Mapped test cases
      List<TestCaseModel> testCases = testCaseRows
          .map((Map<String, dynamic> r) => TestCaseModel.fromJson(r))
          .toList();

      // testCases stays empty when none exist in DB — UI handles the sandbox/empty state

      final String rawDesc = actData?['act_description'] as String? ?? '';
      final String richDescription = rawDesc.isNotEmpty
          ? rawDesc
          : '''### Problem Statement

Apply the foundational concepts of this topic by writing a clean, structured program that outputs the expected response.

Your program must compile without syntax errors and pass the validation test cases.

---

### Key Requirements & Formatting

1. Implement your solution logic inside the starter template.
2. Ensure exact casing, spacing, and punctuation in your stdout prints.
3. Do not modify the class or function entry point signatures.
''';

      return PracticeExerciseModel(
        id: exerciseId,
        moduleId: moduleId,
        title: title.isNotEmpty ? title : 'Guided Practice Exercise',
        description: richDescription,
        difficulty: difficulty,
        category: 'Programming Practice',
        targetTime: targetTime,
        targetSpace: targetSpace,
        languages: finalLanguages,
        starterCodes: starterCodes,
        modelSolutions: modelSolutions,
        testCases: testCases,
        isCompleted: isCompleted,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> submitPracticeExercise(
    String userId,
    String moduleId,
    String exerciseId,
    String code,
    String language,
  ) async {
    try {
      String? createdSubId;

      // 1. Insert into submissions table and retrieve generated sub_id
      if (userId.isNotEmpty) {
        try {
          final dynamic inserted = await _supabase
              .from('submissions')
              .insert(<String, dynamic>{
                'user_id': userId,
                'item_id': exerciseId,
                'sub_code': code,
                'sub_language': language.toLowerCase(),
                'sub_status': 'accepted',
                'sub_verdict': <String, dynamic>{
                  'verdict': 'Accepted',
                  'grade': 'A+',
                },
                'sub_submitted_at': DateTime.now().toUtc().toIso8601String(),
              })
              .select('sub_id')
              .maybeSingle();

          if (inserted is Map && inserted['sub_id'] != null) {
            createdSubId = inserted['sub_id'].toString();
          }
        } catch (_) {}
      }

      // 2. Trigger asynchronous on-demand AI ACF evaluation (Go backend -> Web fallback)
      if (createdSubId != null && createdSubId.isNotEmpty) {
        _triggerAcfEvaluationAsync(createdSubId);
      }

      // 2. Compute accurate completion based on total practice activities (1:1 with Web)
      if (userId.isNotEmpty && moduleId.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> tRows = await _supabase
              .from('topics')
              .select('topic_id')
              .eq('track_id', moduleId);

          final List<String> topicIds = tRows
              .map((Map<String, dynamic> t) => t['topic_id'] as String? ?? '')
              .where((String s) => s.isNotEmpty)
              .toList();

          int totalCount = 1;
          final Set<String> topicActIds = <String>{};

          if (topicIds.isNotEmpty) {
            final List<Map<String, dynamic>> aRows = await _supabase
                .from('activities')
                .select('act_id, act_status')
                .filter('topic_id', 'in', topicIds);

            for (final Map<String, dynamic> a in aRows) {
              final String st = (a['act_status'] as String? ?? 'published').toLowerCase();
              if (st != 'hidden') {
                final String aId = a['act_id'] as String? ?? '';
                if (aId.isNotEmpty) topicActIds.add(aId);
              }
            }
          }

          // Also include module-level challenges
          try {
            final List<Map<String, dynamic>> modDirectActs = await _supabase
                .from('activities')
                .select('act_id, act_status')
                .eq('track_id', moduleId);

            for (final Map<String, dynamic> a in modDirectActs) {
              final String st = (a['act_status'] as String? ?? 'published').toLowerCase();
              if (st != 'hidden') {
                final String aId = a['act_id'] as String? ?? '';
                if (aId.isNotEmpty) topicActIds.add(aId);
              }
            }
          } catch (_) {}

          if (topicActIds.isNotEmpty) {
            totalCount = topicActIds.length;
          }

          // Fetch user's accepted submissions
          final List<Map<String, dynamic>> userSubs = await _supabase
              .from('submissions')
              .select('item_id')
              .eq('user_id', userId)
              .inFilter('sub_status', const <String>['accepted', 'passed', 'Accepted', 'Passed']);

          final Set<String> solvedSet = <String>{};
          for (final Map<String, dynamic> r in userSubs) {
            final String? itemId = r['item_id'] as String?;
            if (itemId != null && itemId.isNotEmpty) solvedSet.add(itemId);
          }
          solvedSet.add(exerciseId);

          int solvedCount = 0;
          for (final String aId in topicActIds) {
            if (solvedSet.contains(aId)) solvedCount++;
          }

          final int nextComp = totalCount > 0 ? ((solvedCount / totalCount) * 100).round() : 100;

          await _supabase.from('user_practice_progress').upsert(<String, dynamic>{
            'user_id': userId,
            'track_id': moduleId,
            'upp_completion': nextComp,
            'upp_updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,track_id');

          // Invalidate cache so module detail recomputes immediately
          _moduleDetailsCache.remove(moduleId);

          // Update memory dashboard cache if present
          if (cachedData != null) {
            PathwayModel updateProgress(PathwayModel p) {
              if (p.id == moduleId) {
                return p.copyWith(
                  completion: nextComp,
                  status: nextComp >= 100 ? 'Mastered' : 'In Progress',
                );
              }
              return p;
            }

            cachedData = LearnDashboardData(
              activePathway: cachedData!.activePathway,
              enrolledPathways: cachedData!.enrolledPathways.map(updateProgress).toList(),
              allPathways: cachedData!.allPathways.map(updateProgress).toList(),
              currentStreak: cachedData!.currentStreak,
              totalActiveDays: cachedData!.totalActiveDays,
              easySolved: cachedData!.easySolved + 1,
              mediumSolved: cachedData!.mediumSolved,
              hardSolved: cachedData!.hardSolved,
              recommendedChallenges: cachedData!.recommendedChallenges,
              submissions: cachedData!.submissions,
            );
          }
        } catch (_) {}
      }

      // Signal all cached catalog/dashboard screens to reload fresh progress
      catalogRefreshNotifier.value++;

      return createdSubId ?? 'success';
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PracticeExerciseModel?> getChallengeExercise(
    String moduleId,
    String challengeId,
    String userId,
  ) async {
    try {
      // 1. Fetch from Supabase activities table if valid UUID
      Map<String, dynamic>? actData;
      Map<String, dynamic>? codeData;
      List<Map<String, dynamic>> testCaseRows = <Map<String, dynamic>>[];

      try {
        final List<Map<String, dynamic>> actRows = await _supabase
            .from('activities')
            .select('*, code_details(*), test_cases(*)')
            .eq('act_id', challengeId)
            .limit(1);

        if (actRows.isNotEmpty) {
          final String status =
              (actRows.first['act_status'] as String? ?? 'published').toLowerCase();
          if (status == 'hidden') return null;
          actData = actRows.first;
          final dynamic cd = actData['code_details'];
          if (cd is List && cd.isNotEmpty) {
            codeData = cd.first as Map<String, dynamic>;
          } else if (cd is Map<String, dynamic>) {
            codeData = cd;
          }

          final dynamic tc = actData['test_cases'];
          if (tc is List) {
            testCaseRows = tc.cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {
        // Non-blocking (handles synthetic challenge IDs)
      }

      // Check if user completed this challenge before
      bool isCompleted = false;
      if (userId.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> subRows = await _supabase
              .from('submissions')
              .select('sub_id')
              .eq('user_id', userId)
              .eq('item_id', challengeId)
              .eq('sub_status', 'accepted')
              .limit(1);
          isCompleted = subRows.isNotEmpty;
        } catch (_) {}
      }

      // 2. Derive challenge details or synthesize defensively (matching Web 1:1)
      final String title = actData?['act_title'] as String? ??
          challengeId
              .replaceAll('-', ' ')
              .replaceAllMapped(
                RegExp(r'\b\w'),
                (Match m) => m.group(0)!.toUpperCase(),
              )
              .trim();

      final String difficulty =
          actData?['act_difficulty'] as String? ?? 'Medium';
      final String targetTime =
          codeData?['target_time'] as String? ?? 'O(N)';
      final String targetSpace =
          codeData?['target_space'] as String? ?? 'O(1)';

      // Extract starter codes if present
      final Map<String, String> starterCodes = <String, String>{};
      final dynamic rawStarters = codeData?['starter_codes'];
      if (rawStarters is Map) {
        rawStarters.forEach((dynamic k, dynamic v) {
          if (v != null && v.toString().trim().isNotEmpty) {
            starterCodes[k.toString().toLowerCase()] = v.toString();
          }
        });
      }

      bool isPlaceholder(String val) {
        final String lower = val.trim().toLowerCase();
        return lower.isEmpty ||
            lower == '// write solution here' ||
            lower == '# write solution here' ||
            lower.startsWith('// write solution here') ||
            lower.startsWith('# write solution here');
      }

      // Purge placeholder values from starterCodes map
      starterCodes.removeWhere((String k, String v) => isPlaceholder(v));

      // Determine declared languages strictly from DB code_details.languages column
      final List<String> declaredLanguages = <String>[];
      final dynamic rawLangs = codeData?['languages'];
      if (rawLangs is List) {
        for (final dynamic l in rawLangs) {
          if (l != null && l.toString().trim().isNotEmpty) {
            declaredLanguages.add(l.toString().toLowerCase());
          }
        }
      }

      // Priority 1: Module technology stack
      final List<String> modStackLangs = <String>[];
      if (moduleId.isNotEmpty) {
        final ModuleDetailModel? cachedMod = _moduleDetailsCache[moduleId];
        if (cachedMod != null && cachedMod.stack.isNotEmpty) {
          modStackLangs.addAll(cachedMod.stack);
        } else {
          try {
            final List<Map<String, dynamic>> modRows = await _supabase
                .from('modules')
                .select('mod_stack')
                .eq('mod_id', moduleId)
                .limit(1);
            if (modRows.isNotEmpty) {
              final dynamic modStack = modRows.first['mod_stack'];
              if (modStack is List) {
                for (final dynamic s in modStack) {
                  if (s != null && s.toString().trim().isNotEmpty) {
                    modStackLangs.add(s.toString().trim().toLowerCase());
                  }
                }
              } else if (modStack is String && modStack.trim().isNotEmpty) {
                modStackLangs.addAll(
                  modStack.split(',').map((String s) => s.trim().toLowerCase()).where((String s) => s.isNotEmpty),
                );
              }
            }
          } catch (_) {}
        }
      }

      const List<String> allSupported = <String>[
        'java',
        'python',
        'javascript',
        'php',
        'cpp',
        'c',
        'csharp',
      ];

      final Set<String> candidateLangs = <String>{};

      // 1. Check non-empty starter codes in DB
      for (final String l in allSupported) {
        final String? s = starterCodes[l];
        if (s != null && s.trim().isNotEmpty && !isPlaceholder(s)) {
          candidateLangs.add(l);
        }
      }

      // 2. Check declared languages in code_details
      for (final String l in declaredLanguages) {
        if (allSupported.contains(l)) candidateLangs.add(l);
      }

      // 3. Check module stack
      for (final String l in modStackLangs) {
        if (allSupported.contains(l)) candidateLangs.add(l);
      }

      // Determine primary language (prefer module stack language if available)
      String primaryLang = modStackLangs.isNotEmpty
          ? modStackLangs.first
          : (declaredLanguages.isNotEmpty ? declaredLanguages.first : 'java');
      if (!allSupported.contains(primaryLang)) {
        primaryLang = candidateLangs.isNotEmpty ? candidateLangs.first : 'java';
      }
      candidateLangs.add(primaryLang);

      final List<String> finalLanguages = <String>[
        primaryLang,
        ...candidateLangs.where((String l) => l != primaryLang),
      ];

      // Default fallback starter codes matching Web challenge template (clean TODO boilerplate)
      const Map<String, String> defaultTemplates = <String, String>{
        'java': 'public class Solution {\n    public static void main(String[] args) {\n        // TODO: Implement solution logic\n    }\n}',
        'python': 'def solve():\n    # TODO: Implement solution logic\n    pass\n\nif __name__ == "__main__":\n    solve()',
        'javascript': 'function solve() {\n  // TODO: Implement solution logic\n}\n\nsolve();',
        'php': '<?php\n\nfunction solve() {\n  // TODO: Implement solution logic\n}\n\nsolve();',
        'cpp': '#include <iostream>\nusing namespace std;\n\nint main() {\n    // TODO: Implement solution logic\n    return 0;\n}',
        'c': '#include <stdio.h>\n\nint main() {\n    // TODO: Implement solution logic\n    return 0;\n}',
        'csharp': 'using System;\n\npublic class Solution {\n    public static void Main(string[] args) {\n        // TODO: Implement solution logic\n    }\n}',
      };

      for (final String lang in finalLanguages) {
        final String? authored = starterCodes[lang];
        if (authored == null || authored.trim().isEmpty || isPlaceholder(authored)) {
          starterCodes[lang] = defaultTemplates[lang] ?? defaultTemplates['java']!;
        }
      }

      final Map<String, String> modelSolutions = <String, String>{
        'java':
            'public class Solution {\n    public static void main(String[] args) {\n        // Solution\n    }\n}',
        'python':
            'def solve():\n    pass\n\nif __name__ == "__main__":\n    solve()',
        'javascript':
            'function solve() {\n}\n\nsolve();',
        'php':
            '<?php\n\nfunction solve() {\n}\n\nsolve();',
      };

      // Mapped test cases
      List<TestCaseModel> testCases = testCaseRows
          .map((Map<String, dynamic> r) => TestCaseModel.fromJson(r))
          .toList();

      // testCases stays empty when none exist in DB — UI handles the sandbox/empty state

      final String rawDesc = actData?['act_description'] as String? ?? '';
      final String richDescription = rawDesc.isNotEmpty
          ? rawDesc
          : '''### Challenge Statement

Solve this algorithmic challenge adhering to strict SLA execution limits.

Ensure your code compiles cleanly and satisfies the validation test suite.
''';

      return PracticeExerciseModel(
        id: challengeId,
        moduleId: moduleId,
        title: title.isNotEmpty ? title : 'Skill Challenge Benchmark',
        description: richDescription,
        difficulty: difficulty,
        category: 'Algorithm Challenge',
        targetTime: targetTime,
        targetSpace: targetSpace,
        languages: finalLanguages,
        starterCodes: starterCodes,
        modelSolutions: modelSolutions,
        testCases: testCases,
        isCompleted: isCompleted,
        acceptanceRate: '94.2%',
        isChallenge: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> submitChallengeExercise(
    String userId,
    String moduleId,
    String challengeId,
    String code,
    String language,
  ) async {
    try {
      String? createdSubId;

      // 1. Insert into submissions table (using live schema: item_id, sub_status, sub_verdict jsonb)
      if (userId.isNotEmpty) {
        try {
          final dynamic inserted = await _supabase
              .from('submissions')
              .insert(<String, dynamic>{
                'user_id': userId,
                'item_id': challengeId,
                'sub_code': code,
                'sub_language': language.toLowerCase(),
                'sub_status': 'accepted',
                'sub_verdict': <String, dynamic>{
                  'verdict': 'Accepted',
                  'grade': 'A+',
                },
                'sub_submitted_at': DateTime.now().toUtc().toIso8601String(),
              })
              .select('sub_id')
              .maybeSingle();

          if (inserted is Map && inserted['sub_id'] != null) {
            createdSubId = inserted['sub_id'].toString();
          }
        } catch (_) {}
      }

      // 2. Trigger asynchronous on-demand AI ACF evaluation (Go backend -> Web fallback)
      if (createdSubId != null && createdSubId.isNotEmpty) {
        _triggerAcfEvaluationAsync(createdSubId);
      }

      // 3. Invalidate cache so module detail recomputes immediately
      if (moduleId.isNotEmpty) {
        _moduleDetailsCache.remove(moduleId);
      }

      return createdSubId ?? 'success';
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SubmissionHistoryModel>> getExerciseSubmissions({
    required String userId,
    required String moduleId,
    required String exerciseId,
  }) async {
    try {
      if (userId.isEmpty || exerciseId.isEmpty) return <SubmissionHistoryModel>[];

      List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      try {
        rows = await _supabase
            .from('submissions')
            .select('*, ai_audits(audit_findings)')
            .eq('user_id', userId)
            .eq('item_id', exerciseId)
            .order('sub_submitted_at', ascending: false);
      } catch (_) {
        rows = await _supabase
            .from('submissions')
            .select('*')
            .eq('user_id', userId)
            .eq('item_id', exerciseId)
            .order('sub_submitted_at', ascending: false);
      }

      return rows
          .map((Map<String, dynamic> r) => SubmissionHistoryModel.fromJson(r))
          .toList();
    } catch (_) {
      return <SubmissionHistoryModel>[];
    }
  }

  @override
  Future<List<DashboardSubmission>> getUserSubmissions(String userId) async {
    // 1. Query Go Backend API first (joined with activities, modules, and ai_audits acf_score)
    try {
      final dynamic apiResult = await apiClient.get('/api/submissions');
      final dynamic items =
          apiResult is Map ? (apiResult['data'] ?? apiResult) : apiResult;
      if (items is List && items.isNotEmpty) {
        final List<DashboardSubmission> list = <DashboardSubmission>[];
        for (final dynamic item in items) {
          if (item is Map) {
            final Map<String, dynamic> row = Map<String, dynamic>.from(item);
            list.add(
              DashboardSubmission.fromDatabase(
                row: row,
                title: row['challenge_title']?.toString(),
                moduleId: row['module_id']?.toString(),
                moduleTitle: row['module_title']?.toString(),
                difficulty: row['challenge_difficulty']?.toString(),
                acfScore: row['acf_score'],
              ),
            );
          }
        }
        if (list.isNotEmpty) {
          if (cachedData != null) {
            cachedData = cachedData!.copyWith(submissions: list);
          }
          return list;
        }
      }
    } catch (e) {
      debugPrint(
        'apiClient.get /api/submissions failed, using Supabase fallback: $e',
      );
    }

    // 2. Direct Supabase query fallback (with joined ai_audits)
    try {
      final LearnDashboardData dashData = await getLearnDashboardData(userId);
      return dashData.submissions;
    } catch (_) {
      return cachedData?.submissions ?? const <DashboardSubmission>[];
    }
  }

  @override
  Future<List<ModuleReviewModel>> getModuleReviews(String moduleId) async {
    try {
      if (moduleId.isEmpty) return <ModuleReviewModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('module_reviews')
          .select('*, profiles:user_id(user_first_name, user_last_name, user_avatar_url)')
          .eq('track_id', moduleId)
          .order('review_created_at', ascending: false);

      return rows
          .map((Map<String, dynamic> r) => ModuleReviewModel.fromJson(r))
          .toList();
    } catch (_) {
      return <ModuleReviewModel>[];
    }
  }

  @override
  Future<bool> submitModuleReview({
    required String moduleId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    try {
      if (moduleId.isEmpty || userId.isEmpty || rating < 1 || rating > 5) {
        return false;
      }

      // Check if user already submitted a review for this track
      final List<Map<String, dynamic>> existing = await _supabase
          .from('module_reviews')
          .select('review_id')
          .eq('track_id', moduleId)
          .eq('user_id', userId)
          .limit(1);

      if (existing.isNotEmpty) {
        final String reviewId = existing.first['review_id'] as String;
        await _supabase.from('module_reviews').update(<String, dynamic>{
          'rating': rating,
          'comment': comment.trim(),
          'review_updated_at': DateTime.now().toIso8601String(),
        }).eq('review_id', reviewId);
      } else {
        await _supabase.from('module_reviews').insert(<String, dynamic>{
          'track_id': moduleId,
          'user_id': userId,
          'rating': rating,
          'comment': comment.trim(),
          'review_created_at': DateTime.now().toIso8601String(),
          'review_updated_at': DateTime.now().toIso8601String(),
        });
      }

      return true;
    } catch (e, st) {
      debugPrint('submitModuleReview error: $e\n$st');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getActiveModuleReport({
    required String moduleId,
    required String userId,
    String? activityId,
  }) async {
    try {
      if (moduleId.isEmpty || userId.isEmpty) return null;

      var query = _supabase
          .from('module_reports')
          .select('report_id, report_reason, report_details')
          .eq('mod_id', moduleId)
          .eq('user_id', userId)
          .inFilter('report_status', <String>['pending', 'investigating']);

      if (activityId != null && activityId.isNotEmpty) {
        query = query.eq('act_id', activityId);
      }

      final List<Map<String, dynamic>> rows = await query.limit(1);

      if (rows.isNotEmpty) {
        return rows.first;
      }
      return null;
    } catch (e) {
      debugPrint('getActiveModuleReport error: $e');
      return null;
    }
  }

  @override
  Future<bool> submitModuleReport({
    required String moduleId,
    required String userId,
    required String reason,
    required String details,
    String? activityId,
  }) async {
    try {
      if (moduleId.isEmpty || userId.isEmpty || details.trim().isEmpty) {
        return false;
      }

      // Check if an active report already exists (idempotency / deduplication)
      var query = _supabase
          .from('module_reports')
          .select('report_id')
          .eq('mod_id', moduleId)
          .eq('user_id', userId)
          .inFilter('report_status', <String>['pending', 'investigating']);

      if (activityId != null && activityId.isNotEmpty) {
        query = query.eq('act_id', activityId);
      }

      final List<Map<String, dynamic>> existing = await query.limit(1);

      if (existing.isNotEmpty) {
        final String reportId = existing.first['report_id'] as String;
        await _supabase.from('module_reports').update(<String, dynamic>{
          'report_reason': reason,
          'report_details': details.trim(),
          if (activityId != null && activityId.isNotEmpty) 'act_id': activityId,
          'report_created_at': DateTime.now().toIso8601String(),
        }).eq('report_id', reportId);
      } else {
        await _supabase.from('module_reports').insert(<String, dynamic>{
          'mod_id': moduleId,
          'user_id': userId,
          if (activityId != null && activityId.isNotEmpty) 'act_id': activityId,
          'report_reason': reason,
          'report_details': details.trim(),
          'report_status': 'pending',
          'report_created_at': DateTime.now().toIso8601String(),
        });
      }

      return true;
    } catch (e, st) {
      debugPrint('submitModuleReport error: $e\n$st');
      return false;
    }
  }

  @override
  Future<List<RoomModel>> getLearnerRooms(String userId) async {
    try {
      // 1. Fetch memberships where user is an enrolled learner (active or pending)
      final List<Map<String, dynamic>> memberships = await _supabase
          .from('hub_members')
          .select('hub_id, status, enrolled_at, requested_at, joined_via, role')
          .eq('learner_id', userId)
          .neq('status', 'rejected')
          .order('enrolled_at', ascending: false);

      final Map<String, Map<String, dynamic>> membershipByRoomId =
          <String, Map<String, dynamic>>{};
      for (final Map<String, dynamic> m in memberships) {
        final String rId = m['hub_id'] as String? ?? '';
        if (rId.isNotEmpty) {
          membershipByRoomId[rId] = m;
        }
      }

      // 2. Fetch hubs created by this user as a mentor
      final List<Map<String, dynamic>> mentorRooms = await _supabase
          .from('hubs')
          .select(
            'id, name, section, join_code, target_language, primary_module_id, description, is_archived, created_at, mentor_id',
          )
          .eq('mentor_id', userId)
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      // 3. Fetch hubs where user is an enrolled learner (if not already fetched as mentor)
      final Set<String> enrolledRoomIds = membershipByRoomId.keys.toSet();
      final Set<String> mentorRoomIds =
          mentorRooms.map((Map<String, dynamic> r) => r['id'] as String).toSet();
      final List<String> neededEnrolledIds =
          enrolledRoomIds.difference(mentorRoomIds).toList();

      List<Map<String, dynamic>> enrolledRooms = <Map<String, dynamic>>[];
      if (neededEnrolledIds.isNotEmpty) {
        enrolledRooms = await _supabase
            .from('hubs')
            .select(
              'id, name, section, join_code, target_language, primary_module_id, description, is_archived, created_at, mentor_id',
            )
            .inFilter('id', neededEnrolledIds)
            .eq('is_archived', false);
      }

      // Combine all hubs (mentor-managed hubs + enrolled hubs)
      final List<Map<String, dynamic>> allRooms = <Map<String, dynamic>>[
        ...mentorRooms,
        ...enrolledRooms,
      ];

      if (allRooms.isEmpty) {
        return <RoomModel>[];
      }

      final List<String> allRoomIds = allRooms
          .map((Map<String, dynamic> r) => r['id'] as String? ?? '')
          .where((String id) => id.isNotEmpty)
          .toList();

      // 4. Fetch attached modules via hub_modules
      final List<Map<String, dynamic>> rmRows = await _supabase
          .from('hub_modules')
          .select('''
            hub_id,
            display_order,
            module_id,
            modules (
              mod_id,
              mod_title,
              mod_description,
              mod_stack,
              mod_status
            )
          ''')
          .inFilter('hub_id', allRoomIds)
          .order('display_order', ascending: true);

      final List<String> attachedModIds = rmRows
          .map((Map<String, dynamic> r) => r['module_id'] as String? ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet()
          .toList();

      // 5. Fetch topics & activities count per module (matching web 1:1)
      final Map<String, int> topicCountMap = <String, int>{};
      final Map<String, int> activityCountMap = <String, int>{};
      final Map<String, List<String>> moduleActIdsMap = <String, List<String>>{};

      if (attachedModIds.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> topicsData = await _supabase
              .from('topics')
              .select('track_id, topic_id, activities (act_id)')
              .inFilter('track_id', attachedModIds);

          for (final Map<String, dynamic> t in topicsData) {
            final String trackId = t['track_id'] as String? ?? '';
            topicCountMap[trackId] = (topicCountMap[trackId] ?? 0) + 1;

            final dynamic rawActs = t['activities'];
            final List<dynamic> acts = rawActs is List ? rawActs : <dynamic>[];
            activityCountMap[trackId] =
                (activityCountMap[trackId] ?? 0) + acts.length;

            for (final dynamic a in acts) {
              if (a is Map && a['act_id'] != null) {
                moduleActIdsMap
                    .putIfAbsent(trackId, () => <String>[])
                    .add(a['act_id'].toString());
              }
            }
          }
        } catch (_) {
          // Non-blocking
        }
      }

      // Group modules by hub_id
      final Map<String, List<RoomModuleSummary>> modulesMap =
          <String, List<RoomModuleSummary>>{};
      for (final Map<String, dynamic> r in rmRows) {
        final String rId = r['hub_id'] as String? ?? '';
        final dynamic rawMod = r['modules'];
        final Map<String, dynamic>? modData = rawMod is List
            ? (rawMod.isNotEmpty ? rawMod.first as Map<String, dynamic> : null)
            : rawMod as Map<String, dynamic>?;

        if (modData != null) {
          final String mId = modData['mod_id'] as String? ?? '';
          modulesMap.putIfAbsent(rId, () => <RoomModuleSummary>[]).add(
                RoomModuleSummary.fromJson(<String, dynamic>{
                  ...modData,
                  'topicsCount': topicCountMap[mId] ?? 0,
                  'activitiesCount': activityCountMap[mId] ?? 0,
                  'displayOrder': r['display_order'] ?? 0,
                }),
              );
        }
      }

      // 5b. Fetch attached assessments from hub_assessments with resilient fallback
      final Map<String, List<RoomAssessmentSummary>> assessmentsMap =
          <String, List<RoomAssessmentSummary>>{};
      try {
        final List<Map<String, dynamic>> haRows = await _supabase
            .from('hub_assessments')
            .select('''
              hub_id,
              assessment_id,
              display_order,
              assessments (
                id,
                title,
                description,
                stack,
                difficulty,
                duration_mins,
                passing_score,
                status,
                assessment_challenges (id)
              )
            ''')
            .inFilter('hub_id', allRoomIds)
            .order('display_order', ascending: true);

        final List<String> assessIds = haRows
            .map((Map<String, dynamic> r) => r['assessment_id'] as String? ?? '')
            .where((String id) => id.isNotEmpty)
            .toSet()
            .toList();

        final Map<String, Map<String, dynamic>> userLibMap =
            <String, Map<String, dynamic>>{};
        if (assessIds.isNotEmpty) {
          try {
            final List<Map<String, dynamic>> userLibRows = await _supabase
                .from('user_assessment_library')
                .select('assessment_id, status, best_score')
                .eq('user_id', userId)
                .inFilter('assessment_id', assessIds);

            for (final Map<String, dynamic> ul in userLibRows) {
              final String aid = ul['assessment_id'] as String? ?? '';
              if (aid.isNotEmpty) {
                userLibMap[aid] = ul;
              }
            }
          } catch (_) {
            // Non-blocking
          }
        }

        for (final Map<String, dynamic> r in haRows) {
          final String rId = r['hub_id'] as String? ?? '';
          final dynamic rawAssess = r['assessments'];
          final Map<String, dynamic>? assessData = rawAssess is List
              ? (rawAssess.isNotEmpty ? rawAssess.first as Map<String, dynamic> : null)
              : rawAssess as Map<String, dynamic>?;

          if (assessData != null) {
            final String aId = assessData['id'] as String? ?? '';
            final dynamic rawChallenges = assessData['assessment_challenges'];
            final int cCount = rawChallenges is List ? rawChallenges.length : 0;
            final Map<String, dynamic>? userAttempt = userLibMap[aId];

            assessmentsMap.putIfAbsent(rId, () => <RoomAssessmentSummary>[]).add(
                  RoomAssessmentSummary.fromJson(<String, dynamic>{
                    ...assessData,
                    'challengesCount': cCount,
                    'displayOrder': r['display_order'] ?? 0,
                    'userStatus': userAttempt?['status'] ?? 'not_started',
                    'userBestScore': userAttempt?['best_score'],
                  }),
                );
          }
        }
      } catch (_) {
        // Table may not exist yet or offline fallback
      }

      // 6. Fetch mentor profiles
      final List<String> mentorIds = allRooms
          .map((Map<String, dynamic> r) => r['mentor_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> mentorProfiles =
          <String, Map<String, dynamic>>{};
      if (mentorIds.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> mentors = await _supabase
              .from('profiles')
              .select(
                'user_id, user_first_name, user_last_name, user_avatar_url, user_email',
              )
              .inFilter('user_id', mentorIds);

          for (final Map<String, dynamic> men in mentors) {
            final String uId = men['user_id'] as String? ?? '';
            final String fName = men['user_first_name'] as String? ?? '';
            final String lName = men['user_last_name'] as String? ?? '';
            final String email = men['user_email'] as String? ?? '';
            final String fullName = '$fName $lName'.trim();
            mentorProfiles[uId] = <String, dynamic>{
              'name': fullName.isNotEmpty ? fullName : (email.split('@').first),
              'avatarUrl': men['user_avatar_url'],
              'email': email,
            };
          }
        } catch (_) {
          // Profiles might be restricted by RLS
        }
      }

      // 7. Fetch user's completed submissions for progress calculation
      final Set<String> passedActivityIds = <String>{};
      try {
        final List<Map<String, dynamic>> subs = await _supabase
            .from('submissions')
            .select('item_id')
            .eq('user_id', userId)
            .inFilter('sub_status', <String>[
          'accepted',
          'passed',
          'Accepted',
          'Passed',
        ]);

        for (final Map<String, dynamic> s in subs) {
          final String? itemId = s['item_id'] as String?;
          if (itemId != null && itemId.isNotEmpty) {
            passedActivityIds.add(itemId);
          }
        }
      } catch (_) {
        // Non-blocking
      }

      // 8. Build final RoomModel list
      return allRooms.map((Map<String, dynamic> room) {
        final String rId = room['id'] as String? ?? '';
        final String mId = room['mentor_id'] as String? ?? '';
        final Map<String, dynamic>? mentor = mentorProfiles[mId];
        final Map<String, dynamic>? membership = membershipByRoomId[rId];

        // Determine status: if membership exists, use membership status; if user is mentor, it's active
        final String status = membership?['status'] as String? ??
            (mId == userId ? 'active' : 'active');

        // Calculate completed activities count in this room
        final List<RoomModuleSummary> roomMods =
            modulesMap[rId] ?? const <RoomModuleSummary>[];
        int completedActivitiesCount = 0;
        for (final RoomModuleSummary mod in roomMods) {
          final List<String> actIds = moduleActIdsMap[mod.id] ?? <String>[];
          for (final String actId in actIds) {
            if (passedActivityIds.contains(actId)) {
              completedActivitiesCount++;
            }
          }
        }

        return RoomModel(
          id: rId,
          name: room['name'] as String? ?? 'Room',
          section: room['section'] as String? ?? 'General',
          joinCode: room['join_code'] as String? ?? '',
          targetLanguage: room['target_language'] as String? ?? 'python',
          description: room['description'] as String? ?? '',
          status: status,
          joinedVia: membership?['joined_via'] as String? ?? 'code',
          mentorName: mentor?['name'] as String? ?? 'Mentor',
          mentorEmail: mentor?['email'] as String?,
          mentorAvatarUrl: mentor?['avatarUrl'] as String?,
          curriculumModules: roomMods,
          assessments: assessmentsMap[rId] ?? const <RoomAssessmentSummary>[],
          completedActivitiesCount: completedActivitiesCount,
          enrolledAt: membership?['enrolled_at'] as String? ??
              room['created_at'] as String?,
          requestedAt: membership?['requested_at'] as String?,
          isArchived: room['is_archived'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('getLearnerRooms error: $e');
      return <RoomModel>[];
    }
  }

  @override
  Future<Map<String, dynamic>> joinRoom({
    required String code,
    required String userId,
  }) async {
    final String cleanCode = code.trim().toUpperCase();

    // 1. Attempt API Gateway POST
    try {
      final dynamic apiResult = await apiClient.post(
        '/api/classrooms/join',
        body: <String, dynamic>{'code': cleanCode},
      );
      if (apiResult is Map) {
        return Map<String, dynamic>.from(apiResult);
      }
    } catch (e) {
      debugPrint('apiClient.post /api/classrooms/join failed, using direct fallback: $e');
    }

    // 2. Direct Supabase Fallback
    try {
      final List<Map<String, dynamic>> rooms = await _supabase
          .from('hubs')
          .select('id, name, section, join_code, target_language, mentor_id, is_archived')
          .eq('join_code', cleanCode)
          .limit(1);

      if (rooms.isEmpty) {
        return <String, dynamic>{
          'success': false,
          'error': 'No active room found with code "$cleanCode". Please check with your mentor.',
        };
      }

      final Map<String, dynamic> room = rooms.first;
      if (room['is_archived'] == true) {
        return <String, dynamic>{
          'success': false,
          'error': 'This room has been archived by the mentor.',
        };
      }

      if (room['mentor_id'] == userId) {
        return <String, dynamic>{
          'success': false,
          'error': 'You are the creator of this room.',
        };
      }

      // Check existing membership
      final List<Map<String, dynamic>> existing = await _supabase
          .from('hub_members')
          .select('id, status')
          .eq('hub_id', room['id'] as String)
          .eq('learner_id', userId)
          .limit(1);

      if (existing.isNotEmpty) {
        final String status = existing.first['status'] as String? ?? 'active';
        if (status == 'active') {
          return <String, dynamic>{
            'success': true,
            'status': 'active',
            'alreadyEnrolled': true,
            'message': 'You are already enrolled in this room!',
            'classroomId': room['id'],
          };
        }
        if (status == 'pending') {
          return <String, dynamic>{
            'success': true,
            'status': 'pending',
            'isPending': true,
            'message': 'You have already requested admission for this room.',
            'classroomId': room['id'],
          };
        }
      }

      // Insert pending membership request
      await _supabase.from('hub_members').insert(<String, dynamic>{
        'hub_id': room['id'],
        'learner_id': userId,
        'role': 'learner',
        'joined_via': 'code',
        'status': 'pending',
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      });

      return <String, dynamic>{
        'success': true,
        'status': 'pending',
        'isPending': true,
        'message': 'Admission request sent! Waiting for your mentor to admit you.',
        'classroom': <String, dynamic>{
          'id': room['id'],
          'name': room['name'],
          'section': room['section'],
          'targetLanguage': room['target_language'],
        },
      };
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'error': e.toString(),
      };
    }
  }

  @override
  Future<bool> acceptRoomInvitation(String roomId) async {
    try {
      final dynamic res = await apiClient.patch(
        '/api/classrooms/$roomId/members',
        body: <String, dynamic>{'action': 'accept_invite'},
      );
      if (res is Map && res['success'] == true) return true;
    } catch (_) {}

    try {
      final String? uid = _supabase.auth.currentUser?.id;
      if (uid == null) return false;
      await _supabase
          .from('hub_members')
          .update(<String, dynamic>{
            'status': 'active',
            'enrolled_at': DateTime.now().toIso8601String(),
          })
          .eq('hub_id', roomId)
          .eq('learner_id', uid);

      try {
        await _supabase
            .from('notifications')
            .update(<String, dynamic>{'notif_is_read': true})
            .eq('user_id', uid)
            .eq('notif_source_id', roomId);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('acceptRoomInvitation fallback error: $e');
      return false;
    }
  }

  @override
  Future<bool> declineRoomInvitation(String roomId) async {
    try {
      final dynamic res = await apiClient.patch(
        '/api/classrooms/$roomId/members',
        body: <String, dynamic>{'action': 'decline_invite'},
      );
      if (res is Map && res['success'] == true) return true;
    } catch (_) {}

    try {
      final String? uid = _supabase.auth.currentUser?.id;
      if (uid == null) return false;
      await _supabase
          .from('hub_members')
          .delete()
          .eq('hub_id', roomId)
          .eq('learner_id', uid);

      try {
        await _supabase
            .from('notifications')
            .update(<String, dynamic>{'notif_is_read': true})
            .eq('user_id', uid)
            .eq('notif_source_id', roomId);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('declineRoomInvitation fallback error: $e');
      return false;
    }
  }

  @override
  Future<ActivitySubmissionReviewModel?> getSubmissionReview(
    String submissionId, {
    DashboardSubmission? cachedSubmission,
  }) async {
    Map<String, dynamic>? subRow;
    AcfEvaluationModel? acfEvaluation;
    MentorFeedbackModel? mentorFeedback;

    // 1. Fetch feedback via Go Backend API
    try {
      final dynamic apiFeedback =
          await apiClient.get('/api/submissions/$submissionId/feedback');
      if (apiFeedback is Map) {
        final Map<String, dynamic> fbMap =
            Map<String, dynamic>.from(apiFeedback);
        if (fbMap.containsKey('acf_composite_score') ||
            fbMap.containsKey('correctness')) {
          acfEvaluation = AcfEvaluationModel.fromJson(fbMap);
        }
      }
    } catch (_) {
      // Non-blocking fallback to Supabase
    }

    // 2. Fetch submission record if not already available or to enrich code/verdict
    try {
      final dynamic subData = await _supabase
          .from('submissions')
          .select('*')
          .eq('sub_id', submissionId)
          .maybeSingle();

      if (subData is Map) {
        subRow = Map<String, dynamic>.from(subData);
      }
    } catch (_) {
      // Non-blocking
    }

    if (subRow == null && cachedSubmission == null) {
      return null;
    }

    final String itemId = subRow?['item_id']?.toString() ??
        cachedSubmission?.itemId ??
        '';
    final String code = subRow?['sub_code']?.toString() ??
        cachedSubmission?.code ??
        '';
    final String language = subRow?['sub_language']?.toString() ??
        cachedSubmission?.language ??
        'java';
    final String status = subRow?['sub_status']?.toString() ??
        cachedSubmission?.status ??
        'accepted';

    String verdict = 'Accepted';
    String? grade;
    final dynamic rawVerdict = subRow?['sub_verdict'];
    if (rawVerdict is Map) {
      final Map<dynamic, dynamic> vMap = rawVerdict;
      verdict = vMap['verdict']?.toString() ?? 'Accepted';
      grade = vMap['grade']?.toString();
    } else if (rawVerdict is String && rawVerdict.trim().isNotEmpty) {
      verdict = rawVerdict;
    } else if (cachedSubmission != null) {
      verdict = cachedSubmission.verdict.isNotEmpty
          ? cachedSubmission.verdict
          : 'Accepted';
      grade = cachedSubmission.score != null ? '${cachedSubmission.score}%' : null;
    }

    final DateTime submittedAt = subRow?['sub_submitted_at'] != null
        ? (DateTime.tryParse(subRow!['sub_submitted_at'].toString()) ??
            cachedSubmission?.submittedAt ??
            DateTime.now())
        : (cachedSubmission?.submittedAt ?? DateTime.now());

    // 3. Fetch activity metadata
    String title = cachedSubmission?.title ?? 'Coding Practice';
    String description = '';
    String difficulty = cachedSubmission?.difficulty ?? 'Easy';
    String targetTime = 'O(1)';
    String targetSpace = 'O(1)';
    String topicId = '';

    if (itemId.isNotEmpty) {
      try {
        final dynamic actData = await _supabase
            .from('activities')
            .select('act_title, act_description, act_difficulty, topic_id, code_details(target_time, target_space)')
            .eq('act_id', itemId)
            .maybeSingle();

        if (actData is Map) {
          final Map<String, dynamic> actMap =
              Map<String, dynamic>.from(actData);
          title = actMap['act_title']?.toString() ?? title;
          description = actMap['act_description']?.toString() ?? '';
          difficulty = actMap['act_difficulty']?.toString() ?? difficulty;
          topicId = actMap['topic_id']?.toString() ?? '';

          if (actMap['code_details'] is Map) {
            final Map<dynamic, dynamic> cd =
                actMap['code_details'] as Map<dynamic, dynamic>;
            targetTime = cd['target_time']?.toString() ?? targetTime;
            targetSpace = cd['target_space']?.toString() ?? targetSpace;
          }
        }
      } catch (_) {
        // Non-blocking
      }
    }

    // 4. Fetch module metadata via topic
    String moduleId = cachedSubmission?.moduleId ?? '';
    String moduleTitle = cachedSubmission?.module ?? 'Practice Activity';

    if (topicId.isNotEmpty) {
      try {
        final dynamic topicData = await _supabase
            .from('topics')
            .select('track_id, topic_title')
            .eq('topic_id', topicId)
            .maybeSingle();

        if (topicData is Map) {
          final Map<String, dynamic> topicMap =
              Map<String, dynamic>.from(topicData);
          final String trackId = topicMap['track_id']?.toString() ?? '';
          if (trackId.isNotEmpty) {
            moduleId = trackId;
            final dynamic modData = await _supabase
                .from('modules')
                .select('mod_id, mod_title')
                .eq('mod_id', trackId)
                .maybeSingle();

            if (modData is Map) {
              final Map<String, dynamic> modMap =
                  Map<String, dynamic>.from(modData);
              moduleTitle = modMap['mod_title']?.toString() ?? moduleTitle;
            }
          }
        }
      } catch (_) {
        // Non-blocking
      }
    }

    // 5. Fetch ai_audits directly from Supabase if not loaded via Go backend
    if (acfEvaluation == null) {
      try {
        final dynamic auditData = await _supabase
            .from('ai_audits')
            .select('audit_findings, audit_is_flagged, audit_audited_at')
            .eq('sub_id', submissionId)
            .order('audit_audited_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (auditData is Map && auditData['audit_findings'] is Map) {
          final Map<String, dynamic> findings =
              Map<String, dynamic>.from(auditData['audit_findings'] as Map<dynamic, dynamic>);
          acfEvaluation = AcfEvaluationModel.fromJson(
            findings,
            defaultTime: targetTime,
            defaultSpace: targetSpace,
          );
        }
      } catch (_) {
        // Non-blocking
      }
    }

    // 5.5. On-Demand Fallback: Request feedback from Web API (evaluates via Gemini and persists to ai_audits)
    if (acfEvaluation == null) {
      try {
        final dynamic webFeedback =
            await apiClient.getWeb('/api/submissions/$submissionId/feedback');
        if (webFeedback is Map) {
          final Map<String, dynamic> fbMap =
              Map<String, dynamic>.from(webFeedback);
          if (fbMap.containsKey('acf_composite_score') ||
              fbMap.containsKey('correctness')) {
            acfEvaluation = AcfEvaluationModel.fromJson(
              fbMap,
              defaultTime: targetTime,
              defaultSpace: targetSpace,
            );
          }
        }
      } catch (_) {
        // Non-blocking
      }
    }

    // 6. Fetch published mentor review feedback if present
    try {
      final dynamic fbData = await _supabase
          .from('submission_feedback')
          .select('*, profiles:mentor_id(user_first_name, user_last_name, user_avatar_url)')
          .eq('submission_id', submissionId)
          .eq('status', 'published')
          .maybeSingle();

      if (fbData is Map) {
        mentorFeedback = MentorFeedbackModel.fromJson(
          Map<String, dynamic>.from(fbData),
        );
      }
    } catch (_) {
      // Non-blocking
    }

    // 7. Graceful fallback if ACF evaluation still null
    if (acfEvaluation == null) {
      final double score = cachedSubmission?.score?.toDouble() ?? 95.0;
      acfEvaluation = AcfEvaluationModel.fallback(
        score: score,
        verdict: verdict,
        language: language,
        defaultTime: targetTime,
        defaultSpace: targetSpace,
      );
    }

    return ActivitySubmissionReviewModel(
      submissionId: submissionId,
      itemId: itemId,
      title: title,
      moduleTitle: moduleTitle,
      moduleId: moduleId,
      difficulty: difficulty,
      language: language,
      submittedCode: code,
      status: status,
      verdict: verdict,
      grade: grade,
      submittedAt: submittedAt,
      description: description,
      targetTime: targetTime,
      targetSpace: targetSpace,
      acfEvaluation: acfEvaluation,
      mentorFeedback: mentorFeedback,
    );
  }

  /// Triggers asynchronous ACF evaluation: first trying Go gateway, then falling back to Web API
  /// (which runs Gemini Flash CoT and persists findings directly to public.ai_audits in Supabase).
  void _triggerAcfEvaluationAsync(String subId) {
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
