import 'package:flutter/material.dart';

import '../icons.dart';
import '../state/policy_controller.dart';
import '../theme.dart';

/// Spending policy editor: per-transaction limit, daily limit, expiry.
class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
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
            setState(() {});
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

  Widget _limitCard() {
    return _card(
      children: [
        Text('Per transaction', style: uiStyle(size: 12, color: AppColors.muted)),
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
          onChanged: (v) => setState(() => _controller.setPerTxLimit(v)),
        ),
        const Divider(color: AppColors.border, height: 28),
        Text('Daily limit', style: uiStyle(size: 12, color: AppColors.muted)),
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
          onChanged: (v) => setState(() => _controller.setDailyLimit(v)),
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
        Wrap(
          spacing: 8,
          children: [
            for (final entry in presets.entries)
              InkResponse(
                onTap: () => setState(
                  () => _controller.setExpiry(DateTime.now().add(entry.value)),
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
              'backend: ${_controller.syncStatus}',
              style: uiStyle(size: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Limits are also enforced by the session key on Base Sepolia once '
          'the wallet leg is connected. Exceeding the per-transaction limit '
          'escalates to owner approval.',
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

abstract final class BridgyPolicyStatus {
  static Color colorFor(String status) {
    if (status.contains('failed')) return AppColors.negative;
    if (status.contains('saved') || status == 'synced') return AppColors.gold;
    return AppColors.muted;
  }
}
