import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bridgy/main.dart';

Future<void> loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    await loadFont('PlusJakartaSans', [
      'assets/fonts/plus_jakarta/PlusJakartaSans-Regular.ttf',
      'assets/fonts/plus_jakarta/PlusJakartaSans-Medium.ttf',
      'assets/fonts/plus_jakarta/PlusJakartaSans-SemiBold.ttf',
      'assets/fonts/plus_jakarta/PlusJakartaSans-Bold.ttf',
      'assets/fonts/plus_jakarta/PlusJakartaSans-ExtraBold.ttf',
    ]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.bridgy.bridgy/accessibility'),
          (call) async => call.method == 'isServiceRunning' ? false : null,
        );
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.bridgy.bridgy/accessibility'),
          null,
        );
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('home matches the reference content', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Notification'), findsOneWidget);
    expect(find.text('Donate for Ukraine'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.byKey(const Key('activity-empty')), findsOneWidget);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    expect(find.byKey(const Key('nav-plus')), findsOneWidget);
    expect(find.byKey(const Key('nav-agent')), findsOneWidget);
    expect(find.byKey(const Key('open-policy')), findsOneWidget);
  });

  testWidgets('plus opens Send Money and keypad updates the amount', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tapAndSettle(tester, find.byKey(const Key('nav-plus')));

    expect(find.text('Send Money'), findsOneWidget);
    expect(find.text('Donate for Ukraine'), findsOneWidget);
    expect(find.text('00.00'), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('back returns from Send Money to the home footer', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tapAndSettle(tester, find.byKey(const Key('nav-plus')));
    await tapAndSettle(tester, find.byKey(const Key('send-back')));

    expect(find.byKey(const Key('nav-plus')), findsOneWidget);
    expect(find.text('Notification'), findsOneWidget);
  });

  testWidgets('send never shows success without a backend response', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tapAndSettle(tester, find.byKey(const Key('nav-plus')));

    await tester.tap(find.text('5'));
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-confirm-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('send-error')), findsOneWidget);
    expect(find.textContaining('Sign in required'), findsOneWidget);
  });

  testWidgets('agent glyph opens the agent window', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tapAndSettle(tester, find.byKey(const Key('nav-agent')));

    expect(find.text('AI Agent'), findsOneWidget);
    expect(find.text('What should we do?'), findsOneWidget);
    expect(find.byKey(const Key('agent-send')), findsOneWidget);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
  });

  testWidgets('agent composer accepts text without the network', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tapAndSettle(tester, find.byKey(const Key('nav-agent')));

    await tester.enterText(find.byType(TextField).last, 'hello');
    expect(find.text('hello'), findsOneWidget);
  });
}
