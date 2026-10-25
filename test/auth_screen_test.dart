import 'package:bridgy/screens/auth_screen.dart';
import 'package:bridgy/unipay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app() => MaterialApp(theme: unipayTheme(), home: const AuthScreen());

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('email, password, magic link and Google are all offered', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-sign-in')), findsOneWidget);
    expect(find.byKey(const Key('auth-sign-up')), findsOneWidget);
    expect(find.byKey(const Key('auth-magic-link')), findsOneWidget);
    expect(find.byKey(const Key('google-sign-in')), findsOneWidget);
  });

  testWidgets('sign in rejects an invalid email before any network call', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byKey(const Key('auth-email')), 'nope');
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret123');
    await tester.tap(find.byKey(const Key('auth-sign-in')));
    await tester.pump();

    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('sign in rejects a short password', (tester) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('auth-password')), '123');
    await tester.tap(find.byKey(const Key('auth-sign-in')));
    await tester.pump();

    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('magic link requires an email', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(const Key('auth-magic-link')));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });
}
