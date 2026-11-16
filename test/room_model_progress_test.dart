import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/domain/room_model.dart';

void main() {
  group('RoomModel & RoomModuleSummary Unlocked Progress Tests', () {
    test('RoomModuleSummary properly initializes unlocked vs locked challenges', () {
      final RoomModuleSummary unlockedMod = RoomModuleSummary.fromJson(<String, dynamic>{
        'mod_id': 'mod-free',
        'mod_title': 'Free Module',
        'topicsCount': 2,
        'exercisesCount': 4,
        'challengesCount': 4,
        'activitiesCount': 8,
        'challengesLocked': false,
      });

      expect(unlockedMod.id, 'mod-free');
      expect(unlockedMod.exercisesCount, 4);
      expect(unlockedMod.challengesCount, 4);
      expect(unlockedMod.activitiesCount, 8);
      expect(unlockedMod.challengesLocked, false);

      final RoomModuleSummary lockedMod = RoomModuleSummary.fromJson(<String, dynamic>{
        'mod_id': 'mod-paid',
        'mod_title': 'Paid Locked Module',
        'topicsCount': 2,
        'exercisesCount': 4,
        'challengesCount': 4,
        'activitiesCount': 4, // Only exercises counted when locked
        'challengesLocked': true,
      });

      expect(lockedMod.id, 'mod-paid');
      expect(lockedMod.exercisesCount, 4);
      expect(lockedMod.challengesCount, 4);
      expect(lockedMod.activitiesCount, 4);
      expect(lockedMod.challengesLocked, true);
    });

    test('RoomModel.totalActivities sums unlocked activities accurately', () {
      // Replicate user scenario:
      // 1 module with unlocked challenges (4 practices + 4 challenges = 8)
      // 1 module with locked challenges (4 practices = 4)
      final RoomModel room = RoomModel(
        id: 'room-test',
        name: 'Test Hub',
        section: 'Sec 1',
        joinCode: 'TEST01',
        targetLanguage: 'python',
        description: 'Test Hub Description',
        status: 'active',
        curriculumModules: const <RoomModuleSummary>[
          RoomModuleSummary(
            id: 'mod-1',
            title: 'Functions & Problem Solving',
            description: '',
            topicsCount: 4,
            exercisesCount: 4,
            challengesCount: 4,
            activitiesCount: 8,
            challengesLocked: false,
          ),
          RoomModuleSummary(
            id: 'mod-2',
            title: 'Object-Oriented Programming',
            description: '',
            topicsCount: 4,
            exercisesCount: 4,
            challengesCount: 4,
            activitiesCount: 4, // Challenges locked
            challengesLocked: true,
          ),
        ],
        completedActivitiesCount: 5,
      );

      // Total unlocked activities: 8 + 4 = 12
      expect(room.totalActivities, 12);
      // Progress: (5 / 12 * 100).round() = 42%
      expect(room.progressPct, 42);
    });

    test('RoomModel matches Web 5 of 134 (4%) calculation exactly', () {
      // 7 baseline pretest modules (each 10 challenges = 70)
      // 12 locked standard modules (each 4 practices = 48)
      // 1 unlocked standard module (4 practices + 4 challenges = 8)
      // 1 locked C# module (8 practices = 8)
      // Total unlocked = 70 + 48 + 8 + 8 = 134
      final List<RoomModuleSummary> modules = <RoomModuleSummary>[
        for (int i = 0; i < 7; i++)
          RoomModuleSummary(
            id: 'pretest-$i',
            title: 'Pretest $i',
            description: '',
            topicsCount: 0,
            exercisesCount: 0,
            challengesCount: 10,
            activitiesCount: 10,
            challengesLocked: false,
            isBaseline: true,
          ),
        for (int i = 0; i < 12; i++)
          RoomModuleSummary(
            id: 'locked-std-$i',
            title: 'Standard Module $i',
            description: '',
            topicsCount: 4,
            exercisesCount: 4,
            challengesCount: 4,
            activitiesCount: 4, // locked
            challengesLocked: true,
          ),
        const RoomModuleSummary(
          id: 'unlocked-std',
          title: 'Functions and Data Structures',
          description: '',
          topicsCount: 4,
          exercisesCount: 4,
          challengesCount: 4,
          activitiesCount: 8,
          challengesLocked: false,
        ),
        const RoomModuleSummary(
          id: 'locked-csharp',
          title: 'C# Programming Fundamentals',
          description: '',
          topicsCount: 8,
          exercisesCount: 8,
          challengesCount: 8,
          activitiesCount: 8, // locked
          challengesLocked: true,
        ),
      ];

      final RoomModel room = RoomModel(
        id: 'd36140d6-3f0f-4c23-b6c3-9943261348a6',
        name: 'CodeMentorAI: Testing Validation',
        section: 'CS-401',
        joinCode: 'VAL2026',
        targetLanguage: 'python',
        description: 'Validation cohort',
        status: 'active',
        curriculumModules: modules,
        completedActivitiesCount: 5,
      );

      expect(room.totalActivities, 134);
      expect(room.completedActivitiesCount, 5);
      expect(room.progressPct, 4); // (5 / 134 * 100).round() == 4%
    });

    test('Strict 0% handling per AGENTS.md 2.3', () {
      final RoomModel zeroProgressRoom = RoomModel(
        id: 'room-zero',
        name: 'Fresh Hub',
        section: '101',
        joinCode: 'ZERO01',
        targetLanguage: 'python',
        description: '',
        status: 'active',
        curriculumModules: const <RoomModuleSummary>[
          RoomModuleSummary(
            id: 'm1',
            title: 'Mod 1',
            description: '',
            activitiesCount: 10,
          ),
        ],
        completedActivitiesCount: 0,
      );

      expect(zeroProgressRoom.progressPct, 0);
    });
  });
}
