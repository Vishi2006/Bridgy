import 'package:flutter/material.dart';

import '../icons.dart';
import '../services/policy.dart';
import '../services/upi.dart';
import '../services/wallet_service.dart';
import '../state/policy_controller.dart';
import '../state/wallet_store.dart';
import '../theme.dart';

/// Entry point for `upi://pay` checkouts. Applies the ZeroDev spending policy and
/// escalates to owner biometric approval when the amount exceeds the session key limit.
class UpiCheckoutScreen extends StatefulWidget {
  const UpiCheckoutScreen({super.key, required this.link});

  final String link;

  @override
  State<UpiCheckoutScreen> createState() => _UpiCheckoutScreenState();
}

class _UpiCheckoutScreenState extends State<UpiCheckoutScreen> {
  bool _busy = false;

  String get link => widget.link;

  @override
  Widget build(BuildContext context) {
    final intent = UpiIntent.parse(link);
    if (intent == null) {
      return _scaffold(
        context,
        body: Text(
          'Not a valid UPI payment request.',
          style: uiStyle(size: 14, color: AppColors.negative),
        ),
      );
    }

    final controller = PolicyController.instance;
    final decision = controller.evaluate(intent.amountInr);

    return _scaffold(
      context,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Pay with Bridgy',
                style: displayStyle(size: 26, spacing: -1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'ERC-4337',
                  style: uiStyle(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.goldText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            intent.merchantName,
            style: uiStyle(size: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          Text(
            '₹${intent.amountInr.toStringAsFixed(2)}',
            style: displayStyle(size: 44, spacing: -2),
          ),
          const SizedBox(height: 6),
          Text(
            intent.merchantVpa,
            style: uiStyle(size: 12, color: AppColors.muted),
          ),
          if (intent.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(intent.note, style: uiStyle(size: 12, color: AppColors.muted)),
          ],
          const SizedBox(height: 22),
          InkWell(
            onTap: decision == PolicyDecision.reject
                ? () => _showBlockedDialog(
                    context,
                    amountInr: intent.amountInr,
                    remainingInr: controller.policy.remainingTodayInr,
                  )
                : null,
            borderRadius: BorderRadius.circular(22),
            child: _decisionCard(decision, intent.amountInr, controller),
          ),
          const Spacer(),
          _action(context, decision, intent, controller),
        ],
      ),
    );
  }

  Widget _decisionCard(
    PolicyDecision decision,
    double amount,
    PolicyController controller,
  ) {
    final (title, detail, color) = switch (decision) {
      PolicyDecision.allow => (
        'Within policy',
        'The AI agent session key can authorize and sign this transaction autonomously without you.',
        AppColors.goldText,
      ),
      PolicyDecision.ownerApproval => (
        'Owner approval required',
        '₹${amount.round()} exceeds the ₹${controller.perTxLimitInr.round()} '
            'per-transaction limit. Your key must sign.',
        AppColors.goldDeep,
      ),
      PolicyDecision.reject => (
        'Blocked by policy (Low Budget)',
        'Daily budget or expiry check failed. Tap to see guardrail details. '
            'The contract would revert this transaction.',
        AppColors.negative,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: uiStyle(size: 14, weight: FontWeight.w700, color: color),
              ),
              const Spacer(),
              if (decision == PolicyDecision.allow)
                const AppIcon(
                  Icons8.shieldCheck,
                  size: 16,
                  color: AppColors.gold,
                )
              else if (decision == PolicyDecision.ownerApproval)
                const AppIcon(
                  Icons8.fingerprint,
                  size: 16,
                  color: AppColors.goldDeep,
                )
              else
                const AppIcon(
                  Icons8.alert,
                  size: 16,
                  color: AppColors.negative,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: uiStyle(size: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'per-tx ₹${controller.perTxLimitInr.round()} · '
            'daily ₹${controller.dailyLimitInr.round()} · '
            '₹${controller.policy.remainingTodayInr.round()} left',
            style: uiStyle(size: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context,
    PolicyDecision decision,
    UpiIntent intent,
    PolicyController controller,
  ) {
    final enabled = decision != PolicyDecision.reject && !_busy;
    final label = _busy
        ? 'Paying…'
        : decision == PolicyDecision.ownerApproval
        ? 'Approve as owner'
        : 'Pay ₹${intent.amountInr.toStringAsFixed(0)}';

    return InkResponse(
      onTap: enabled
          ? () async {
              if (decision == PolicyDecision.ownerApproval) {
                final approved = await showModalBottomSheet<bool>(
                  context: context,
                  backgroundColor: AppColors.card,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  builder: (_) => OwnerApprovalSheet(
                    amountInr: intent.amountInr,
                    merchantName: intent.merchantName,
                  ),
                );
                if (approved != true || !context.mounted) return;
              }
              _submit(context, decision, intent, controller);
            }
          : () => _showBlockedDialog(
              context,
              amountInr: intent.amountInr,
              remainingInr: controller.policy.remainingTodayInr,
            ),
      radius: 30,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled ? AppColors.dark : AppColors.pill,
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled ? AppShadows.pill : null,
        ),
        child: Center(
          child: Text(
            enabled ? label : 'Payment blocked',
            style: uiStyle(
              size: 14,
              weight: FontWeight.w700,
              color: enabled ? AppColors.card : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    PolicyDecision decision,
    UpiIntent intent,
    PolicyController controller,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    final authType = decision == PolicyDecision.ownerApproval
        ? 'OWNER_PAID'
        : 'AGENT_PAID';

    try {
      final result = decision == PolicyDecision.ownerApproval
          ? await WalletService.payWithOwner(
              amountInr: intent.amountInr,
              merchantName: intent.merchantName,
              merchantVpa: intent.merchantVpa,
            )
          : await WalletService.payWithAgent(
              amountInr: intent.amountInr,
              merchantName: intent.merchantName,
              merchantVpa: intent.merchantVpa,
            );
      await controller.load();
      await WalletStore.instance.refresh();
      if (!mounted) return;
      _showSuccessDialog(
        context,
        merchant: intent.merchantName,
        amountInr: intent.amountInr,
        authType: authType,
        txHash: result.txHash,
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorDialog(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIcon(
                  Icons8.alert,
                  size: 20,
                  color: AppColors.negative,
                ),
                const SizedBox(width: 10),
                Text(
                  'Payment failed',
                  style: displayStyle(size: 20, spacing: -0.4),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              key: const Key('upi-payment-error'),
              style: uiStyle(size: 12, color: AppColors.negative, height: 1.45),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Close', style: uiStyle(size: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context, {
    required String merchant,
    required double amountInr,
    required String authType,
    String? txHash,
  }) {
    final truncatedHash = txHash != null && txHash.length > 14
        ? '${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 6)}'
        : (txHash ?? 'ledger entry');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Center(
                child: AppIcon(
                  Icons8.check,
                  size: 28,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Settled!',
              style: displayStyle(size: 22, spacing: -0.6),
            ),
            const SizedBox(height: 6),
            Text(
              '₹${amountInr.toStringAsFixed(2)} to $merchant',
              style: uiStyle(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Settlement Rail:',
                        style: uiStyle(size: 11.5, color: AppColors.muted),
                      ),
                      Text(
                        'Bridgy UPI Vault (INR)',
                        style: uiStyle(size: 11.5, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Security Policy:',
                        style: uiStyle(size: 11.5, color: AppColors.muted),
                      ),
                      Text(
                        authType,
                        style: uiStyle(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: AppColors.goldText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ledger reference:',
                        style: uiStyle(size: 11.5, color: AppColors.muted),
                      ),
                      Text(
                        truncatedHash,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            InkResponse(
              onTap: () => Navigator.of(ctx).pop(),
              radius: 24,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    'Return to App',
                    style: uiStyle(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.card,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockedDialog(
    BuildContext context, {
    required double amountInr,
    required double remainingInr,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Center(
                child: AppIcon(
                  Icons8.alert,
                  size: 28,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Blocked!',
              style: displayStyle(size: 22, spacing: -0.6),
            ),
            const SizedBox(height: 6),
            Text(
              'Insufficient Daily Budget / Low Fund',
              style: uiStyle(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.negative,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requested: ₹${amountInr.round()} • Remaining Budget: ₹${remainingInr.round()}',
                    style: uiStyle(size: 12, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The ZeroDev smart contract guardrail reverted this transaction. '
                    'The autonomous AI agent is mathematically prevented from spending more than your configured daily limit.',
                    style: uiStyle(
                      size: 11.5,
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            InkResponse(
              onTap: () => Navigator.of(ctx).pop(),
              radius: 24,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    'Dismiss & Keep Safe',
                    style: uiStyle(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.card,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scaffold(BuildContext context, {required Widget body}) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: body,
        ),
      ),
    );
  }
}

/// Owner-key confirmation modal.
class OwnerApprovalSheet extends StatelessWidget {
  const OwnerApprovalSheet({
    super.key,
    required this.amountInr,
    required this.merchantName,
  });

  final double amountInr;
  final String merchantName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Owner approval',
                style: displayStyle(size: 22, spacing: -0.6),
              ),
              const Spacer(),
              const AppIcon(
                Icons8.fingerprint,
                size: 20,
                color: AppColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$merchantName wants ₹${amountInr.toStringAsFixed(2)}, above the '
            'session key limit. Approving signs with the owner key.',
            style: uiStyle(size: 12.5, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          InkResponse(
            onTap: () => Navigator.of(context).pop(true),
            radius: 26,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppIcon(
                      Icons8.fingerprint,
                      size: 18,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Approve with owner key',
                      style: uiStyle(size: 13, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: uiStyle(size: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
