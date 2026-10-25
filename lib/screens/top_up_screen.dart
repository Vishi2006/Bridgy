import 'package:flutter/material.dart';

import '../icons.dart';
import '../services/wallet_service.dart';
import '../state/wallet_store.dart';
import '../theme.dart';

/// Top-up sheet for the Bridgy ledger.
///
/// Every tap calls the backend and applies the balance it returns. There is no
/// local credit path: a failure stays on screen with the exact backend message.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key, this.onSubmit});

  /// Test seam only. Production calls [WalletService.topUp].
  final Future<TopUpResult> Function(double amountInr)? onSubmit;

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  static const _presets = [100.0, 500.0, 1000.0, 2000.0];

  final _amount = TextEditingController(text: '500');
  bool _busy = false;
  String? _error;
  TopUpResult? _result;

  double? get _parsedAmount => double.tryParse(_amount.text.trim());

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pick(double value) {
    setState(() {
      _amount.text = value.toStringAsFixed(0);
      _error = null;
      _result = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;

    final amount = _parsedAmount;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final submit = widget.onSubmit ?? WalletService.topUp;
      final result = await submit(amount);
      await WalletStore.instance.applyTopUp(
        amountInr: result.amountInr,
        balanceInr: result.balanceInr,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
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
                children: _presets.map((value) => _preset(value)).toList(),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('topup-amount'),
                controller: _amount,
                enabled: !_busy,
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
                  if (_error != null || _result != null) {
                    setState(() {
                      _error = null;
                      _result = null;
                    });
                  }
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorBox(_error!),
              ],
              if (_result != null) ...[
                const SizedBox(height: 14),
                _successBox(_result!),
              ],
              const SizedBox(height: 22),
              _submitButton(),
              const SizedBox(height: 12),
              Text(
                'Demo ledger. This credits the shared Bridgy wallet through the '
                'backend; it does not move bank money.',
                textAlign: TextAlign.center,
                style: uiStyle(size: 11, color: AppColors.muted, height: 1.5),
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
              'balance is stored in the backend',
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
      onTap: _busy ? null : () => _pick(value),
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

  Widget _successBox(TopUpResult result) {
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
              'Added ₹${result.amountInr.toStringAsFixed(2)}. '
              'New balance ₹${result.balanceInr.toStringAsFixed(2)}.',
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
        ? 'Adding ₹${amount.toStringAsFixed(0)}…'
        : 'Top up ₹${amount.toStringAsFixed(0)}';

    return InkResponse(
      key: const Key('topup-submit'),
      onTap: _busy ? null : _submit,
      radius: 28,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _busy ? AppColors.pill : AppColors.dark,
          borderRadius: BorderRadius.circular(999),
          boxShadow: _busy ? null : AppShadows.pill,
        ),
        child: Center(
          child: Text(
            label,
            style: uiStyle(
              size: 14,
              weight: FontWeight.w700,
              color: _busy ? AppColors.muted : AppColors.card,
            ),
          ),
        ),
      ),
    );
  }
}
