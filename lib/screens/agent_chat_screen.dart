import 'dart:async';

import 'package:flutter/material.dart';

import '../icons.dart';
import '../models/agent_action.dart';
import '../services/ai_service.dart';
import '../services/app_launcher_service.dart';
import '../services/screen_automation_service.dart';
import '../services/shizuku_service.dart';
import '../services/task_executor.dart';
import '../theme.dart';
import 'agent_screen.dart';

/// Chat page for the on-device agent.
///
/// Chat mode talks to the model. Agent mode lets the model pick one JSON action
/// and runs it through the accessibility service, so no Termux or laptop is
/// needed. The Termux/ADB screen stays reachable from the header.
class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
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
    _init();
  }

  Future<void> _init() async {
    await _ai.init();
    final running = await _screen.isServiceRunning();
    if (!mounted) return;
    setState(() => _accessibilityOn = running);
    if (!_ai.isConfigured) {
      _appendSystem('Add your API key to start, or connect to the Backend.');
    } else if (_ai.isBackendProxy && _ai.apiKey.isEmpty) {
      _appendSystem('Connected to Bridgy Backend with server-side AI key. Ready to assist!');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _ai.dispose();
    super.dispose();
  }

  void _appendSystem(String text) {
    if (!mounted) return;
    setState(() => _messages.add(_Msg(text, isUser: false)));
    _scrollToEnd(animate: false);
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    if (!_ai.isConfigured) {
      _appendSystem('No API key yet. Tap the gear to add one.');
      return;
    }
    _input.clear();
    setState(() {
      _busy = true;
      _messages.add(_Msg(text, isUser: true));
    });
    _scrollToEnd(animate: false);

    try {
      if (_mode == 'chat') {
        await _streamChat(text);
      } else {
        await _runAgent(text);
      }
    } catch (e) {
      _appendSystem('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _streamChat(String text) async {
    final index = _messages.length;
    setState(() => _messages.add(const _Msg('', isUser: false)));
    final buffer = StringBuffer();
    var lastPaint = DateTime.now();

    final stream = _ai
        .sendMessageStream(text, isAgentMode: false)
        .timeout(const Duration(seconds: 90));

    await for (final chunk in stream) {
      buffer.write(chunk);
      final now = DateTime.now();
      if (now.difference(lastPaint).inMilliseconds < 70) continue;
      lastPaint = now;
      if (!mounted) return;
      setState(() => _messages[index] = _Msg(buffer.toString(), isUser: false));
      _scrollToEnd(animate: false);
    }

    if (!mounted) return;
    setState(() => _messages[index] = _Msg(buffer.toString(), isUser: false));
    _scrollToEnd();
  }

  Future<void> _runAgent(String text) async {
    final reply = await _ai.sendMessage(text, isAgentMode: true);
    final action = _ai.parseAction(reply);

    if (action == null) {
      _appendSystem(reply);
      return;
    }

    if (action.action != 'execute_task') {
      final detail = await _runSimpleAction(action);
      _appendSystem(detail);
      return;
    }

    if (!_accessibilityOn) {
      _accessibilityOn = await _screen.isServiceRunning();
      if (!_accessibilityOn) {
        _appendSystem(
          'Enable "Bridgy Screen Control" in Accessibility settings first.',
        );
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
        if (mounted) setState(() => _messages.add(_Msg('· $message', isUser: false)));
        _scrollToEnd(animate: false);
      },
    );

    final result = await executor.executeTask(
      goal == null || goal.isEmpty ? text : goal,
    );
    _appendSystem(result);
  }

  Future<String> _runSimpleAction(AgentAction action) async {
    switch (action.action) {
      case 'open_app':
        return _apps.openApp(action.params['app_name'] as String? ?? '');
      case 'read_screen':
        return _screen.getCompressedScreenDescription(
          action.response.isEmpty ? 'read the screen' : action.response,
        );
      case 'press_back':
        await _screen.pressBack();
        return 'Pressed back.';
      default:
        return action.response.isEmpty
            ? 'No action for ${action.action}.'
            : action.response;
    }
  }

  Future<void> _openSettings() async {
    final baseUrl = TextEditingController(text: _ai.baseUrl);
    final model = TextEditingController(text: _ai.model);
    final key = TextEditingController(text: _ai.apiKey);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('AI settings', style: displayStyle(size: 20, spacing: -0.4)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(baseUrl, 'Base URL', 'https://api.deepseek.com'),
              const SizedBox(height: 12),
              _dialogField(model, 'Model', 'deepseek-chat'),
              const SizedBox(height: 12),
              _dialogField(key, 'API key', 'sk-...', obscure: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: uiStyle(size: 13)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dark),
            onPressed: () async {
              await _ai.saveSettings(
                apiKey: key.text.trim(),
                baseUrl: baseUrl.text.trim(),
                model: model.text.trim(),
              );
              await _ai.saveAdvancedSettings(
                temperature: _ai.temperature,
                maxTokens: _ai.maxTokens,
                useScreenCompression: _ai.useScreenCompression,
                useSystemPrompt: _ai.useSystemPrompt,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) setState(() {});
            },
            child: Text('Save', style: uiStyle(size: 13, color: AppColors.card)),
          ),
        ],
      ),
    );

    baseUrl.dispose();
    model.dispose();
    key.dispose();
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: uiStyle(size: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: uiStyle(size: 12, color: AppColors.muted),
        hintStyle: uiStyle(size: 12, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.bgAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }

  Future<void> _openAccessibility() async {
    await _screen.openAccessibilitySettings();
    final running = await _screen.isServiceRunning();
    if (mounted) setState(() => _accessibilityOn = running);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 14),
              _modeRow(),
              if (!_accessibilityOn) _accessibilityBanner(),
              const SizedBox(height: 12),
              Expanded(child: _messageList()),
              const SizedBox(height: 10),
              _composer(),
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
            Text('Agent', style: displayStyle(size: 22, spacing: -0.6)),
            Text(
              _mode == 'chat' ? 'chat · on-device' : 'agent · screen control',
              style: uiStyle(size: 11, color: AppColors.muted),
            ),
          ],
        ),
        const Spacer(),
        _pill(
          label: 'Termux',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AgentScreen()),
          ),
        ),
        const SizedBox(width: 8),
        InkResponse(
          onTap: _openSettings,
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
              child: AppIcon(Icons8.navProfile, size: 16, color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill({required String label, required VoidCallback onTap}) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: uiStyle(size: 11, weight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _modeRow() {
    return Row(
      children: [
        _modeButton('chat', 'Chat'),
        const SizedBox(width: 8),
        _modeButton('agent', 'Agent'),
      ],
    );
  }

  Widget _modeButton(String id, String label) {
    final active = _mode == id;
    return InkResponse(
      onTap: _busy ? null : () => setState(() => _mode = id),
      radius: 24,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.dark : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.dark : AppColors.border),
        ),
        child: Text(
          label,
          style: uiStyle(
            size: 12,
            weight: FontWeight.w700,
            color: active ? AppColors.card : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _accessibilityBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkResponse(
        onTap: _openAccessibility,
        radius: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.goldSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Screen control is off. Tap to open Accessibility settings.',
            style: uiStyle(size: 11, weight: FontWeight.w600, color: AppColors.goldText),
          ),
        ),
      ),
    );
  }

  Widget _messageList() {
    if (_messages.isEmpty) {
      return Container(
        alignment: Alignment.center,
        child: Text(
          'Ask for anything. In Agent mode I can tap, type and scroll\nacross installed apps.',
          textAlign: TextAlign.center,
          style: uiStyle(size: 12, color: AppColors.muted, height: 1.6),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: _messages.length,
      itemBuilder: (context, index) => _bubble(_messages[index]),
    );
  }

  Widget _bubble(_Msg message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.dark : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          message.text.isEmpty ? '…' : message.text,
          style: uiStyle(
            size: 13,
            height: 1.45,
            color: isUser ? AppColors.card : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: uiStyle(size: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Ask Bridgy…',
                hintStyle: uiStyle(size: 13, color: AppColors.muted),
              ),
            ),
          ),
          InkResponse(
            onTap: _busy ? null : _send,
            radius: 22,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.dark,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.card),
                        ),
                      )
                    : const AppIcon(Icons8.arrowUpRight, size: 16, color: AppColors.card),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  const _Msg(this.text, {required this.isUser});

  final String text;
  final bool isUser;
}
