import 'package:bridgy/services/policy.dart';
import 'package:bridgy/services/upi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wallet = WalletPolicy(
    perTxLimitInr: 200,
    dailyLimitInr: 500,
    spentTodayInr: 320,
    expiresAt: DateTime(2026, 10, 25, 3),
  );
  final now = DateTime(2026, 10, 24, 22);

  test('allows an amount inside both limits', () {
    expect(wallet.evaluate(150, now: now), PolicyDecision.allow);
  });

  test('owner approval at and above the per-transaction limit', () {
    final fresh = WalletPolicy(
      perTxLimitInr: 200,
      dailyLimitInr: 500,
      spentTodayInr: 0,
      expiresAt: DateTime(2026, 10, 25, 3),
    );
    expect(fresh.evaluate(200, now: now), PolicyDecision.allow);
    expect(fresh.evaluate(201, now: now), PolicyDecision.ownerApproval);
  });

  test('daily budget caps the owner-approval path too', () {
    expect(wallet.evaluate(201, now: now), PolicyDecision.reject);
  });

  test('rejects beyond the remaining daily budget', () {
    expect(wallet.evaluate(180, now: now), PolicyDecision.allow);
    expect(wallet.evaluate(181, now: now), PolicyDecision.reject);
  });

  test('rejects after expiry and for non-positive amounts', () {
    expect(wallet.evaluate(10, now: DateTime(2026, 10, 25, 3, 1)),
        PolicyDecision.reject);
    expect(wallet.evaluate(0, now: now), PolicyDecision.reject);
  });

  test('parses a upi intent into merchant, amount and note', () {
    final intent = UpiIntent.parse(
      'upi://pay?pa=blinkit@axisbank&pn=Blinkit&am=380.50&cu=INR&tn=Order%20123',
    );
    expect(intent, isNotNull);
    expect(intent!.merchantVpa, 'blinkit@axisbank');
    expect(intent.merchantName, 'Blinkit');
    expect(intent.amountInr, 380.50);
    expect(intent.note, 'Order 123');
  });

  test('rejects intents without a payee or amount', () {
    expect(UpiIntent.parse('upi://pay?pn=Blinkit'), isNull);
    expect(UpiIntent.parse('upi://pay?pa=blinkit@axisbank'), isNull);
    expect(UpiIntent.parse('upi://pay?pa=blinkit@axisbank&am=0'), isNull);
    expect(UpiIntent.parse('https://pay?pa=blinkit@axisbank&am=10'), isNull);
  });
}
