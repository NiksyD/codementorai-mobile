import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/common_widgets/app_toast.dart';

void main() {
  group('AppToast Widget Tests (Redesigned Floating Frosted Capsule Toast)', () {
    testWidgets('Renders info toast with message, sky blue icon, and close button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    AppToast.showInfo(
                      context,
                      'Email address is linked to your account and cannot be modified.',
                    );
                  },
                  child: const Text('Show Info Toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Info Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text('Email address is linked to your account and cannot be modified.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap close button dismisses toast
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text('Email address is linked to your account and cannot be modified.'),
        findsNothing,
      );
    });

    testWidgets('Renders success, error, and warning toasts with proper icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return Column(
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () => AppToast.showSuccess(context, 'Success!'),
                      child: const Text('Success Btn'),
                    ),
                    ElevatedButton(
                      onPressed: () => AppToast.showError(context, 'Error!'),
                      child: const Text('Error Btn'),
                    ),
                    ElevatedButton(
                      onPressed: () => AppToast.showWarning(context, 'Warning!'),
                      child: const Text('Warning Btn'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Test Success
      await tester.tap(find.text('Success Btn'));
      await tester.pump();
      expect(find.text('Success!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Test Error
      await tester.tap(find.text('Error Btn'));
      await tester.pump();
      expect(find.text('Error!'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);

      // Test Warning
      await tester.tap(find.text('Warning Btn'));
      await tester.pump();
      expect(find.text('Warning!'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });
  });
}
