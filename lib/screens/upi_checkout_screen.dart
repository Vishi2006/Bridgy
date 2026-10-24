import 'package:flutter/material.dart';

import '../services/policy.dart';
import '../services/upi.dart';
import '../state/policy_controller.dart';
import '../theme.dart';

/// Entry point for `upi://pay` checkouts. Applies the spending policy and
/// escalates to owner approval when the amount exceeds the session key limit.
class UpiCheckoutScreen extends StatelessWidget {
  const UpiCheckoutScreen({super.key, required this.link});

  final String link;

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
          Text('Pay with Bridgy', style: displayStyle(size: 26, spacing: -1)),
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
          _decisionCard(decision, intent.amountInr, controller),
          const Spacer(),
          _action(context, decision, intent),
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
        'The agent session key can pay this amount without you.',
        AppColors.goldText,
      ),
      PolicyDecision.ownerApproval => (
        'Owner approval required',
        '₹${amount.round()} exceeds the ₹${controller.perTxLimitInr.round()} '
            'per-transaction limit. Your key must sign.',
        AppColors.goldDeep,
      ),
      PolicyDecision.reject => (
        'Blocked by policy',
        'Daily budget, expiry, or amount check failed. The contract would '
            'revert this transaction.',
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
          Text(
            title,
            style: uiStyle(size: 14, weight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 8),
          Text(detail, style: uiStyle(size: 12, color: AppColors.muted, height: 1.5)),
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

  Widget _action(BuildContext context, PolicyDecision decision, UpiIntent intent) {
    final enabled = decision != PolicyDecision.reject;
    final label = decision == PolicyDecision.ownerApproval
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  builder: (_) => OwnerApprovalSheet(
                    amountInr: intent.amountInr,
                    merchantName: intent.merchantName,
                  ),
                );
                if (approved != true || !context.mounted) return;
              }
              _submit(context);
            }
          : null,
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

  Future<void> _submit(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Wallet not connected: the ERC-4337 settlement call lands next. '
          'Nothing was charged.',
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

/// Owner-key confirmation. Biometric gating is deferred until `local_auth` is
/// wired; the sheet only reports intent to sign.
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
          Text('Owner approval', style: displayStyle(size: 22, spacing: -0.6)),
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
                child: Text(
                  'Approve with owner key',
                  style: uiStyle(size: 13, weight: FontWeight.w700),
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
