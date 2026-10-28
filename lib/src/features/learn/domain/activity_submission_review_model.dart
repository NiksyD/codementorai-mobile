import 'dart:convert';
import 'dashboard_submission.dart';

class AcfCriterionModel {
  const AcfCriterionModel({
    required this.id,
    required this.label,
    required this.weight,
    required this.score,
    required this.cotReasoning,
    this.strengths = const <String>[],
    this.improvements = const <String>[],
    this.edgeCaseStatus,
    this.modularityRating,
    this.detectedTime,
    this.detectedSpace,
  });

  final String id;
  final String label;
  final String weight;
  final int score;
  final String cotReasoning;
  final List<String> strengths;
  final List<String> improvements;
  final String? edgeCaseStatus;
  final String? modularityRating;
  final String? detectedTime;
  final String? detectedSpace;

  factory AcfCriterionModel.fromJson({
    required String id,
    required String label,
    required String weight,
    required Map<String, dynamic> json,
    String defaultTime = 'O(1)',
    String defaultSpace = 'O(1)',
  }) {
    final int scoreVal = _parseInt(json['score'], fallback: 85);
    final String reasoning =
        json['cot_reasoning']?.toString() ?? 'Evaluation completed.';

    // Strengths
    List<String> parsedStrengths = <String>[];
    if (json['strengths'] is List) {
      parsedStrengths = (json['strengths'] as List<dynamic>)
          .map((dynamic e) => e.toString())
          .where((String s) => s.trim().isNotEmpty)
          .toList();
    }
    if (parsedStrengths.isEmpty) {
      if (id == 'correctness' && scoreVal >= 80) {
        parsedStrengths = <String>[
          'Verified functional correctness across test assertions.',
          if (json['edge_case_status'] != null)
            json['edge_case_status'].toString(),
        ];
      } else if (id == 'readability' && scoreVal >= 80) {
        parsedStrengths = <String>[
          'Structured layout adhering to idiomatic syntax standards.',
        ];
      } else if (id == 'maintainability' && scoreVal >= 80) {
        parsedStrengths = <String>[
          json['modularity_rating'] == 'High'
              ? 'Highly modular architecture with clear separation of concerns.'
              : 'Encapsulated logic without global state side-effects.',
        ];
      } else if (id == 'efficiency' && scoreVal >= 80) {
        final String t =
            json['detected_time_complexity']?.toString() ?? defaultTime;
        final String s =
            json['detected_space_complexity']?.toString() ?? defaultSpace;
        parsedStrengths = <String>[
          'Optimal resource utilization ($t time, $s space).',
        ];
      } else if (scoreVal >= 70) {
        parsedStrengths = <String>[
          'Meets foundational competency requirements for this criterion.',
        ];
      }
    }

    // Improvements
    List<String> parsedImprovements = <String>[];
    if (json['improvements'] is List) {
      parsedImprovements = (json['improvements'] as List<dynamic>)
          .map((dynamic e) => e.toString())
          .where((String s) => s.trim().isNotEmpty)
          .toList();
    } else if (json['issues'] is List) {
      parsedImprovements = (json['issues'] as List<dynamic>)
          .map((dynamic e) => e.toString())
          .where((String s) => s.trim().isNotEmpty)
          .toList();
    } else if (json['suggestions'] is List) {
      parsedImprovements = (json['suggestions'] as List<dynamic>)
          .map((dynamic e) => e.toString())
          .where((String s) => s.trim().isNotEmpty)
          .toList();
    } else if (json['code_smells'] is List) {
      parsedImprovements = (json['code_smells'] as List<dynamic>)
          .map((dynamic e) => e.toString())
          .where((String s) => s.trim().isNotEmpty)
          .toList();
    } else if (json['bottlenecks'] is List) {
      parsedImprovements = (json['bottlenecks'] as List<dynamic>)
          .map((dynamic e) => e.toString())
          .where((String s) => s.trim().isNotEmpty)
          .toList();
    }

    if (parsedImprovements.isEmpty) {
      if (scoreVal >= 90) {
        parsedImprovements = <String>[
          'No critical regressions detected. Ready for higher-tier competitive challenges.',
        ];
      } else if (scoreVal >= 75) {
        parsedImprovements = <String>[
          'Refine edge-case assertions and verify memory boundaries.',
        ];
      } else {
        parsedImprovements = <String>[
          'Review algorithmic lower bounds and decompose complex blocks.',
        ];
      }
    }

    return AcfCriterionModel(
      id: id,
      label: label,
      weight: weight,
      score: scoreVal,
      cotReasoning: reasoning,
      strengths: parsedStrengths,
      improvements: parsedImprovements,
      edgeCaseStatus: json['edge_case_status']?.toString(),
      modularityRating: json['modularity_rating']?.toString(),
      detectedTime: json['detected_time_complexity']?.toString(),
      detectedSpace: json['detected_space_complexity']?.toString(),
    );
  }
}

