import 'package:codementorai_mobile/src/features/learn/domain/history_items.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an assessment attempt is Completed, never Passed or Needs Review', () {
    final List<HistoryItem> items = buildHistoryItems(
      const [],
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'a1',
          'assessment_id': 'asm',
          'submitted_at': '2026-01-01T00:00:00Z',
          'score': 50,
          'is_passed': false,
        },
        <String, dynamic>{
          'id': 'a2',
          'assessment_id': 'asm',
          'submitted_at': '2026-01-02T00:00:00Z',
          'score': 100,
          'is_passed': true,
        },
      ],
    );
    expect(items.length, 2);
    expect(items.every((HistoryItem i) => i.status == 'Completed'), isTrue);
  });
}
