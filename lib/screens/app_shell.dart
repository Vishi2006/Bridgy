import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../unipay.dart';
import 'agent_chat_screen.dart';
import 'home_screen.dart';
import 'send_money_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  final _tab = ValueNotifier<int>(0);
  String? _goal;
  int _goalTick = 0;
  bool _fabDown = false;

  void openAgent(String goal) {
    setState(() {
      _goal = goal.trim();
      _goalTick++;
    });
    _tab.value = 1;
  }

  void _openSend() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => SendMoneyScreen(onSent: () {}),
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

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.appDark,
      body: ValueListenableBuilder<int>(
        valueListenable: _tab,
        builder: (context, index, _) => Stack(
          children: [
            _layer(
              active: index == 0,
              child: HomeScreen(onOpenSend: _openSend),
            ),
            _layer(
              active: index == 1,
              child: AgentChatScreen(
                key: ValueKey<int>(_goalTick),
                initialGoal: _goal,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _footer(),
    );
  }

  Widget _layer({required bool active, required Widget child}) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  const SizedBox(width: 20),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _navIcon(
                        key: const Key('nav-home'),
                        label: 'Home',
                        paths: UArt.home,
                        active: true,
                        onTap: () => _tab.value = 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _navIcon(
                        key: const Key('nav-agent'),
                        label: 'Agent',
                        paths: UArt.agent,
                        active: false,
                        onTap: () => _tab.value = 1,
                        stroke: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
              Positioned(
                top: -22,
                child: GestureDetector(
                  key: const Key('nav-plus'),
                  onTapDown: (_) => setState(() => _fabDown = true),
                  onTapCancel: () => setState(() => _fabDown = false),
                  onTapUp: (_) => setState(() => _fabDown = false),
                  onTap: _openSend,
                  child: AnimatedScale(
                    scale: _fabDown ? 0.9 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: U.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: U.lightBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x732563EB),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SvgPicture.string(
                          '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">${UArt.plus}</svg>',
                          width: 24,
                          height: 24,
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
    );
  }

  Widget _navIcon({
    Key? key,
    required String label,
    required String paths,
    required bool active,
    required VoidCallback onTap,
    bool stroke = false,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: SvgPicture.string(
              '<svg viewBox="0 0 24 24" fill="${stroke ? 'none' : 'currentColor'}" stroke="${stroke ? 'currentColor' : 'none'}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">$paths</svg>',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                active ? const Color(0xFF0A0A0A) : const Color(0xFF0A0A0A),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