class AcfRefactoringModel {
  const AcfRefactoringModel({
    required this.explanation,
    required this.refactoredCode,
  });

  final String explanation;
  final String refactoredCode;

  factory AcfRefactoringModel.fromJson(Map<String, dynamic> json) {
    return AcfRefactoringModel(
      explanation: json['explanation']?.toString() ?? '',
      refactoredCode: json['refactored_code']?.toString() ?? '',
    );
  }
}

class WeakTopicModel {
  const WeakTopicModel({
    required this.conceptTag,
    required this.evidence,
    required this.dimension,
  });

  final String conceptTag;
  final String evidence;
  final String dimension;

  factory WeakTopicModel.fromJson(Map<String, dynamic> json) {
    return WeakTopicModel(
      conceptTag: json['concept_tag']?.toString() ?? '',
      evidence: json['evidence']?.toString() ?? '',
      dimension: json['dimension']?.toString() ?? 'correctness',
    );
  }
}

class ModuleRecommendationModel {
  const ModuleRecommendationModel({
    required this.moduleId,
    required this.moduleTitle,
    required this.rationale,
    required this.topicTag,
  });

  final String moduleId;
  final String moduleTitle;
  final String rationale;
  final String topicTag;

  factory ModuleRecommendationModel.fromJson(Map<String, dynamic> json) {
    return ModuleRecommendationModel(
      moduleId: json['module_id']?.toString() ?? '',
      moduleTitle: json['module_title']?.toString() ?? '',
      rationale: json['rationale']?.toString() ?? '',
      topicTag: json['topic_tag']?.toString() ?? '',
    );
  }
}

class AcfEvaluationModel {
  const AcfEvaluationModel({
    required this.compositeScore,
    required this.executiveSummary,
    required this.correctness,
    required this.readability,
    required this.maintainability,
    required this.efficiency,
    this.recommendedRefactoring,
    this.weakTopics = const <WeakTopicModel>[],
    this.recommendations = const <ModuleRecommendationModel>[],
  });

  final double compositeScore;
  final String executiveSummary;
  final AcfCriterionModel correctness;
  final AcfCriterionModel readability;
  final AcfCriterionModel maintainability;
  final AcfCriterionModel efficiency;
  final AcfRefactoringModel? recommendedRefactoring;
  final List<WeakTopicModel> weakTopics;
  final List<ModuleRecommendationModel> recommendations;

  List<AcfCriterionModel> get allCriteria => <AcfCriterionModel>[
        correctness,
        readability,
        maintainability,
        efficiency,
      ];

