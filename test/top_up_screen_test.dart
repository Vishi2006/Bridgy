import 'package:bridgy/screens/top_up_screen.dart';
import 'package:bridgy/services/wallet_service.dart';
import 'package:bridgy/state/wallet_store.dart';
import 'package:bridgy/unipay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TopUpOrder _order({
  String status = 'PENDING',
  double? balanceInr,
  String? checkoutUrl = 'https://rzp.io/pay',
}) {
  return TopUpOrder(
    id: 'topup-1',
    amountInr: 1000,
    status: status,
    checkoutUrl: checkoutUrl,
    balanceInr: balanceInr,
  );
}

Widget _app({
  Future<TopUpOrder> Function(double)? createOrder,
  Future<TopUpOrder> Function(String)? fetchOrder,
  Future<bool> Function(Uri)? launchPayment,
}) {
  return MaterialApp(
    theme: unipayTheme(),
    home: TopUpScreen(
      createOrder: createOrder,
      fetchOrder: fetchOrder,
      launchPayment: launchPayment,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WalletStore.instance.reset();
  });

  testWidgets('preset buttons fill the amount field', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byKey(const Key('topup-preset-1000')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('topup-amount')),
    );
    expect(field.controller?.text, '1000');
    expect(find.text('Top up ₹1000 with UPI'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('paid top-up updates the wallet from the backend balance', (
    tester,
  ) async {
    double? submitted;
    Uri? opened;

    await tester.pumpWidget(
      _app(
        createOrder: (amount) async {
          submitted = amount;
          return _order();
        },
        fetchOrder: (id) async => _order(status: 'PAID', balanceInr: 1500),
        launchPayment: (uri) async {
          opened = uri;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('topup-preset-1000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(submitted, 1000);
    expect(opened.toString(), 'https://rzp.io/pay');
    expect(find.byKey(const Key('topup-success')), findsOneWidget);
    expect(find.textContaining('New balance ₹1500.00'), findsOneWidget);
    expect(WalletStore.instance.balance, 1500);
    expect(WalletStore.instance.balanceText, '₹1,500.00');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing Razorpay configuration is shown verbatim', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        createOrder: (amount) async => throw const WalletApiException(
          'Razorpay is not configured: set RAZORPAY_KEY_ID and '
          'RAZORPAY_KEY_SECRET on the backend. (PSP_NOT_CONFIGURED)',
        ),
        launchPayment: (uri) async => true,
      ),
    );

    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('topup-error')), findsOneWidget);
    expect(find.textContaining('PSP_NOT_CONFIGURED'), findsOneWidget);
    expect(find.byKey(const Key('topup-success')), findsNothing);
    expect(WalletStore.instance.loaded, isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('zero amount is rejected without calling the backend', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      _app(
        createOrder: (amount) async {
          called = true;
          return _order();
        },
        launchPayment: (uri) async => true,
      ),
    );

    await tester.enterText(find.byKey(const Key('topup-amount')), '0');
    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Enter an amount greater than 0.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expired payment stops polling and adds no money', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        createOrder: (amount) async => _order(),
        fetchOrder: (id) async => _order(status: 'EXPIRED'),
        launchPayment: (uri) async => true,
      ),
    );

    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byKey(const Key('topup-error')), findsOneWidget);
    expect(find.textContaining('Payment expired'), findsOneWidget);
    expect(WalletStore.instance.balance, 0);

    await tester.pumpWidget(const SizedBox());
  });
}
