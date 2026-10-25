import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/wallet_service.dart';
import '../state/wallet_store.dart';
import '../unipay.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key, this.donate = true, required this.onSent});

  final bool donate;
  final VoidCallback onSent;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  String _entry = '';
  bool _enabled = true;
  String _account = '•••• 1234';

  bool get _hasValue => (double.tryParse(_entry) ?? 0) > 0;

  String get _display => _entry.isEmpty ? '00.00' : _entry;

  void _pressKey(String value) {
    HapticFeedback.selectionClick();
    if (value == '.') {
      if (_entry.contains('.')) return;
      setState(() => _entry = _entry.isEmpty ? '0.' : '$_entry.');
      return;
    }
    final dot = _entry.indexOf('.');
    if (dot >= 0 && _entry.length - dot > 2) return;
    final whole = dot >= 0 ? _entry.substring(0, dot) : _entry;
    if (dot < 0 && whole.length >= 9) return;
    setState(() {
      if (_entry == '0') {
        _entry = value;
      } else {
        _entry += value;
      }
    });
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _send() async {
    if (!_enabled) {
      _toast('Turn on the recipient to continue.');
      return;
    }
    if (!_hasValue) {
      _toast('Enter an amount first.');
      return;
    }
    final amount = double.parse(_entry);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: U.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Confirm transfer',
              style: uText(
                size: 22,
                weight: FontWeight.w700,
                color: Colors.white,
                spacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(2)} to Donate for Ukraine',
              style: uText(size: 13, color: U.grey),
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: U.lightBlue,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              onPressed: () => Navigator.pop(sheet, true),
              child: Text(
                'Confirm',
                style: uText(
                  size: 15,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet, false),
              child: Text('Cancel', style: uText(size: 13, color: U.grey)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await WalletService.payWithOwner(
        amountInr: amount,
        merchantName: 'Donate for Ukraine',
        merchantVpa: 'donate@bridgy',
      );
      await WalletStore.instance.refresh();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SuccessDialog(),
      );
      if (!mounted) return;
      widget.onSent();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: U.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Payment failed',
            style: uText(size: 18, weight: FontWeight.w700),
          ),
          content: Text(
            error.toString(),
            key: const Key('send-error'),
            style: uText(size: 13, color: U.grey, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: uText(size: 13, color: Colors.white)),
          backgroundColor: U.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: U.appDark,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _topBar(context),
              const SizedBox(height: 16),
              _recipient(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Amount',
                        style: uText(
                          size: 12,
                          weight: FontWeight.w400,
                          color: U.grey,
                          spacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹',
                              style: uText(
                                size: 30,
                                weight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _display,
                              key: const Key('amount-text'),
                              style: uText(
                                size: 44,
                                weight: FontWeight.w700,
                                color: _entry.isEmpty
                                    ? U.digitMuted
                                    : Colors.white,
                                spacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _pickAccount,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: U.accentYellow,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            _account,
                            style: uText(
                              size: 10,
                              weight: FontWeight.w800,
                              color: Colors.black,
                              spacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _keypad(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                key: const Key('send-back'),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            Text(
              'Send Money',
              style: uText(
                size: 15,
                weight: FontWeight.w600,
                color: Colors.white,
                spacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipient() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: U.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF2A171D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x4DFF4D4D)),
              ),
              child: SvgPicture.string(UArt.ukraine),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Donate for Ukraine',
                    style: uText(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.1,
                      spacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Charitable Foundation',
                    style: uText(
                      size: 11,
                      weight: FontWeight.w400,
                      color: U.grey,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.86,
              child: SwitchTheme(
                data: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : Colors.white,
                  ),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? U.lightBlue
                        : const Color(0xFF121214),
                  ),
                  trackOutlineColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.transparent
                        : Colors.white12,
                  ),
                ),
                child: Switch(
                  key: const Key('recipient-toggle'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keypad() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['.', '0', '<'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: _key(
                          key,
                          onTap: key == '<' ? _backspace : () => _pressKey(key),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            GestureDetector(
              key: const Key('send-confirm-button'),
              onTap: _send,
              child: AnimatedOpacity(
                opacity: _enabled ? 1 : 0.45,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: U.lightBlue,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x402563EB),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Send',
                      style: uText(
                        size: 16,
                        weight: FontWeight.w500,
                        color: Colors.white,
                      ),
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

  Widget _key(String value, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 50,
        child: Center(
          child: value == '<'
              ? const Icon(
                  Icons.keyboard_arrow_left_rounded,
                  size: 26,
                  color: Colors.black,
                )
              : Text(
                  value,
                  style: uText(
                    size: value == '.' ? 26 : 24,
                    weight: FontWeight.w600,
                    color: Colors.black,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }

  void _pickAccount() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: U.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Source account',
              style: uText(
                size: 18,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            for (final account in const ['•••• 1234', '•••• 8890'])
              ListTile(
                onTap: () {
                  setState(() => _account = account);
                  Navigator.pop(sheet);
                },
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: U.accentYellow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
                title: Text(
                  account,
                  style: uText(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                trailing: _account == account
                    ? const Icon(Icons.check_rounded, color: U.accentYellow)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog();

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: U.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: U.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sent',
              style: uText(
                size: 22,
                weight: FontWeight.w700,
                color: Colors.white,
                spacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your transfer is on its way.',
              style: uText(size: 12, color: U.grey),
            ),
          ],
        ),
      ),
    );
  }
}
