import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../state/policy_controller.dart';
import '../theme.dart';
import 'top_up_screen.dart';

/// Spending policy editor: smart wallet, per-transaction limit, daily limit, expiry.
class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key, this.embedded = false});

  /// Shown as a shell tab: no back arrow, footer provides navigation.
  final bool embedded;

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  final _controller = PolicyController.instance;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  int get _hoursLeft =>
      _controller.expiresAt.difference(DateTime.now()).inHours.clamp(0, 999);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      _smartWalletCard(),
                      const SizedBox(height: 14),
                      _limitCard(),
                      const SizedBox(height: 14),
                      _expiryCard(),
                      const SizedBox(height: 14),
                      _statusCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        if (!widget.embedded) ...[
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
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Policy', style: displayStyle(size: 22, spacing: -0.6)),
            Text(
              'agent session key limits',
              style: uiStyle(size: 11, color: AppColors.muted),
            ),
          ],
        ),
        const Spacer(),
        InkResponse(
          onTap: () async {
            await _controller.save();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Policy ${_controller.syncStatus}')),
            );
          },
          radius: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Save',
              style: uiStyle(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.card,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _smartWalletCard() {
    final addr = _controller.smartWalletAddress;
    final truncated = addr.length > 14
        ? '${addr.substring(0, 8)}...${addr.substring(addr.length - 6)}'
        : addr;

    return _card(
      children: [
        Row(
          children: [
            Text(
              'Smart Account',
              style: uiStyle(size: 12, color: AppColors.muted),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Base Sepolia',
                style: uiStyle(
                  size: 10,
                  weight: FontWeight.w700,
                  color: AppColors.goldText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                truncated,
                style: displayStyle(size: 17, spacing: -0.4),
              ),
            ),
            IconButton(
              icon: const AppIcon(Icons8.copy, size: 16, color: AppColors.ink),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: addr));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wallet address copied to clipboard'),
                  ),
                );
              },
              tooltip: 'Copy address',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Session Key Active • ZeroDev Kernel v0.3.1',
              style: uiStyle(size: 11, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InkResponse(
          key: const Key('policy-topup'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const TopUpScreen())),
          radius: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(
                  Icons8.arrowDownLeft,
                  size: 15,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top up wallet',
                  style: uiStyle(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.card,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _limitCard() {
    return _card(
      children: [
        Text(
          'Per transaction hard cap',
          style: uiStyle(size: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${_controller.perTxLimitInr.round()}',
          style: displayStyle(size: 30, spacing: -1.2),
        ),
        Slider(
          value: _controller.perTxLimitInr,
          min: 50,
          max: 500,
          divisions: 9,
          activeColor: AppColors.gold,
          label: '₹${_controller.perTxLimitInr.round()}',
          onChanged: (v) => _controller.setPerTxLimit(v),
        ),
        const Divider(color: AppColors.border, height: 28),
        Text(
          'Daily spending budget',
          style: uiStyle(size: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${_controller.dailyLimitInr.round()}',
          style: displayStyle(size: 30, spacing: -1.2),
        ),
        Slider(
          value: _controller.dailyLimitInr,
          min: 100,
          max: 2000,
          divisions: 19,
          activeColor: AppColors.gold,
          label: '₹${_controller.dailyLimitInr.round()}',
          onChanged: (v) => _controller.setDailyLimit(v),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${_controller.policy.remainingTodayInr.round()} left today · '
          '₹${_controller.spentTodayInr.round()} spent',
          style: uiStyle(size: 12, color: AppColors.goldText),
        ),
      ],
    );
  }

  Widget _expiryCard() {
    const presets = {
      '1 hour': Duration(hours: 1),
      '24 hours': Duration(hours: 24),
      '7 days': Duration(days: 7),
    };
    return _card(
      children: [
        Row(
          children: [
            Text(
              'Permission expiry',
              style: uiStyle(size: 12, color: AppColors.muted),
            ),
            const Spacer(),
            Text(
              '${_hoursLeft}h left',
              style: uiStyle(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.goldText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in presets.entries)
                    InkResponse(
                      onTap: () => _controller.setExpiry(
                        DateTime.now().add(entry.value),
                      ),
                      radius: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entry.key,
                          style: uiStyle(size: 12, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkResponse(
              onTap: () async {
                final ok = await _controller.renewSession();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Session renewed for 24 hours on Base Sepolia'
                          : 'Session renewed locally',
                    ),
                  ),
                );
              },
              radius: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Renew 24h',
                  style: uiStyle(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusCard() {
    return _card(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: BridgyPolicyStatus.colorFor(_controller.syncStatus),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'status: ${_controller.syncStatus}',
              style: uiStyle(size: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Policies are enforced cryptographically on Base Sepolia by ZeroDev '
          'Kernel v0.3.1. When an agent action exceeds the ₹${_controller.perTxLimitInr.round()} '
          'per-tx limit, it automatically escalates to your biometric approval.',
          style: uiStyle(size: 11.5, color: AppColors.muted, height: 1.45),
        ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

abstract final class BridgyPolicyStatus {
  static Color colorFor(String status) {
    if (status.contains('failed')) return AppColors.negative;
    if (status.contains('saved') || status.contains('synced'))
      return AppColors.gold;
    return AppColors.muted;
  }
}
