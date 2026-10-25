import 'package:bridgy/screens/top_up_screen.dart';
import 'package:bridgy/services/wallet_service.dart';
import 'package:bridgy/state/wallet_store.dart';
import 'package:bridgy/unipay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app({required Future<TopUpResult> Function(double) onSubmit}) {
  return MaterialApp(
    theme: unipayTheme(),
    home: TopUpScreen(onSubmit: onSubmit),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WalletStore.instance.reset();
  });

  testWidgets('preset buttons fill the amount field', (tester) async {
    await tester.pumpWidget(
      _app(onSubmit: (amount) async => throw UnimplementedError()),
    );

    await tester.tap(find.byKey(const Key('topup-preset-1000')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('topup-amount')),
    );
    expect(field.controller?.text, '1000');
    expect(find.text('Top up ₹1000'), findsOneWidget);
  });

  testWidgets('successful top-up shows the backend balance', (tester) async {
    double? submitted;
    await tester.pumpWidget(
      _app(
        onSubmit: (amount) async {
          submitted = amount;
          return const TopUpResult(
            amountInr: 1000,
            balanceInr: 1500,
            transactionId: 'tx-1',
          );
        },
      ),
    );

    await tester.tap(find.byKey(const Key('topup-preset-1000')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pumpAndSettle();

    expect(submitted, 1000);
    expect(find.byKey(const Key('topup-success')), findsOneWidget);
    expect(find.textContaining('New balance ₹1500.00'), findsOneWidget);
    expect(WalletStore.instance.balance, 1500);
    expect(WalletStore.instance.balanceText, '₹1,500.00');
  });

  testWidgets('backend error is shown verbatim and no balance is applied', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        onSubmit: (amount) async => throw const WalletApiException(
          'wallet_topup returned no row (TOPUP_EMPTY)',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('topup-error')), findsOneWidget);
    expect(
      find.text('wallet_topup returned no row (TOPUP_EMPTY)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('topup-success')), findsNothing);
    expect(WalletStore.instance.loaded, isFalse);
  });

  testWidgets('zero amount is rejected without calling the backend', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      _app(
        onSubmit: (amount) async {
          called = true;
          return const TopUpResult(
            amountInr: 1,
            balanceInr: 1,
            transactionId: 'tx',
          );
        },
      ),
    );

    await tester.enterText(find.byKey(const Key('topup-amount')), '0');
    await tester.tap(find.byKey(const Key('topup-submit')));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Enter an amount greater than 0.'), findsOneWidget);
  });
}
