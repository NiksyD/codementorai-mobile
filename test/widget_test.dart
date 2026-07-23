import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/main.dart';

void main() {
  testWidgets('App renders Sign In screen on launch', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CodeMentorApp());

    // Verify that Welcome Back header and Sign In button are present.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(
      find.text('Sign In'),
      findsNWidgets(2),
    ); // AppBar title & Button text
  });
}
