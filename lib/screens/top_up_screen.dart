import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../icons.dart';
import '../services/wallet_service.dart';
import '../state/wallet_store.dart';
import '../theme.dart';
import 'receive_screen.dart';

/// Real UPI top-up through a Razorpay payment link.
///
/// The customer enters their UPI ID and PIN inside Razorpay or their UPI app.
/// Bridgy only polls the backend, which verifies the payment with Razorpay
/// before crediting the ledger. A failure stays on screen verbatim.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({
    super.key,
    this.createOrder,
    this.fetchOrder,
    this.launchPayment,
  });

  /// Test seams. Production uses [WalletService] and [launchUrl].
  final Future<TopUpOrder> Function(double amountInr)? createOrder;
  final Future<TopUpOrder> Function(String id)? fetchOrder;
  final Future<bool> Function(Uri uri)? launchPayment;

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  static const _presets = [100.0, 500.0, 1000.0, 2000.0];
  static const _pollInterval = Duration(seconds: 2);
  static const _maxPolls = 300;

  final _amount = TextEditingController(text: '500');

  bool _busy = false;
  bool _polling = false;
  bool _fetching = false;
  String? _error;
  TopUpOrder? _order;
  Timer? _pollTimer;
  int _polls = 0;

  Future<TopUpOrder> _create(double amount) =>
      (widget.createOrder ?? WalletService.createTopUp)(amount);

  Future<TopUpOrder> _fetch(String id) =>
      (widget.fetchOrder ?? WalletService.getTopUp)(id);

  Future<bool> _launch(Uri uri) => widget.launchPayment != null
      ? widget.launchPayment!(uri)
      : launchUrl(uri, mode: LaunchMode.externalApplication);

  double? get _parsedAmount => double.tryParse(_amount.text.trim());

  @override
  void dispose() {
    _pollTimer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  void _pick(double value) {
    setState(() {
      _amount.text = value.toStringAsFixed(0);
      _error = null;
      _order = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _polling) return;

    final amount = _parsedAmount;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _order = null;
    });

    try {
      final order = await _create(amount);
      final checkoutUrl = order.checkoutUrl;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw const WalletApiException(
          'Backend returned no checkout URL.',
          code: 'NO_CHECKOUT_URL',
        );
      }
      final opened = await _launch(Uri.parse(checkoutUrl));
      if (!opened) {
        throw const WalletApiException(
          'Could not open the payment page. Install a browser or UPI app.',
          code: 'LAUNCH_FAILED',
        );
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _order = order;
        _polling = true;
        _polls = 0;
      });
      _startPolling(order.id);
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.toString();
      });
    }
  }

  void _startPolling(String id) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll(id));
  }

  Future<void> _poll(String id) async {
    if (_fetching) return;
    _fetching = true;
    _polls++;

    if (_polls > _maxPolls) {
      _stopPolling();
      setState(() {
        _error =
            'Payment not confirmed after 10 minutes. '
            'Open the payment page again if you have not paid.';
      });
      _fetching = false;
      return;
    }

    try {
      final order = await _fetch(id);
      if (!mounted) return;

      if (order.isPaid) {
        final balance = order.balanceInr;
        if (balance == null) {
          _stopPolling();
          setState(() {
            _error = 'Paid top-up returned no balance.';
            _polling = false;
          });
          return;
        }
        await WalletStore.instance.applyTopUp(
          amountInr: order.amountInr,
          balanceInr: balance,
        );
        if (!mounted) return;
        _stopPolling();
        setState(() {
          _polling = false;
          _order = order;
        });
      } else if (order.status == 'FAILED' || order.status == 'EXPIRED') {
        _stopPolling();
        setState(() {
          _polling = false;
          _error = 'Payment ${order.status.toLowerCase()}. No money was added.';
        });
      }
    } catch (failure) {
      if (!mounted) return;
      _stopPolling();
      setState(() {
        _polling = false;
        _error = failure.toString();
      });
    } finally {
      _fetching = false;
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
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
              _balanceCard(),
              const SizedBox(height: 22),
              Text(
                'Choose an amount',
                style: uiStyle(size: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map(_preset).toList(),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('topup-amount'),
                controller: _amount,
                enabled: !_busy && !_polling,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: displayStyle(size: 30, spacing: -1),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: displayStyle(size: 30, spacing: -1),
                  filled: true,
                  fillColor: AppColors.card,
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorBox(_error!),
              ],
              if (_polling) ...[const SizedBox(height: 14), _waitingBox()],
              if (_order != null && _order!.isPaid) ...[
                const SizedBox(height: 14),
                _successBox(_order!),
              ],
              const SizedBox(height: 22),
              _submitButton(),
              const SizedBox(height: 12),
              Text(
                'You enter your UPI ID and UPI PIN inside Razorpay or your UPI '
                'app. Bridgy never sees the PIN. The wallet is credited only '
                'after Razorpay confirms the payment. UPI needs Razorpay keys '
                'on the backend.',
                textAlign: TextAlign.center,
                style: uiStyle(size: 11, color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Testnet ETH is credited to the ₹ ledger at the backend demo '
                'rate. It has no cash value.',
                textAlign: TextAlign.center,
                style: uiStyle(size: 10, color: AppColors.muted, height: 1.45),
              ),
              TextButton(
                key: const Key('topup-testnet'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReceiveScreen(),
                  ),
                ),
                child: Text(
                  'Top up with Base Sepolia testnet ETH instead',
                  textAlign: TextAlign.center,
                  style: uiStyle(size: 12, color: AppColors.goldText),
                ),
              ),
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
          key: const Key('topup-back'),
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
            Text('Top up', style: displayStyle(size: 22, spacing: -0.6)),
            Text(
              'UPI via Razorpay',
              style: uiStyle(size: 11, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _balanceCard() {
    return ListenableBuilder(
      listenable: WalletStore.instance,
      builder: (context, _) {
        final store = WalletStore.instance;
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
                    'CURRENT BALANCE',
                    style: uiStyle(
                      size: 10,
                      weight: FontWeight.w700,
                      color: const Color(0x99FFFFFF),
                      spacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    store.balanceText,
                    key: const Key('topup-balance'),
                    style: displayStyle(
                      size: 30,
                      spacing: -1,
                      color: AppColors.card,
                    ),
                  ),
                  if (store.onchainEth != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${store.onchainEth!.toStringAsFixed(6)} ETH · Base Sepolia',
                      style: uiStyle(size: 10, color: const Color(0x99FFFFFF)),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              const AppIcon(
                Icons8.arrowDownLeft,
                size: 22,
                color: AppColors.gold,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _preset(double value) {
    final selected = _parsedAmount == value;
    return InkWell(
      key: Key('topup-preset-${value.toStringAsFixed(0)}'),
      onTap: _busy || _polling ? null : () => _pick(value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.dark : AppColors.border,
          ),
        ),
        child: Text(
          '₹${value.toStringAsFixed(0)}',
          style: uiStyle(
            size: 13,
            weight: FontWeight.w700,
            color: selected ? AppColors.card : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _waitingBox() {
    return Container(
      key: const Key('topup-waiting'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldDeep),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Waiting for Razorpay to confirm the payment…',
              style: uiStyle(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.goldText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      key: const Key('topup-error'),
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

  Widget _successBox(TopUpOrder order) {
    return Container(
      key: const Key('topup-success'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const AppIcon(Icons8.check, size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Added ₹${order.amountInr.toStringAsFixed(2)}. '
              'New balance ₹${(order.balanceInr ?? 0).toStringAsFixed(2)}.',
              style: uiStyle(
                size: 12,
                weight: FontWeight.w600,
                color: const Color(0xFF15803D),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    final amount = _parsedAmount ?? 0;
    final label = _busy
        ? 'Opening UPI…'
        : _polling
        ? 'Waiting for payment…'
        : 'Top up ₹${amount.toStringAsFixed(0)} with UPI';

    return InkResponse(
      key: const Key('topup-submit'),
      onTap: _busy || _polling ? null : _submit,
      radius: 28,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _busy || _polling ? AppColors.pill : AppColors.dark,
          borderRadius: BorderRadius.circular(999),
          boxShadow: _busy || _polling ? null : AppShadows.pill,
        ),
        child: Center(
          child: Text(
            label,
            style: uiStyle(
              size: 14,
              weight: FontWeight.w700,
              color: _busy || _polling ? AppColors.muted : AppColors.card,
            ),
          ),
        ),
      ),
    );
  }
}