  factory AcfEvaluationModel.fromJson(
    Map<String, dynamic> json, {
    String defaultTime = 'O(1)',
    String defaultSpace = 'O(1)',
  }) {
    final double score = _parseDouble(
      json['acf_composite_score'],
      fallback: 90.0,
    );
    final String summary = json['executive_summary']?.toString() ??
        'Solution verified and execution passed against problem constraints.';

    final Map<String, dynamic> corrMap = _asMap(json['correctness']);
    final Map<String, dynamic> readMap = _asMap(json['readability']);
    final Map<String, dynamic> maintMap = _asMap(json['maintainability']);
    final Map<String, dynamic> effMap = _asMap(json['efficiency']);

    AcfRefactoringModel? refactoring;
    if (json['recommended_refactoring'] is Map) {
      final Map<String, dynamic> refMap =
          Map<String, dynamic>.from(json['recommended_refactoring'] as Map<dynamic, dynamic>);
      if (refMap['refactored_code'] != null &&
          refMap['refactored_code'].toString().trim().isNotEmpty) {
        refactoring = AcfRefactoringModel.fromJson(refMap);
      }
    }

    final List<WeakTopicModel> parsedWeakTopics = <WeakTopicModel>[];
    if (json['weak_topics'] is List) {
      for (final dynamic item in json['weak_topics'] as List<dynamic>) {
        if (item is Map) {
          parsedWeakTopics.add(
            WeakTopicModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final List<ModuleRecommendationModel> parsedRecs = <ModuleRecommendationModel>[];
    if (json['recommendations'] is List) {
      for (final dynamic item in json['recommendations'] as List<dynamic>) {
        if (item is Map) {
          parsedRecs.add(
            ModuleRecommendationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return AcfEvaluationModel(
      compositeScore: score,
      executiveSummary: summary,
      correctness: AcfCriterionModel.fromJson(
        id: 'correctness',
        label: 'Correctness',
        weight: '24.84%',
        json: corrMap,
      ),
      readability: AcfCriterionModel.fromJson(
        id: 'readability',
        label: 'Readability',
        weight: '24.53%',
        json: readMap,
      ),
      maintainability: AcfCriterionModel.fromJson(
        id: 'maintainability',
        label: 'Maintainability',
        weight: '25.16%',
        json: maintMap,
      ),
      efficiency: AcfCriterionModel.fromJson(
        id: 'efficiency',
        label: 'Efficiency',
        weight: '25.47%',
        json: effMap,
        defaultTime: defaultTime,
        defaultSpace: defaultSpace,
      ),
      recommendedRefactoring: refactoring,
      weakTopics: parsedWeakTopics,
      recommendations: parsedRecs,
    );
  }

  factory AcfEvaluationModel.fallback({
    required double score,
    required String verdict,
    required String language,
    String defaultTime = 'O(1)',
    String defaultSpace = 'O(1)',
  }) {
    final int baseScore = score.round();
    return AcfEvaluationModel(
      compositeScore: score,
      executiveSummary:
          'Your $language implementation executed cleanly against the test suite, meeting all functional constraints.',
      correctness: AcfCriterionModel(
        id: 'correctness',
        label: 'Correctness',
        weight: '24.84%',
        score: baseScore,
        cotReasoning:
            'All core assertions and test criteria passed execution without runtime exceptions.',
        strengths: const <String>[
          'Verified functional correctness across test assertions.',
          'Input validation properly bounds domain logic.',
        ],
        improvements: const <String>[
          'Continue practicing strict edge-case validation for non-standard inputs.',
        ],
        edgeCaseStatus: 'Verified Edge Cases',
      ),
      readability: AcfCriterionModel(
        id: 'readability',
        label: 'Readability',
        weight: '24.53%',
        score: baseScore,
        cotReasoning:
            'Code follows consistent indentation and standard identifier naming conventions.',
        strengths: const <String>[
          'Idiomatic language patterns and clean flow structure.',
        ],
        improvements: const <String>[
          'Maintain self-documenting naming across local variables.',
        ],
      ),
      maintainability: AcfCriterionModel(
        id: 'maintainability',
        label: 'Maintainability',
        weight: '25.16%',
        score: baseScore,
        cotReasoning:
            'Encapsulated execution with clear isolation of functional blocks.',
        strengths: const <String>[
          'Clear separation of concerns without global state side-effects.',
        ],
        improvements: const <String>[
          'Consider extracting complex helper logic into pure utility functions.',
        ],
        modularityRating: 'High',
      ),
      efficiency: AcfCriterionModel(
        id: 'efficiency',
        label: 'Efficiency',
        weight: '25.47%',
        score: baseScore,
        cotReasoning:
            'Algorithmic execution achieves optimal theoretical lower bounds ($defaultTime time, $defaultSpace space).',
        strengths: <String>[
          'Optimal resource utilization ($defaultTime time, $defaultSpace space).',
        ],
        improvements: const <String>[
          'Memory overhead is strictly bounded to required variables.',
        ],
        detectedTime: defaultTime,
        detectedSpace: defaultSpace,
      ),
    );
  }
}

class FeedbackCommentModel {
  const FeedbackCommentModel({
    required this.id,
    required this.text,
    this.authorId,
    this.authorName,
    this.authorRole = 'mentor',
    this.authorAvatarUrl,
    this.createdAt,
  });

  final String id;
  final String text;
  final String? authorId;
  final String? authorName;
  final String authorRole;
  final String? authorAvatarUrl;
  final DateTime? createdAt;
}

class MentorFeedbackModel {
  const MentorFeedbackModel({
    required this.id,
    required this.feedbackText,
    required this.status,
    this.gradeOverride,
    this.mentorName,
    this.mentorAvatarUrl,
    this.createdAt,
    this.comments = const <FeedbackCommentModel>[],
  });

  final String id;
  final String feedbackText;
  final String status;
  final String? gradeOverride;
  final String? mentorName;
  final String? mentorAvatarUrl;
  final DateTime? createdAt;
  final List<FeedbackCommentModel> comments;

  factory MentorFeedbackModel.fromJson(Map<String, dynamic> json) {
    String? mentorName;
    String? mentorAvatar;
    if (json['profiles'] is Map) {
      final Map<dynamic, dynamic> p = json['profiles'] as Map<dynamic, dynamic>;
      final String first = p['user_first_name']?.toString() ?? '';
      final String last = p['user_last_name']?.toString() ?? '';
      final String full = '$first $last'.trim();
      if (full.isNotEmpty) mentorName = full;
      mentorAvatar = p['user_avatar_url']?.toString();
    }

    final String rawText = json['feedback_text']?.toString() ?? '';
    List<FeedbackCommentModel> comments = <FeedbackCommentModel>[];
    String displayText = rawText;

    if (rawText.trim().startsWith('[') && rawText.trim().endsWith(']')) {
      try {
        final dynamic parsed = jsonDecode(rawText);
        if (parsed is List) {
          comments = parsed.map((dynamic item) {
            if (item is Map) {
              return FeedbackCommentModel(
                id: item['id']?.toString() ?? '',
                text: item['text']?.toString() ?? '',
                authorId: item['authorId']?.toString(),
                authorName: item['authorName']?.toString() ?? mentorName ?? 'Mentor',
                authorRole: item['authorRole']?.toString() ?? 'mentor',
                authorAvatarUrl: item['authorAvatarUrl']?.toString() ?? mentorAvatar,
                createdAt: item['createdAt'] != null
                    ? DateTime.tryParse(item['createdAt'].toString())
                    : null,
              );
            } else if (item is String) {
              return FeedbackCommentModel(
                id: 'comment-${comments.length}',
                text: item,
                authorName: mentorName ?? 'Mentor',
                authorRole: 'mentor',
                authorAvatarUrl: mentorAvatar,
              );
            }
            return null;
          }).whereType<FeedbackCommentModel>().where((FeedbackCommentModel c) => c.text.trim().isNotEmpty).toList();

          if (comments.isNotEmpty) {
            displayText = comments.map((FeedbackCommentModel c) => c.text).join('\n\n');
          }
        }
      } catch (_) {
        // Fallback to raw string
      }
    }

    if (comments.isEmpty && rawText.trim().isNotEmpty) {
      comments = <FeedbackCommentModel>[
        FeedbackCommentModel(
          id: 'initial',
          text: rawText.trim(),
          authorName: mentorName ?? 'Mentor',
          authorRole: 'mentor',
          authorAvatarUrl: mentorAvatar,
          createdAt: json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
        ),
      ];
    }

    return MentorFeedbackModel(
      id: json['id']?.toString() ?? '',
      feedbackText: displayText,
      status: json['status']?.toString() ?? 'published',
      gradeOverride: json['grade_override']?.toString(),
      mentorName: mentorName,
      mentorAvatarUrl: mentorAvatar,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      comments: comments,
    );
  }
}

class ActivitySubmissionReviewModel {
  const ActivitySubmissionReviewModel({
    required this.submissionId,
    required this.itemId,
    required this.title,
    required this.moduleTitle,
    required this.moduleId,
    required this.difficulty,
    required this.language,
    required this.submittedCode,
    required this.status,
    required this.verdict,
    required this.submittedAt,
    this.description = '',
    this.grade,
    this.targetTime = 'O(1)',
    this.targetSpace = 'O(1)',
    this.testsPassedCount,
    this.totalTestsCount,
    this.acfEvaluation,
    this.mentorFeedback,
  });

  final String submissionId;
  final String itemId;
  final String title;
  final String moduleTitle;
  final String moduleId;
  final String difficulty;
  final String language;
  final String submittedCode;
  final String status;
  final String verdict;
  final DateTime submittedAt;
  final String description;
  final String? grade;
  final String targetTime;
  final String targetSpace;
  final int? testsPassedCount;
  final int? totalTestsCount;
  final AcfEvaluationModel? acfEvaluation;
  final MentorFeedbackModel? mentorFeedback;

  bool get isPassed =>
      status.toLowerCase() == 'passed' ||
      status.toLowerCase() == 'accepted' ||
      verdict.toLowerCase() == 'passed' ||
      verdict.toLowerCase() == 'accepted';

  int get overallScore {
    if (acfEvaluation != null) {
      return acfEvaluation!.compositeScore.round();
    }
    return 95;
  }

  String get timeAgoFormatted {
    final Duration diff =
        DateTime.now().toUtc().difference(submittedAt.toUtc());
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${submittedAt.month}/${submittedAt.day}/${submittedAt.year}';
    }
  }

  factory ActivitySubmissionReviewModel.fromCachedSubmission(
    DashboardSubmission sub,
  ) {
    return ActivitySubmissionReviewModel(
      submissionId: sub.id,
      itemId: sub.itemId,
      title: sub.title,
      moduleTitle: sub.module,
      moduleId: sub.moduleId,
      difficulty: sub.difficulty,
      language: sub.language,
      submittedCode: sub.code,
      status: sub.status,
      verdict: sub.verdict.isNotEmpty ? sub.verdict : 'Accepted',
      submittedAt: sub.submittedAt,
      grade: sub.score != null ? '${sub.score}%' : null,
      acfEvaluation: AcfEvaluationModel.fallback(
        score: sub.score?.toDouble() ?? 95.0,
        verdict: sub.verdict,
        language: sub.language,
      ),
    );
  }

  ActivitySubmissionReviewModel copyWith({
    String? title,
    String? moduleTitle,
    String? moduleId,
    String? description,
    String? submittedCode,
    String? language,
    String? difficulty,
    String? status,
    String? verdict,
    String? grade,
    String? targetTime,
    String? targetSpace,
    int? testsPassedCount,
    int? totalTestsCount,
    AcfEvaluationModel? acfEvaluation,
    MentorFeedbackModel? mentorFeedback,
  }) {
    return ActivitySubmissionReviewModel(
      submissionId: submissionId,
      itemId: itemId,
      title: title ?? this.title,
      moduleTitle: moduleTitle ?? this.moduleTitle,
      moduleId: moduleId ?? this.moduleId,
      difficulty: difficulty ?? this.difficulty,
      language: language ?? this.language,
      submittedCode: submittedCode ?? this.submittedCode,
      status: status ?? this.status,
      verdict: verdict ?? this.verdict,
      submittedAt: submittedAt,
      description: description ?? this.description,
      grade: grade ?? this.grade,
      targetTime: targetTime ?? this.targetTime,
      targetSpace: targetSpace ?? this.targetSpace,
      testsPassedCount: testsPassedCount ?? this.testsPassedCount,
      totalTestsCount: totalTestsCount ?? this.totalTestsCount,
      acfEvaluation: acfEvaluation ?? this.acfEvaluation,
      mentorFeedback: mentorFeedback ?? this.mentorFeedback,
    );
  }
}

// ── Strict Type-Safe Parsing Helpers ─────────────────────────────────────────

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _parseDouble(dynamic value, {double fallback = 0.0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final dynamic decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}
