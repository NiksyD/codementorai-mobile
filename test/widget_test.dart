import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/main.dart';

void main() {
  testWidgets('App launches Splash Screen with CodeMentor AI title', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CodeMentorApp());

    // Verify that Splash screen renders CodeMentor AI title.
    expect(find.text('CodeMentor AI'), findsOneWidget);

    // Advance timer past splash delay to clean up pending timers
    await tester.pump(const Duration(seconds: 2));
  });
}
