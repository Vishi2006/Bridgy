import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';
import 'select_card_screen.dart';
import 'send_money_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 20),
                  _balance(context),
                  const SizedBox(height: 16),
                  _promo(),
                  const SizedBox(height: 16),
                  _sendAgain(),
                  const SizedBox(height: 16),
                  _history(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(child: _nav(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Pesse',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: AppColors.ink,
            height: 1,
          ),
        ),
        const Spacer(),
        _roundButton(
          icon: Icons8.help,
          label: 'Support and FAQ',
          size: 32,
          iconSize: 16,
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: const BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(Icons8.gift, size: 14, color: AppColors.card),
                  SizedBox(width: 6),
                  Text(
                    'Rewards',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.card,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: -6,
              right: -2,
              child: Text(
                '✦',
                style: TextStyle(fontSize: 12, color: AppColors.star),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _balance(BuildContext context) {
    return Column(
      children: [
        InkWell(
          key: const Key('balance-selector'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _open(context, const SelectCardScreen()),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Linda's card balance",
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(width: 6),
                _CardChip(),
                SizedBox(width: 4),
                AppIcon(Icons8.chevronDown, size: 12, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '\$521,098.31',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: AppColors.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: const BoxDecoration(
            color: Color(0xFFE7E1D4),
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: const Text.rich(
            TextSpan(
              text: 'Money hold ',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
              children: [
                TextSpan(
                  text: '\$2,500',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                key: const Key('send-button'),
                icon: Icons8.arrowUpRight,
                label: 'Send',
                onTap: () => _open(context, const SendMoneyScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                key: const Key('receive-button'),
                icon: Icons8.arrowDownLeft,
                label: 'Receive',
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    Key? key,
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 16, strokeWidth: 2.2),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promo() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  child: Text(
                    'Start sending money tax free',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                SizedBox(
                  width: 220,
                  child: Text(
                    'The best place for freelancers to receive and send money. Start saving now!',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(child: _GoldCoin()),
          ),
        ],
      ),
    );
  }

  Widget _sendAgain() {
    const contacts = [
      ('s_rijal', 'S Rijal', AppColors.gold, 'S', 8.0),
      ('ferina_c', 'Ferina C', Color(0xFF0EA5E9), 'P', 8.0),
      ('daffa_t', 'Daffa T', Color(0xFF9333EA), 'S', 8.0),
      ('bayu_s', 'Bayu S', Color(0xFF2563EB), 'BCA', 6.0),
      ('christian_k', 'Christian K', Color(0xFF0284C7), 'P', 8.0),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2EEE4)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Send again',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.pill,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: const Text(
                  '+ Add',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: contacts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final c = contacts[i];
                return SizedBox(
                  width: 48,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/images/avatars/${c.$1}.jpg',
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
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.$3,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.card,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                c.$4,
                                style: TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: c.$5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _history() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2EEE4)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'History transaction',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              const Text(
                'see more',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _tx(
            icon: Icons8.dribbble,
            title: 'Dribbble Pro',
            subtitle: 'June 28 • 00:01 AM',
            amount: '- \$573',
            amountColor: AppColors.negative,
          ),
          const SizedBox(height: 14),
          _tx(
            avatar: 'syaiful_history',
            badgeColor: const Color(0xFFC2554A),
            badgeText: '///',
            title: 'Syaiful Rijal',
            subtitle: 'June 22 • 05:20 PM',
            amount: '+ \$1000',
            amountColor: AppColors.goldText,
          ),
          const SizedBox(height: 14),
          _tx(
            avatar: 'ferina_history',
            badgeColor: const Color(0xFF0EA5E9),
            badgeText: 'P',
            title: 'Ferina C',
            subtitle: 'June 12 • 07:20 AM',
            amount: '- \$200',
            amountColor: AppColors.negative,
          ),
        ],
      ),
    );
  }

  Widget _tx({
    String? icon,
    String? avatar,
    Color? badgeColor,
    String? badgeText,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (avatar != null)
              ClipOval(
                child: Image.asset(
                  'assets/images/avatars/$avatar.jpg',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EEE4),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: AppIcon(
                  icon!,
                  size: 20,
                  color: AppColors.muted,
                  strokeWidth: 1.8,
                ),
              ),
            if (badgeColor != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card, width: 1.5),
                  ),
                  child: Text(
                    badgeText ?? '',
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 6,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  color: AppColors.muted,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ],
    );
  }

  Widget _nav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: AppShadows.nav,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _navItem(Icons8.navHome, active: true, label: 'Home'),
          _navItem(Icons8.navActivity, label: 'Activity'),
          _navItem(
            Icons8.navCards,
            label: 'Cards',
            onTap: () => _open(context, const SelectCardScreen()),
          ),
          _navItem(Icons8.navFinances, label: 'Finances'),
          _navItem(Icons8.navProfile, label: 'Profile'),
        ],
      ),
    );
  }

  Widget _navItem(
    String icon, {
    bool active = false,
    String? label,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkResponse(
        onTap: onTap ?? () {},
        radius: 24,
        child: AppIcon(
          icon,
          size: 20,
          color: active ? AppColors.gold : AppColors.navInactive,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _roundButton({
    required String icon,
    required String label,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1F190F),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: AppIcon(
          icon,
          size: iconSize,
          color: AppColors.ink,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('card-chip'),
      width: 16,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0x1A000000)),
      ),
    );
  }
}

class _GoldCoin extends StatelessWidget {
  const _GoldCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            Color(0xFFF7EBCB),
            Color(0xFFDCC27E),
            Color(0xFFB08D57),
            Color(0xFF6E5628),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x661F190F),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x99FFF6DD)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x66FFF8E4), Color(0x33A9863D)],
          ),
        ),
        child: const Center(
          child: AppIcon(
            Icons8.dollar,
            size: 24,
            color: Color(0xE6FFFBEF),
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
