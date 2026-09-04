import 'package:flutter/foundation.dart';

@immutable
class AssessmentChallengeModel {
  const AssessmentChallengeModel({
    required this.id,
    required this.title,
    required this.problemStatement,
    required this.starterCode,
    required this.language,
    required this.difficulty,
    this.testCases = const <Map<String, dynamic>>[],
  });

  final String id;
  final String title;
  final String problemStatement;
  final String starterCode;
  final String language;
  final String difficulty;
  final List<Map<String, dynamic>> testCases;

  factory AssessmentChallengeModel.fromJson(Map<String, dynamic> json) {
    return AssessmentChallengeModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      problemStatement: json['problem_statement'] as String? ?? '',
      starterCode: json['starter_code'] as String? ?? '',
      language: json['language'] as String? ?? 'javascript',
      difficulty: json['difficulty'] as String? ?? 'Medium',
      testCases: (json['test_cases'] as List<dynamic>?)
              ?.map((dynamic e) => e as Map<String, dynamic>)
              .toList() ??
          const <Map<String, dynamic>>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'problem_statement': problemStatement,
      'starter_code': starterCode,
      'language': language,
      'difficulty': difficulty,
      'test_cases': testCases,
    };
  }
}

@immutable
class AssessmentModel {
  const AssessmentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.stack,
    required this.difficulty,
    required this.durationMins,
    required this.passingScore,
    required this.maxAttempts,
    required this.status,
    required this.challengeCount,
    this.mentorId,
    this.mentorName = 'CodeMentor AI',
    this.mentorAvatar,
    this.isInLibrary = false,
    this.challenges = const <AssessmentChallengeModel>[],
  });

  final String id;
  final String title;
  final String description;
  final List<String> stack;
  final String difficulty; // 'Easy', 'Medium', 'Hard'
  final int durationMins;
  final int passingScore;
  final int maxAttempts;
  final String status;
  final int challengeCount;
  final String? mentorId;
  final String mentorName;
  final String? mentorAvatar;
  final bool isInLibrary;
  final List<AssessmentChallengeModel> challenges;

  AssessmentModel copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? stack,
    String? difficulty,
    int? durationMins,
    int? passingScore,
    int? maxAttempts,
    String? status,
    int? challengeCount,
    String? mentorId,
    String? mentorName,
    String? mentorAvatar,
    bool? isInLibrary,
    List<AssessmentChallengeModel>? challenges,
  }) {
    return AssessmentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      stack: stack ?? this.stack,
      difficulty: difficulty ?? this.difficulty,
      durationMins: durationMins ?? this.durationMins,
      passingScore: passingScore ?? this.passingScore,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      status: status ?? this.status,
      challengeCount: challengeCount ?? this.challengeCount,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      mentorAvatar: mentorAvatar ?? this.mentorAvatar,
      isInLibrary: isInLibrary ?? this.isInLibrary,
      challenges: challenges ?? this.challenges,
    );
  }

  factory AssessmentModel.fromJson(
    Map<String, dynamic> json, {
    bool isInLibrary = false,
  }) {
    // 1. Stack parsing
    List<String> parsedStack = <String>[];
    if (json['stack'] is List) {
      parsedStack = (json['stack'] as List<dynamic>)
          .map((dynamic s) => s.toString())
          .toList();
    }
    if (parsedStack.isEmpty) {
      parsedStack = <String>['General'];
    }

    // 2. Difficulty normalization (DB stores 'Beginner'/'Intermediate'/'Advanced' or 'Easy'/'Medium'/'Hard')
    final String rawDiff = json['difficulty']?.toString() ?? 'Medium';
    final String normalizedDiff;
    switch (rawDiff.toLowerCase()) {
      case 'beginner':
      case 'easy':
        normalizedDiff = 'Easy';
        break;
      case 'advanced':
      case 'hard':
        normalizedDiff = 'Hard';
        break;
      default:
        normalizedDiff = 'Medium';
    }

    // 3. Mentor resolution
    String mentorName = 'CodeMentor AI';
    String? mentorAvatar;
    if (json['profiles'] is Map<String, dynamic>) {
      final Map<String, dynamic> profile =
          json['profiles'] as Map<String, dynamic>;
      final String first = profile['user_first_name']?.toString().trim() ?? '';
      final String last = profile['user_last_name']?.toString().trim() ?? '';
      final String fullName = '$first $last'.trim();
      if (fullName.isNotEmpty) {
        mentorName = fullName;
      }
      mentorAvatar = profile['user_avatar_url']?.toString();
    }

    // 4. Challenge count
    int challengeCount = 0;
    if (json['challenges'] is List) {
      final List<dynamic> chList = json['challenges'] as List<dynamic>;
      if (chList.isNotEmpty) {
        final dynamic first = chList.first;
        if (first is Map<String, dynamic> && first.containsKey('count')) {
          challengeCount = first['count'] as int? ?? 0;
        } else {
          challengeCount = chList.length;
        }
      }
    }

    // 5. Full challenges if provided
    List<AssessmentChallengeModel> challenges = <AssessmentChallengeModel>[];
    if (json['challenges'] is List) {
      final List<dynamic> chList = json['challenges'] as List<dynamic>;
      if (chList.isNotEmpty) {
        final dynamic first = chList.first;
        if (first is Map<String, dynamic> && first.containsKey('title')) {
          challenges = chList
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> c) =>
                  AssessmentChallengeModel.fromJson(c))
              .toList();
        }
      }
    }

    return AssessmentModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      stack: parsedStack,
      difficulty: normalizedDiff,
      durationMins: json['duration_mins'] as int? ?? 60,
      passingScore: json['passing_score'] as int? ?? 70,
      maxAttempts: json['max_attempts'] as int? ?? 1,
      status: json['status']?.toString() ?? 'published',
      challengeCount: challengeCount > 0 ? challengeCount : challenges.length,
      mentorId: json['mentor_id']?.toString(),
      mentorName: mentorName,
      mentorAvatar: mentorAvatar,
      isInLibrary: isInLibrary,
      challenges: challenges,
    );
  }
}
