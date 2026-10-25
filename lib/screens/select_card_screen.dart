import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';

class SelectCardScreen extends StatefulWidget {
  const SelectCardScreen({super.key});

  @override
  State<SelectCardScreen> createState() => _SelectCardScreenState();
}

class _SelectCardScreenState extends State<SelectCardScreen> {
  String _selected = '2451';

  void _select(String last4) => setState(() => _selected = last4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgAlt,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 16, 28, 12),
              child: Text(
                'Select Card',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.ink,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  _CardTile(
                    key: const Key('card-lime'),
                    background: AppColors.gold,
                    nameColor: AppColors.ink,
                    amountColor: AppColors.ink,
                    visaColor: AppColors.ink,
                    numberColor: AppColors.ink,
                    watermarkColor: const Color(0x737A5E28),
                    watermarkShadows: const [
                      Shadow(
                        color: Color(0x4DFFFFFF),
                        offset: Offset(1, 1),
                        blurRadius: 1,
                      ),
                      Shadow(
                        color: Color(0x665A4A22),
                        offset: Offset(-1, -1),
                        blurRadius: 2,
                      ),
                    ],
                    amount: '\$112,411',
                    last4: '2451',
                    selected: _selected == '2451',
                    onTap: () => _select('2451'),
                  ),
                  const SizedBox(height: 16),
                  _CardTile(
                    key: const Key('card-black'),
                    background: const Color(0xFF18181B),
                    nameColor: const Color(0xFFD4D4D4),
                    amountColor: Colors.white,
                    visaColor: Colors.white,
                    numberColor: const Color(0xFFA3A3A3),
                    watermarkColor: const Color(0xFF1B1917),
                    watermarkShadows: const [
                      Shadow(
                        color: Color(0x12FFFFFF),
                        offset: Offset(0, 1),
                        blurRadius: 1,
                      ),
                      Shadow(
                        color: Color(0xB3000000),
                        offset: Offset(0, -1),
                        blurRadius: 1,
                      ),
                    ],
                    amount: '\$112,411',
                    last4: '0095',
                    selected: _selected == '0095',
                    onTap: () => _select('0095'),
                  ),
                  const SizedBox(height: 16),
                  _CardTile(
                    key: const Key('card-white'),
                    background: AppColors.card,
                    nameColor: const Color(0xFF5A554C),
                    amountColor: AppColors.ink,
                    visaColor: AppColors.ink,
                    numberColor: const Color(0xFF3A352C),
                    watermarkColor: const Color(0xFFFAF6EC),
                    watermarkShadows: const [
                      Shadow(
                        color: Color(0xE6FFFFFF),
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                      Shadow(
                        color: Color(0x121F190F),
                        offset: Offset(-1, -1),
                        blurRadius: 2,
                      ),
                    ],
                    amount: '\$12,000',
                    last4: '1122',
                    selected: _selected == '1122',
                    onTap: () => _select('1122'),
                    bordered: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.background,
    required this.nameColor,
    required this.amountColor,
    required this.visaColor,
    required this.numberColor,
    required this.watermarkColor,
    required this.watermarkShadows,
    required this.amount,
    required this.last4,
    required this.selected,
    required this.onTap,
    this.bordered = false,
  });

  final Color background;
  final Color nameColor;
  final Color amountColor;
  final Color visaColor;
  final Color numberColor;
  final Color watermarkColor;
  final List<Shadow> watermarkShadows;
  final String amount;
  final String last4;
  final bool selected;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Card ending $last4',
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 184,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            border: bordered
                ? Border.all(color: const Color(0xFFF2EEE4))
                : null,
            boxShadow: AppShadows.cardSoft,
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned(
                left: -6,
                bottom: -30,
                child: Text(
                  'Bridgy',
                  style: TextStyle(
                    fontFamily: AppFonts.script,
                    fontStyle: FontStyle.italic,
                    fontSize: 126,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -4,
                    height: 0.9,
                    color: watermarkColor,
                    shadows: watermarkShadows,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Linda Srikandi',
                                style: TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: nameColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                amount,
                                style: TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.8,
                                  color: amountColor,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Transform(
                            transform: Matrix4.skewX(-0.16),
                            alignment: Alignment.center,
                            child: Text(
                              'VISA',
                              style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontStyle: FontStyle.italic,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                                color: visaColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '••••',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: numberColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          last4,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.4,
                            color: numberColor,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D0C0B),
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _CheckDot(),
                                SizedBox(width: 6),
                                Text(
                                  'Main card',
                                  style: TextStyle(
                                    fontFamily: AppFonts.ui,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  const _CheckDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: AppColors.gold,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: AppIcon(
          Icons8.check,
          size: 10,
          color: Color(0xFF0D0C0B),
          strokeWidth: 3,
        ),
      ),
    );
  }
}
