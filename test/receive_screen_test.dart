import 'package:bridgy/screens/receive_screen.dart';
import 'package:bridgy/services/wallet_service.dart';
import 'package:bridgy/unipay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Future<OnChainWallet> Function() load) => MaterialApp(
    theme: unipayTheme(),
    home: ReceiveScreen(load: load),
  );

  testWidgets('shows the on-chain address and live ETH balance', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        () async => const OnChainWallet(
          address: '0xA00B4c7954F40B896037B884BDCCc8d6565C960b',
          network: 'Base Sepolia',
          chainId: 84532,
          balanceEth: 0,
          explorer: 'https://sepolia.basescan.org/address/0xA00B',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('0xA00B4c7954F40B896037B884BDCCc8d6565C960b'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('receive-balance')), findsOneWidget);
    expect(find.text('0.000000 ETH'), findsOneWidget);
    expect(find.byKey(const Key('receive-copy')), findsOneWidget);
  });

  testWidgets('backend error is shown verbatim', (tester) async {
    await tester.pumpWidget(
      app(
        () async => throw const WalletApiException(
          'Base Sepolia RPC unreachable (ONCHAIN_READ_FAILED)',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('receive-error')), findsOneWidget);
    expect(
      find.text('Base Sepolia RPC unreachable (ONCHAIN_READ_FAILED)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('receive-retry')), findsOneWidget);
  });
}
