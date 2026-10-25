import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;

import '../icons.dart';
import '../services/adb_bridge.dart';
import '../services/macro.dart';
import '../theme.dart';

/// Runs the agent loop: dump screen, ask the backend for the next ADB command,
/// execute it. "Fast mode" skips the network and replays a calibrated macro.
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  static const _agentUrl = String.fromEnvironment(
    'BRIDGY_AGENT_URL',
    defaultValue: 'http://10.0.2.2:8787',
  );
  static const _maxSteps = 12;

  /// One keep-alive client for the backend calls, so each step reuses the
  /// connection instead of paying a TCP/TLS setup per request.
  final _http = http.Client();
  final _bridge = AdbBridge();
  final _goal = TextEditingController(
    text: 'Open Rapido and book a cab to Manipal',
  );
  final _log = <_LogLine>[];

  bool _fastMode = true;
  bool _running = false;
  bool _hudOn = false;
  bool _termuxMissing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final installed = await _bridge.isTermuxInstalled();
    final launchText = await _bridge.takeLaunchText();
    if (!mounted) return;
    setState(() {
      _termuxMissing = !installed;
      if (launchText != null && launchText.trim().isNotEmpty) {
        _goal.text = launchText.trim();
      }
    });
    if (!installed) {
      _append(
        'Termux not found. Install Termux + android-tools, then pair '
        'wireless ADB.',
      );
    }
  }

  @override
  void dispose() {
    _goal.dispose();
    _http.close();
    super.dispose();
  }

  void _append(String text) {
    if (!mounted) return;
    setState(() {
      _log.add(_LogLine(text));
      if (_log.length > 120) _log.removeAt(0);
    });
    if (_hudOn) {
      FlutterOverlayWindow.shareData({'line': text});
    }
  }

  Future<void> _toggleHud() async {
    try {
      if (_hudOn) {
        await FlutterOverlayWindow.closeOverlay();
        setState(() => _hudOn = false);
        return;
      }
      var granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        granted = await FlutterOverlayWindow.requestPermission() ?? false;
      }
      if (!granted) {
        _append('Overlay permission denied');
        return;
      }
      await FlutterOverlayWindow.showOverlay(
        height: 210,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        enableDrag: true,
        overlayTitle: 'Bridgy is running',
        overlayContent: 'Live ADB commands',
      );
      setState(() => _hudOn = true);
    } on Exception catch (e) {
      _append('Overlay error: $e');
    }
  }

  Future<void> _start() async {
    if (_running) {
      setState(() => _running = false);
      _append('stop requested');
      return;
    }
    final goal = _goal.text.trim();
    if (goal.isEmpty) return;
    setState(() => _running = true);
    _append('goal: $goal');
    try {
      if (_fastMode) {
        await _runMacro(goal);
      } else {
        await _runAgent(goal);
      }
    } on AdbException catch (e) {
      _append('adb error: ${e.message}');
    } finally {
      if (mounted) setState(() => _running = false);
      _append('done');
    }
  }

  Future<void> _runMacro(String goal) async {
    final macro = Macro.forGoal(goal);
    _append('fast mode: ${macro.label} macro');
    for (final step in macro.steps(goal)) {
      if (!_running) break;
      _append(step.raw ? step.command : 'adb shell ${step.command}');
      await _bridge.run(step.command, raw: step.raw);
      await Future<void>.delayed(Duration(milliseconds: step.waitMs));
    }
  }

  Future<void> _runAgent(String goal) async {
    String? lastXml;
    for (var step = 1; step <= _maxSteps && _running; step++) {
      _append('--- step $step ---');
      await _bridge.run('uiautomator dump /sdcard/window_dump.xml');
      final xml = await _waitForScreenDump(lastXml);
      if (!_running) return;
      if (xml == null || xml.isEmpty) {
        _append('dump missing: grant "All files access", or use fast mode');
        return;
      }
      lastXml = xml;
      final next = await _nextCommand(goal, xml);
      if (next == null) return;
      _append(next.thought.isEmpty ? next.command : next.thought);
      _append('adb shell ${next.command}');
      await _bridge.run(next.command);
      // Let the tap land. The next dump read waits for the screen itself.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// `uiautomator dump` is fired into Termux and returns immediately, so the
  /// file has to be watched. Waits until the dump differs from [previous] and
  /// then stays unchanged for one poll, instead of always sleeping 1.2s.
  Future<String?> _waitForScreenDump(
    String? previous, {
    Duration timeout = const Duration(milliseconds: 1800),
    Duration poll = const Duration(milliseconds: 150),
  }) async {
    var baseline = previous ?? await _bridge.readScreenDump();
    var candidate = baseline;
    final stopwatch = Stopwatch()..start();

    while (_running && stopwatch.elapsed < timeout) {
      await Future<void>.delayed(poll);
      final current = await _bridge.readScreenDump();
      if (current == null || current.isEmpty) continue;
      if (current != candidate) {
        candidate = current;
        continue;
      }
      if (candidate != baseline) return candidate;
    }
    return candidate ?? baseline;
  }

  Future<_AgentCommand?> _nextCommand(String goal, String xml) async {
    try {
      final res = await _http
          .post(
            Uri.parse('$_agentUrl/api/agent/next-adb'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'userGoal': goal, 'screenXml': xml}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        _append('agent ${res.statusCode}: ${res.body}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final command = body['command'] as String?;
      if (command == null || command.isEmpty) {
        _append('agent returned no command');
        return null;
      }
      return _AgentCommand(
        command: command,
        thought: (body['thought'] as String?) ?? '',
      );
    } on Exception catch (e) {
      _append('agent unreachable: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 18),
              _goalField(),
              const SizedBox(height: 12),
              _controls(),
              if (_termuxMissing) _warning(),
              const SizedBox(height: 14),
              Expanded(child: _terminal()),
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
            Text('Termux', style: displayStyle(size: 22, spacing: -0.6)),
            Text(
              _fastMode
                  ? 'fast mode · calibrated taps'
                  : 'live · deepseek loop',
              style: uiStyle(size: 11, color: AppColors.muted),
            ),
          ],
        ),
        const Spacer(),
        _pill(
          label: _hudOn ? 'HUD on' : 'HUD',
          active: _hudOn,
          onTap: _toggleHud,
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.dark : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.dark : AppColors.border),
        ),
        child: Text(
          label,
          style: uiStyle(
            size: 12,
            weight: FontWeight.w600,
            color: active ? AppColors.card : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _goalField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _goal,
        maxLines: 2,
        minLines: 1,
        enabled: !_running,
        style: uiStyle(size: 14, weight: FontWeight.w600),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'e.g. order milk on Blinkit',
          hintStyle: uiStyle(size: 14, color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _controls() {
    return Row(
      children: [
        Switch.adaptive(
          value: _fastMode,
          activeThumbColor: AppColors.gold,
          onChanged: _running ? null : (v) => setState(() => _fastMode = v),
        ),
        const SizedBox(width: 4),
        Text('Fast mode', style: uiStyle(size: 13, weight: FontWeight.w600)),
        const Spacer(),
        InkResponse(
          onTap: _start,
          radius: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: _running ? AppColors.negative : AppColors.dark,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppShadows.pill,
            ),
            child: Text(
              _running ? 'Stop' : 'Run agent',
              style: uiStyle(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.card,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _warning() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Commands need Termux with android-tools and a paired wireless ADB '
        'session (adb connect localhost:5555).',
        style: uiStyle(size: 11, color: AppColors.negative),
      ),
    );
  }

  Widget _terminal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 1),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: _log.length,
        itemBuilder: (context, index) {
          final line = _log[_log.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line.text,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                height: 1.4,
                color: line.text.startsWith('adb shell')
                    ? AppColors.gold
                    : const Color(0xFFE9E3D4),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogLine {
  _LogLine(this.text);

  final String text;
}

class _AgentCommand {
  _AgentCommand({required this.command, required this.thought});

  final String command;
  final String thought;
}
