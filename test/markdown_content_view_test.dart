import 'package:codementorai_mobile/src/features/learn/presentation/widgets/markdown_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(String markdown) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MarkdownContentView(
          markdown: markdown,
          isDark: true,
          textPrimary: Colors.white,
          textSecondary: Colors.grey,
          cardBg: Colors.black,
          borderColor: Colors.grey,
        ),
      ),
    ),
  );
}

void main() {
  group('MarkdownContentView with unmatched inline markers', () {
    final Map<String, String> cases = <String, String>{
      'single asterisk between words': 'Time complexity must be O(n * m).',
      'trailing asterisk': 'Return the product n*',
      'unmatched double asterisk': 'This is **not closed',
      'unmatched backtick': 'Use the ` character carefully',
      'bullet with a lone asterisk': '- compute a * b for every pair',
      'only markers': '** * ` **',
    };

    cases.forEach((String name, String markdown) {
      testWidgets('renders without hanging: $name', (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(markdown));
        expect(find.byType(MarkdownContentView), findsOneWidget);
      }, timeout: const Timeout(Duration(seconds: 10)));
    });

    testWidgets('matched bold and inline code still render', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap('Use **bold** and `code` here.'));
      expect(find.byType(MarkdownContentView), findsOneWidget);
      expect(find.textContaining('bold', findRichText: true), findsWidgets);
    });
  });
}
