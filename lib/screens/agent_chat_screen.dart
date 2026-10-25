import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_service.dart';
import '../services/app_launcher_service.dart';
import '../services/screen_automation_service.dart';
import '../services/shizuku_service.dart';
import '../services/task_executor.dart';
import '../unipay.dart';

class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key, this.initialGoal});

  final String? initialGoal;

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen>
    with WidgetsBindingObserver {
  final _ai = AiService();
  final _screen = ScreenAutomationService();
  final _apps = AppLauncherService();
  final _shizuku = ShizukuService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];

  String _mode = 'agent';
  bool _busy = false;
  bool _accessibilityOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final goal = widget.initialGoal?.trim();
    if (goal != null && goal.isNotEmpty) _input.text = goal;
    _init();
  }

  Future<void> _init() async {
    await _ai.init();
    final running = await _screen.isServiceRunning();
    if (!mounted) return;
    setState(() => _accessibilityOn = running);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccessibility();
  }

  Future<void> _refreshAccessibility() async {
    final running = await _screen.isServiceRunning();
    if (mounted && running != _accessibilityOn) {
      setState(() => _accessibilityOn = running);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    _ai.dispose();
    super.dispose();
  }

  void _system(String text) {
    if (!mounted) return;
    setState(() => _messages.add(_Msg(text, user: false)));
    _scrollEnd();
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _busy = true;
      _messages.add(_Msg(text, user: true));
    });
    _scrollEnd();
    try {
      if (_mode == 'chat') {
        await _chat(text);
      } else {
        await _agent(text);
      }
    } catch (e) {
      _system(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollEnd();
    }
  }

  Future<void> _chat(String text) async {
    final index = _messages.length;
    setState(() => _messages.add(const _Msg('', user: false)));
    final buffer = StringBuffer();
    var last = DateTime.now();
    await for (final chunk in _ai
        .sendMessageStream(text, isAgentMode: false)
        .timeout(const Duration(seconds: 120))) {
      buffer.write(chunk);
      final now = DateTime.now();
      if (now.difference(last).inMilliseconds < 60) continue;
      last = now;
      if (!mounted) return;
      setState(() => _messages[index] = _Msg(buffer.toString(), user: false));
      _scrollEnd();
    }
    if (!mounted) return;
    setState(() => _messages[index] = _Msg(buffer.toString(), user: false));
  }

  Future<void> _agent(String text) async {
    final reply = await _ai.sendMessage(text, isAgentMode: true);
    final action = _ai.parseAction(reply);
    if (action == null) {
      _system(reply);
      return;
    }
    if (action.action == 'open_app') {
      _system(await _apps.openApp(action.params['app_name'] as String? ?? ''));
      return;
    }
    if (action.action == 'read_screen') {
      _system(
        await _screen.getCompressedScreenDescription(
          action.response.isEmpty ? 'read the screen' : action.response,
        ),
      );
      return;
    }
    if (action.action == 'press_back') {
      await _screen.pressBack();
      _system('Pressed back.');
      return;
    }
    if (!_accessibilityOn) {
      _accessibilityOn = await _screen.isServiceRunning();
      if (!_accessibilityOn) {
        _system('Enable Screen Control to let the agent tap and type.');
        return;
      }
    }
    final goal = (action.params['goal'] as String?)?.trim();
    final executor = TaskExecutor(
      aiService: _ai,
      screenService: _screen,
      appLauncher: _apps,
      shizukuService: _shizuku,
      onProgress: (message) {
        if (mounted) {
          setState(() => _messages.add(_Msg('· $message', user: false)));
        }
        _scrollEnd();
      },
    );
    _system(await executor.executeTask(goal == null || goal.isEmpty ? text : goal));
  }

  Future<void> _connectSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: U.cardDark,
      isScrollControlled: true,
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
            const SizedBox(height: 20),
            Text(
              'Agent connection',
              style: uText(
                size: 22,
                weight: FontWeight.w700,
                color: Colors.white,
                spacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The agent drives this phone through the on-device accessibility '
              'service. Wireless ADB pairing is available when Developer '
              'options and Wireless debugging are enabled.',
              style: uText(size: 12, color: U.grey, height: 1.5),
            ),
            const SizedBox(height: 18),
            _statusRow(
              'Screen control',
              _accessibilityOn ? 'Ready' : 'Off',
              _accessibilityOn,
            ),
            const SizedBox(height: 10),
            _statusRow('ADB transport', 'Optional', false),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: U.lightBlue,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              onPressed: () async {
                await _screen.openAccessibilitySettings();
                final on = await _screen.isServiceRunning();
                if (mounted) setState(() => _accessibilityOn = on);
                if (sheet.mounted) Navigator.pop(sheet);
              },
              child: Text(
                _accessibilityOn ? 'Open settings' : 'Enable screen control',
                style: uText(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(sheet);
                _system(
                  'ADB setup: enable Developer options → Wireless debugging, '
                  'pair the device, then keep it connected while the agent runs.',
                );
              },
              child: Text(
                'How ADB pairing works',
                style: uText(size: 12, color: U.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value, bool ready) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: ready ? const Color(0xFF34D399) : U.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: uText(
                size: 13,
                weight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          Text(value, style: uText(size: 12, color: U.grey)),
        ],
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
      ),
      child: ColoredBox(
        color: U.appDark,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              _modes(),
              if (!_accessibilityOn) _banner(),
              Expanded(child: _list()),
              _composer(),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: U.lightBlue,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x402563EB),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Agent',
                style: uText(
                  size: 21,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  spacing: -0.5,
                ),
              ),
              Text(
                _accessibilityOn ? 'Screen control ready' : 'Connect to control apps',
                style: uText(size: 11, color: U.grey),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            key: const Key('agent-connect'),
            onTap: _connectSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _accessibilityOn
                          ? const Color(0xFF34D399)
                          : U.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Status',
                    style: uText(
                      size: 11,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _modePill('chat', 'Chat'),
          const SizedBox(width: 8),
          _modePill('agent', 'Agent'),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _modePill(String id, String label) {
    final active = _mode == id;
    return GestureDetector(
      onTap: _busy ? null : () => setState(() => _mode = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? U.yellow : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: uText(
            size: 12,
            weight: FontWeight.w700,
            color: active ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _banner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: GestureDetector(
        onTap: _connectSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: U.yellow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: U.yellow.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: U.yellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Screen control is off. Tap to enable.',
                  style: uText(
                    size: 11,
                    weight: FontWeight.w600,
                    color: U.yellow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list() {
    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        children: [
          Text(
            'What should we do?',
            style: uText(
              size: 30,
              weight: FontWeight.w700,
              color: Colors.white,
              spacing: -1,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chat for answers, or switch to Agent to let me drive this phone.',
            style: uText(size: 12, color: U.grey, height: 1.5),
          ),
          const SizedBox(height: 22),
          for (final prompt in const [
            'Open YouTube and search for lo-fi music',
            'Summarise my spending this month',
            'Send \$25 to Donate for Ukraine',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  _input.text = prompt;
                  _send();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: U.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          prompt,
                          style: uText(
                            size: 12,
                            weight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: U.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      itemCount: _messages.length + (_busy && _mode == 'chat' ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) return const _Typing();
        return _bubble(_messages[index]);
      },
    );
  }

  Widget _bubble(_Msg message) {
    final user = message.user;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - value)),
          child: child,
        ),
      ),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: user ? U.lightBlue : U.cardDark,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(user ? 16 : 4),
              bottomRight: Radius.circular(user ? 4 : 16),
            ),
          ),
          child: Text(
            message.text.isEmpty ? '…' : message.text,
            style: uText(
              size: 13,
              height: 1.45,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 5, 4),
        decoration: BoxDecoration(
          color: U.cardDark,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: !_busy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: uText(size: 13, color: Colors.white),
                cursorColor: U.lightBlue,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _mode == 'chat' ? 'Ask anything…' : 'Tell me a task…',
                  hintStyle: uText(size: 13, color: U.grey),
                ),
              ),
            ),
            GestureDetector(
              key: const Key('agent-send'),
              onTap: _busy ? null : _send,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: U.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        size: 20,
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

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: U.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = ((_c.value + i * 0.2) % 1);
              final bounce = t < 0.5 ? t * 2 : (1 - t) * 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                transform: Matrix4.translationValues(0, -3 * bounce, 0),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: U.grey,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Msg {
  const _Msg(this.text, {required this.user});

  final String text;
  final bool user;
}
