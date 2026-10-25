import 'package:bridgy/screens/upi_checkout_screen.dart';
import 'package:bridgy/state/policy_controller.dart';
import 'package:bridgy/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('Manrope', [
      'assets/fonts/Manrope-400.ttf',
      'assets/fonts/Manrope-500.ttf',
      'assets/fonts/Manrope-600.ttf',
      'assets/fonts/Manrope-700.ttf',
      'assets/fonts/Manrope-800.ttf',
    ]);
    await _loadFont('Fraunces', [
      'assets/fonts/Fraunces-600.ttf',
      'assets/fonts/Fraunces-700.ttf',
    ]);
    await _loadFont('JetBrainsMono', ['assets/fonts/JetBrainsMono-500.ttf']);
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1170, 2532);
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
    PolicyController.instance
      ..perTxLimitInr = 200
      ..dailyLimitInr = 500
      ..spentTodayInr = 0
      ..expiresAt = DateTime.now().add(const Duration(hours: 24));
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  Widget app(String link) => MaterialApp(
    theme: bridgyTheme(),
    home: UpiCheckoutScreen(link: link),
  );

  testWidgets('shows merchant and amount from the upi link', (tester) async {
    await tester.pumpWidget(
      app('upi://pay?pa=blinkit@axisbank&pn=Blinkit&am=150&tn=Order%20123'),
    );

    expect(find.text('Blinkit'), findsOneWidget);
    expect(find.text('₹150.00'), findsOneWidget);
    expect(find.text('Order 123'), findsOneWidget);
    expect(find.text('Within policy'), findsOneWidget);
    expect(find.text('Pay ₹150'), findsOneWidget);
  });

  testWidgets('escalates to owner approval above the per-tx limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      app('upi://pay?pa=blinkit@axisbank&pn=Blinkit&am=380'),
    );

    expect(find.text('Owner approval required'), findsOneWidget);
    expect(find.text('Approve as owner'), findsOneWidget);

    await tester.tap(find.text('Approve as owner'));
    await tester.pumpAndSettle();
    expect(find.text('Approve with owner key'), findsOneWidget);

    await tester.tap(find.text('Approve with owner key'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing was charged'), findsOneWidget);
  });

  testWidgets('blocks an amount above the daily budget', (tester) async {
    PolicyController.instance.spentTodayInr = 480;
    await tester.pumpWidget(
      app('upi://pay?pa=zepto@axisbank&pn=Zepto&am=100'),
    );

    expect(find.text('Blocked by policy'), findsOneWidget);
    expect(find.text('Payment blocked'), findsOneWidget);
  });

  testWidgets('rejects a malformed link', (tester) async {
    await tester.pumpWidget(app('upi://pay?pn=Blinkit&am=10'));

    expect(find.text('Not a valid UPI payment request.'), findsOneWidget);
  });
}
