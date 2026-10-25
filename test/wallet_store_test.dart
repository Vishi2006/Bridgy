import 'dart:convert';

import 'package:bridgy/services/wallet_service.dart';
import 'package:bridgy/state/wallet_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    WalletService.tokenOverride = 'test-token';
    WalletService.clientOverride = MockClient((request) async {
      if (request.url.path == '/api/wallet/balance') {
        return http.Response(
          jsonEncode({
            'balanceInr': 250,
            'onchain': {
              'address': '0xc2380dea8E9c66A5e0dFe54397A1bDc8eCA41592',
              'balanceEth': 0.005,
            },
            'onchainError': null,
          }),
          200,
        );
      }
      if (request.url.path == '/api/wallet/transactions') {
        return http.Response(
          jsonEncode({
            'transactions': [
              {
                'id': 't1',
                'merchantName': 'Wallet top-up',
                'amountInr': 500,
                'status': 'TOPUP',
                'createdAt': '2026-10-25T00:00:00.000Z',
              },
              {
                'id': 't2',
                'merchantName': 'Blinkit',
                'amountInr': 250,
                'status': 'AGENT_PAID',
                'createdAt': '2026-10-24T00:00:00.000Z',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('{"error":"not found"}', 404);
    });
    WalletStore.instance.clear();
  });

  tearDown(() {
    WalletService.clientOverride = null;
    WalletService.tokenOverride = null;
    WalletStore.instance.clear();
  });

  test('refresh loads the backend balance and ledger rows', () async {
    await WalletStore.instance.refresh();

    expect(WalletStore.instance.loaded, isTrue);
    expect(WalletStore.instance.balance, 250);
    expect(WalletStore.instance.balanceText, '₹250.00');
    expect(WalletStore.instance.onchainEth, 0.005);
    expect(
      WalletStore.instance.onchainAddress,
      '0xc2380dea8E9c66A5e0dFe54397A1bDc8eCA41592',
    );
    expect(WalletStore.instance.transactions.length, 2);

    final topup = WalletStore.instance.transactions.first;
    expect(topup.title, 'Wallet top-up');
    expect(topup.amount, 500);
    expect(topup.kind, 'topup');

    final payment = WalletStore.instance.transactions.last;
    expect(payment.amount, -250);
    expect(payment.kind, 'agent_paid');
  });

  test('clear removes the previous user data on sign-out', () async {
    await WalletStore.instance.refresh();
    WalletStore.instance.clear();

    expect(WalletStore.instance.loaded, isFalse);
    expect(WalletStore.instance.balance, 0);
    expect(WalletStore.instance.transactions, isEmpty);
    expect(WalletStore.instance.error, isNull);
  });

  test(
    'refresh keeps the exact backend error and does not invent rows',
    () async {
      WalletService.clientOverride = MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'permission denied', 'code': '42501'}),
          403,
        ),
      );

      await WalletStore.instance.refresh();

      expect(WalletStore.instance.loaded, isFalse);
      expect(WalletStore.instance.error, contains('permission denied'));
      expect(WalletStore.instance.transactions, isEmpty);
    },
  );
}
