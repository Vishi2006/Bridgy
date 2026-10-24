import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen>
    with SingleTickerProviderStateMixin {
  String _digits = '19';
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  void _append(String value) {
    setState(() {
      if (_digits.length < 12) _digits += value;
    });
  }

  void _backspace() {
    setState(() {
      if (_digits.isNotEmpty) {
        _digits = _digits.substring(0, _digits.length - 1);
      }
    });
  }

  String get _amount {
    if (_digits.isEmpty) return '\$0';
    return '\$${int.parse(_digits).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgAlt,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  children: [
                    _header(context),
                    const SizedBox(height: 16),
                    _recipient(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _amount,
                                key: const Key('amount-text'),
                                style: const TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontSize: 60,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -2,
                                  color: AppColors.ink,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              FadeTransition(
                                opacity: _blink,
                                child: Container(
                                  width: 3.5,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _funding(),
                    const Spacer(),
                    _keypad(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Material(
                        color: const Color(0xFF0D0C0B),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {},
                          child: const Center(
                            child: Text(
                              'Send money',
                              style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        _circleButton(
          icon: Icons8.back,
          label: 'Go back',
          onTap: () => Navigator.of(context).pop(),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Send money',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        _circleButton(icon: Icons8.helpAlt, label: 'Help and Info'),
      ],
    );
  }

  Widget _circleButton({
    required String icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: AppColors.card,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap ?? () {},
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: AppIcon(
                icon,
                size: 20,
                color: AppColors.ink,
                strokeWidth: 2.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recipient() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send to',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/avatars/syaiful_send.jpg',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Color(0x1F1F190F), blurRadius: 2),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [Color(0xFFC2554A), Color(0xFF4A4A9E)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Syaiful Rijal',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '8921362190',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _changePill(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _changePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.pill,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: const Text(
        'Change',
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _funding() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 28,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F1F190F),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'LINDA',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                            height: 1,
                          ),
                        ),
                      ),
                      Text(
                        'VISA',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontStyle: FontStyle.italic,
                          fontSize: 6,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  bottom: 0,
                  left: 0,
                  child: Text(
                    '•••• 2451',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 0.3,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Linda's card",
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.3,
                ),
              ),
              Text.rich(
                TextSpan(
                  text: 'Balance ',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                  children: [
                    TextSpan(
                      text: '\$521,098.31',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          _changePill(),
        ],
      ),
    );
  }

  Widget _keypad() {
    return Column(
      children: [
        _keyRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _keyRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _keyRow(['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _key(
                '000',
                fontSize: 14,
                background: const Color(0xB3FFFFFF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _key('0')),
            const SizedBox(width: 8),
            Expanded(
              child: _key(
                '',
                child: const AppIcon(Icons8.backspace, size: 20, filled: true),
                background: const Color(0xB3FFFFFF),
                onTap: _backspace,
                key: const Key('key-backspace'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyRow(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _key(
              keys[i],
              highlighted: keys[i] == '9',
              onTap: () => _append(keys[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _key(
    String label, {
    Key? key,
    Widget? child,
    bool highlighted = false,
    Color? background,
    double fontSize = 18,
    VoidCallback? onTap,
  }) {
    return Material(
      key: key,
      color: highlighted ? AppColors.gold : (background ?? AppColors.card),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => _append(label),
        child: SizedBox(
          height: 48,
          child: Center(
            child:
                child ??
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: fontSize,
                    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
