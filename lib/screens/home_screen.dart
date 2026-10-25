import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/backend.dart';
import '../state/wallet_store.dart';
import '../theme.dart';
import '../unipay.dart';
import 'send_money_screen.dart';
import 'top_up_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenSend});

  final VoidCallback onOpenSend;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: U.bg,
      child: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListenableBuilder(
              listenable: WalletStore.instance,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _notification(context),
                    const SizedBox(height: 22),
                    Text(
                      'Recent Activity',
                      style: uText(
                        size: 17,
                        weight: FontWeight.w700,
                        spacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...WalletStore.instance.transactions.map(
                      (tx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityRow(
                          tx: tx,
                          onTap: () => _receipt(context, tx),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notification(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Notification',
          style: uText(size: 17, weight: FontWeight.w700, spacing: -0.3),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _openSend(context, donate: true),
          child: Container(
            height: 86,
            decoration: BoxDecoration(
              color: U.lightBlue,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -26,
                  bottom: -26,
                  child: Container(
                    width: 80,
                    decoration: const BoxDecoration(
                      color: U.pink,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(44),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 21,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [U.red, U.red, Colors.black, Colors.black],
                        stops: [0, 0.5, 0.5, 1],
                      ),
                      boxShadow: [
                        BoxShadow(color: Color(0x26000000), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Donate for Ukraine',
                        style: uText(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                          spacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Each coin is a step towards victory!',
                        style: uText(
                          size: 11,
                          weight: FontWeight.w500,
                          color: const Color(0xFFDBEAFE),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openSend(BuildContext context, {bool donate = false}) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) =>
            SendMoneyScreen(donate: donate, onSent: () {}),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  void _receipt(BuildContext context, WalletTx tx) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: U.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: U.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              tx.title,
              style: uText(size: 22, weight: FontWeight.w700, spacing: -0.6),
            ),
            const SizedBox(height: 6),
            Text(tx.subtitle, style: uText(size: 13, color: U.grey)),
            const SizedBox(height: 22),
            Text(
              '${tx.amount < 0 ? '-' : '+'}₹ ${tx.amount.abs().toStringAsFixed(2)}',
              style: uText(size: 34, weight: FontWeight.w800, spacing: -1),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed · Visa •••• 1214',
              style: uText(size: 12, color: U.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header();

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with WidgetsBindingObserver {
  bool _primary = false;
  Timer? _balanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WalletStore.instance.refresh();
    _balanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      WalletStore.instance.refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WalletStore.instance.refresh();
    }
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: ListenableBuilder(
            listenable: WalletStore.instance,
            builder: (context, _) => Column(
              children: [
                const Row(
                  children: [
                    Text(
                      'BRIDGY',
                      style: TextStyle(
                        fontFamily: UF.sans,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: Color(0x99FFFFFF),
                      ),
                    ),
                    Spacer(),
                    _AccountChip(),
                  ],
                ),
                const SizedBox(height: 10),
                _card(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(false),
                    const SizedBox(width: 6),
                    _dot(true),
                    const SizedBox(width: 6),
                    _dot(false),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _action(
                        'Withdraw',
                        UArt.arrowUpRight,
                        () => _moneySheet(context, withdraw: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _action('Top up', UArt.arrowDownLeft, _openTopUp),
                    ),
                  ],
                ),
                if (WalletStore.instance.error != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    key: const Key('balance-error'),
                    onTap: () => WalletStore.instance.refresh(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x33DC2626),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x66FCA5A5)),
                      ),
                      child: Text(
                        'Balance unavailable: ${WalletStore.instance.error}\n'
                        'Tap to retry.',
                        style: uText(
                          size: 11,
                          color: const Color(0xFFFCA5A5),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTopUp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TopUpScreen()));
  }

  Widget _card() {
    return AspectRatio(
      aspectRatio: 1.62,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFC400),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: SvgPicture.string(UArt.card, fit: BoxFit.fill),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => setState(() => _primary = !_primary),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 40,
                  height: 24,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    alignment: _primary
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _primary ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                        border: _primary
                            ? Border.all(color: const Color(0xFF404040))
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: WalletStore.instance.balanceWhole,
                            style: uText(
                              size: 34,
                              weight: FontWeight.w800,
                              spacing: -1.4,
                              height: 1,
                              color: const Color(0xFF171717),
                            ),
                          ),
                          TextSpan(
                            text: WalletStore.instance.balanceFraction,
                            style: uText(
                              size: 34,
                              weight: FontWeight.w800,
                              spacing: -1.4,
                              height: 1,
                              color: const Color(0xFF262626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CREDIT',
                            style: uText(
                              size: 11,
                              weight: FontWeight.w600,
                              color: const Color(0xFF525252),
                              spacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '•••• •••• ••••  ',
                                  style: uText(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    spacing: 1.6,
                                    color: const Color(0xFF0A0A0A),
                                  ),
                                ),
                                TextSpan(
                                  text: '1214',
                                  style: uText(
                                    size: 14,
                                    weight: FontWeight.w800,
                                    color: const Color(0xFF0A0A0A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'EXP DATE',
                            style: uText(
                              size: 10,
                              weight: FontWeight.w700,
                              color: const Color(0xFF404040),
                              spacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '04 / 26',
                            style: uText(
                              size: 12,
                              weight: FontWeight.w700,
                              color: const Color(0xFF0A0A0A),
                              spacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: active ? 10 : 6,
    height: 6,
    decoration: BoxDecoration(
      color: active ? U.lightBlue : const Color(0xFF525252),
      borderRadius: BorderRadius.circular(99),
    ),
  );

  Widget _action(String label, String icon, VoidCallback onTap) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF212124),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF2E2E33),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.string(
                  '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">$icon</svg>',
                  width: 14,
                  height: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: uText(
                size: 12,
                weight: FontWeight.w600,
                color: Colors.white,
                spacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _moneySheet(BuildContext context, {required bool withdraw}) {
    final controller = TextEditingController(text: '100');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: U.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          24 + MediaQuery.of(sheet).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: U.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              withdraw ? 'Withdraw' : 'Deposit',
              style: uText(size: 24, weight: FontWeight.w700, spacing: -0.6),
            ),
            const SizedBox(height: 6),
            Text(
              withdraw
                  ? 'Move money to your linked bank.'
                  : 'Add money from your linked bank.',
              style: uText(size: 13, color: U.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: uText(size: 28, weight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: uText(size: 28, weight: FontWeight.w700),
                filled: true,
                fillColor: U.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: U.dark,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              onPressed: () async {
                final value = double.tryParse(controller.text) ?? 0;
                if (value <= 0) return;
                await WalletStore.instance.apply(
                  amount: withdraw ? -value : value,
                  title: withdraw ? 'Withdrawal' : 'Deposit',
                  subtitle: 'Just now',
                  kind: withdraw ? 'withdraw' : 'deposit',
                );
                if (sheet.mounted) Navigator.pop(sheet);
              },
              child: Text(
                withdraw ? 'Withdraw' : 'Deposit',
                style: uText(
                  size: 15,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.tx, required this.onTap});

  final WalletTx tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDribbble = tx.kind == 'dribbble';
    final isMailchimp = tx.kind == 'mailchimp';
    return _PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDribbble
                    ? const Color(0x26F95C96)
                    : isMailchimp
                    ? const Color(0xFFFFE01B)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: isDribbble
                    ? SvgPicture.string(UArt.dribbble, width: 24, height: 24)
                    : isMailchimp
                    ? SvgPicture.string(UArt.mailchimp, width: 28, height: 28)
                    : Icon(
                        tx.amount >= 0
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: U.blue,
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: uText(
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.1,
                      spacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tx.subtitle,
                    style: uText(
                      size: 11,
                      weight: FontWeight.w500,
                      color: U.grey,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${tx.amount < 0 ? '-' : '+'}₹${tx.amount.abs().toStringAsFixed(2).replaceAll('.', ',')}',
              style: uText(
                size: 14,
                weight: FontWeight.w700,
                spacing: -0.2,
                color: const Color(0xFF171717),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Small avatar in the header. Opens the signed-in account sheet.
class _AccountChip extends StatelessWidget {
  const _AccountChip();

  @override
  Widget build(BuildContext context) {
    final email = BridgyBackend.user?.email;
    if (!BridgyBackend.enabled || email == null) {
      return const SizedBox.shrink();
    }
    return InkResponse(
      key: const Key('account-chip'),
      onTap: () => _accountSheet(context, email),
      radius: 20,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Center(
          child: Text(
            email.substring(0, 1).toUpperCase(),
            style: uiStyle(
              size: 13,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _accountSheet(BuildContext context, String email) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.goldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      email.substring(0, 1).toUpperCase(),
                      style: displayStyle(size: 24, spacing: -0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                email,
                textAlign: TextAlign.center,
                style: uiStyle(size: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  key: const Key('sign-out'),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await BridgyBackend.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Sign out',
                    style: uiStyle(
                      size: 14,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
