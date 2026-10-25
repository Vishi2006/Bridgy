import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../icons.dart';
import '../services/wallet_service.dart';
import '../theme.dart';

/// Base Sepolia receive screen for MetaMask.
///
/// Shows the backend's on-chain address, a QR, and the live testnet balance.
/// The INR ledger balance is separate and is never mixed into this screen.
class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key, this.load});

  /// Test seam. Production uses [WalletService.getOnChain].
  final Future<OnChainWallet> Function()? load;

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  OnChainWallet? _wallet;
  String? _error;
  bool _busy = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wallet = await (widget.load ?? WalletService.getOnChain)();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _busy = false;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            children: [
              _header(),
              const SizedBox(height: 20),
              if (_busy && _wallet == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.goldDeep,
                      ),
                    ),
                  ),
                ),
              if (_error != null) ...[
                _errorBox(_error!),
                const SizedBox(height: 14),
                TextButton(
                  key: const Key('receive-retry'),
                  onPressed: _refresh,
                  child: Text('Retry', style: uiStyle(size: 12)),
                ),
              ],
              if (_wallet != null) ...[
                _addressCard(_wallet!),
                const SizedBox(height: 14),
                _balanceCard(_wallet!),
                const SizedBox(height: 14),
                _instructions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        InkResponse(
          onTap: () => Navigator.of(context).maybePop(),
          radius: 22,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: AppIcon(Icons8.back, size: 16, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receive', style: displayStyle(size: 22, spacing: -0.6)),
            Text(
              'Base Sepolia • MetaMask',
              style: uiStyle(size: 11, color: AppColors.muted),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          key: const Key('receive-refresh'),
          onPressed: _busy ? null : _refresh,
          icon: const AppIcon(Icons8.bolt, size: 18, color: AppColors.ink),
          tooltip: 'Refresh on-chain balance',
        ),
      ],
    );
  }

  Widget _addressCard(OnChainWallet wallet) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'BRIDGY BASE SEPOLIA VAULT',
                style: uiStyle(
                  size: 10,
                  weight: FontWeight.w700,
                  color: AppColors.muted,
                  spacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '${wallet.network} (${wallet.chainId})',
                style: uiStyle(size: 10, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: QrImageView(
              data: wallet.address,
              version: QrVersions.auto,
              size: 188,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            wallet.address,
            key: const Key('receive-address'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 12,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                key: const Key('receive-copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: wallet.address));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied')),
                  );
                },
                icon: const AppIcon(
                  Icons8.copy,
                  size: 15,
                  color: AppColors.ink,
                ),
                label: Text('Copy', style: uiStyle(size: 12)),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(wallet.explorer),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const AppIcon(
                  Icons8.arrowUpRight,
                  size: 15,
                  color: AppColors.ink,
                ),
                label: Text('Explorer', style: uiStyle(size: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(OnChainWallet wallet) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ON-CHAIN BALANCE',
                style: uiStyle(
                  size: 10,
                  weight: FontWeight.w700,
                  color: const Color(0x99FFFFFF),
                  spacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${wallet.balanceEth.toStringAsFixed(6)} ETH',
                key: const Key('receive-balance'),
                style: displayStyle(
                  size: 26,
                  spacing: -0.8,
                  color: AppColors.card,
                ),
              ),
            ],
          ),
          const Spacer(),
          const AppIcon(Icons8.bolt, size: 22, color: AppColors.gold),
        ],
      ),
    );
  }

  Widget _instructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to see this in MetaMask',
            style: uiStyle(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '1. Open MetaMask and add the Base Sepolia network (chain ID '
            '84532).\n'
            '2. Import this address as a watched account, or send testnet ETH '
            'to it.\n'
            '3. Refresh here: the balance above reads directly from the Base '
            'Sepolia RPC.\n\n'
            'This is the testnet vault for this Bridgy deployment. Testnet ETH '
            'is separate from the ₹ ledger balance and has no cash value.',
            style: uiStyle(size: 12, color: AppColors.muted, height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      key: const Key('receive-error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(Icons8.alert, size: 16, color: AppColors.negative),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: uiStyle(size: 12, color: AppColors.negative, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
