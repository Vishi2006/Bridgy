import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bridgy/main.dart';

const gold = Color(0xFFC9A961);

Future<void> loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await loadFont('Manrope', [
      'assets/fonts/Manrope-400.ttf',
      'assets/fonts/Manrope-500.ttf',
      'assets/fonts/Manrope-600.ttf',
      'assets/fonts/Manrope-700.ttf',
      'assets/fonts/Manrope-800.ttf',
    ]);
    await loadFont('Fraunces', [
      'assets/fonts/Fraunces-600.ttf',
      'assets/fonts/Fraunces-700.ttf',
    ]);
    await loadFont('PlayfairDisplay', [
      'assets/fonts/PlayfairDisplay-700-Italic.ttf',
    ]);
    await loadFont('JetBrainsMono', ['assets/fonts/JetBrainsMono-500.ttf']);
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('home shows Pesse branding, balance and matte gold chip', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Pesse'), findsOneWidget);
    expect(find.text('\$521,098.31'), findsOneWidget);

    final chip = tester.widget<Container>(find.byKey(const Key('card-chip')));
    expect((chip.decoration! as BoxDecoration).color, gold);
  });

  testWidgets('Send opens the send money screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Send to'), findsOneWidget);
    expect(find.text('Syaiful Rijal'), findsWidgets);
  });

  testWidgets('balance selector opens the select card screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('balance-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Select Card'), findsOneWidget);
    expect(find.text('New card'), findsOneWidget);

    final firstCard = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('card-lime')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((firstCard.decoration! as BoxDecoration).color, gold);
  });

  testWidgets('close returns from select card to home', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const Key('balance-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-cards')));
    await tester.pumpAndSettle();

    expect(find.text('\$521,098.31'), findsOneWidget);
  });

  testWidgets('keypad appends digits and backspace removes them', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('\$19'), findsOneWidget);

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(find.text('\$197'), findsOneWidget);

    await tester.tap(find.byKey(const Key('key-backspace')));
    await tester.pump();
    expect(find.text('\$19'), findsOneWidget);
  });
}
