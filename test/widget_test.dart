import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/main.dart';

void main() {
  testWidgets('App launches Splash Screen with CodeMentor AI title', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CodeMentorApp());

    // Verify that Splash screen renders CodeMentorAI title.
    expect(
      find.byWidgetPredicate((widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('CodeMentorAI')),
      findsWidgets,
    );

    // Advance timer past splash delay to clean up pending timers
    await tester.pump(const Duration(seconds: 2));
  });
}
