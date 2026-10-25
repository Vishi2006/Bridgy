import 'dart:convert';

import 'package:bridgy/services/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    WalletService.tokenOverride = 'test-token';
  });

  tearDown(() {
    WalletService.clientOverride = null;
    WalletService.tokenOverride = null;
  });

  test('getBalance sends the bearer token and parses the balance', () async {
    late http.Request seen;
    WalletService.clientOverride = MockClient((request) async {
      seen = request;
      return http.Response(jsonEncode({'balanceInr': 42.5}), 200);
    });

    final balance = await WalletService.getBalance();
    expect(balance.balanceInr, 42.5);
    expect(seen.headers['Authorization'], 'Bearer test-token');
    expect(seen.url.path, '/api/wallet/balance');
  });

  test('getBalance parses the on-chain deposit fields', () async {
    WalletService.clientOverride = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'balanceInr': 500,
          'onchain': {
            'address': '0xc2380dea8E9c66A5e0dFe54397A1bDc8eCA41592',
            'balanceEth': 0.005,
          },
          'onchainError': null,
        }),
        200,
      ),
    );

    final snapshot = await WalletService.getBalance();
    expect(snapshot.balanceInr, 500);
    expect(snapshot.onchainEth, 0.005);
    expect(
      snapshot.onchainAddress,
      '0xc2380dea8E9c66A5e0dFe54397A1bDc8eCA41592',
    );
    expect(snapshot.onchainError, isNull);
  });

  test(
    'getBalance surfaces an on-chain sync error next to the balance',
    () async {
      WalletService.clientOverride = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'balanceInr': 500,
            'onchain': null,
            'onchainError': {
              'error': 'Base Sepolia RPC failed',
              'code': 'RPC_UNAVAILABLE',
            },
          }),
          200,
        ),
      );

      final snapshot = await WalletService.getBalance();
      expect(snapshot.balanceInr, 500);
      expect(snapshot.onchainEth, isNull);
      expect(snapshot.onchainError, contains('Base Sepolia RPC failed'));
      expect(snapshot.onchainError, contains('RPC_UNAVAILABLE'));
    },
  );

  test('getBalance surfaces the backend error and code', () async {
    WalletService.clientOverride = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'error': 'Sign in required: missing bearer token',
          'code': 'UNAUTHORIZED',
        }),
        401,
      ),
    );

    await expectLater(
      WalletService.getBalance(),
      throwsA(
        isA<WalletApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.code, 'code', 'UNAUTHORIZED')
            .having(
              (e) => e.message,
              'message',
              'Sign in required: missing bearer token (UNAUTHORIZED)',
            ),
      ),
    );
  });

  test('createTopUp parses the Razorpay checkout URL', () async {
    WalletService.clientOverride = MockClient((request) async {
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['amountInr'], 500);
      return http.Response(
        jsonEncode({
          'id': 'topup-1',
          'amountInr': 500,
          'status': 'PENDING',
          'checkoutUrl': 'https://rzp.io/abc',
        }),
        201,
      );
    });

    final order = await WalletService.createTopUp(500);
    expect(order.id, 'topup-1');
    expect(order.status, 'PENDING');
    expect(order.checkoutUrl, 'https://rzp.io/abc');
  });

  test('createTopUp reports PSP_NOT_CONFIGURED verbatim', () async {
    WalletService.clientOverride = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'error':
              'Razorpay is not configured: set RAZORPAY_KEY_ID and '
              'RAZORPAY_KEY_SECRET on the backend.',
          'code': 'PSP_NOT_CONFIGURED',
        }),
        503,
      ),
    );

    await expectLater(
      WalletService.createTopUp(100),
      throwsA(
        isA<WalletApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.code, 'code', 'PSP_NOT_CONFIGURED'),
      ),
    );
  });

  test('getTopUp returns the server-confirmed balance', () async {
    WalletService.clientOverride = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'id': 'topup-1',
          'amountInr': 500,
          'status': 'PAID',
          'balanceInr': 1500,
        }),
        200,
      ),
    );

    final order = await WalletService.getTopUp('topup-1');
    expect(order.isPaid, isTrue);
    expect(order.balanceInr, 1500);
  });

  test('invalid JSON is an explicit error, not a silent zero', () async {
    WalletService.clientOverride = MockClient(
      (request) async => http.Response('<html>bad gateway</html>', 502),
    );

    await expectLater(
      WalletService.getBalance(),
      throwsA(
        isA<WalletApiException>().having(
          (e) => e.message,
          'message',
          contains('invalid JSON'),
        ),
      ),
    );
  });
}
