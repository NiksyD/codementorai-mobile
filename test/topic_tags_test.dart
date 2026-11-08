import 'dart:io';

import 'package:codementorai_mobile/src/features/learn/domain/topic_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ids and labels match the web list exactly', () {
    final File web = File('../codementorai-web/lib/competency/topicTags.ts');
    if (!web.existsSync()) {
      markTestSkipped('web repo not next to mobile repo');
      return;
    }
    final RegExp row = RegExp(r'\{ id: "([a-z_]+)", label: "([^"]+)", group: "([a-z_]+)"');
    final List<String> webTags = <String>[
      for (final RegExpMatch m in row.allMatches(web.readAsStringSync()))
        '${m[1]}|${m[2]}|${m[3]}',
    ];
    final List<String> dartTags = <String>[
      for (final TopicTag t in topicTags) '${t.id}|${t.label}|${t.group}',
    ];
    expect(dartTags, webTags);
    expect(dartTags.length, 36);
  });

  test('sanitize keeps known ids or labels, dedupes and caps at 3', () {
    expect(sanitizeTopicTags(null), isEmpty);
    expect(
      sanitizeTopicTags(<dynamic>['recursion', 'Recursion', 'Big-O', 'Arrays', 'trees', 'stacks']),
      <String>['recursion', 'arrays', 'trees'],
    );
  });
}
