import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../theme.dart';

/// Content of the floating HUD. Runs in its own isolate, so it only receives
/// strings pushed with `FlutterOverlayWindow.shareData`.
class BridgyHud extends StatefulWidget {
  const BridgyHud({super.key});

  @override
  State<BridgyHud> createState() => _BridgyHudState();
}

class _BridgyHudState extends State<BridgyHud> {
  static const _maxLines = 5;
  final List<String> _lines = [];
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((event) {
      final text = event is Map ? event['line'] as String? : event?.toString();
      if (text == null || text.isEmpty) return;
      setState(() {
        _lines.add(text);
        if (_lines.length > _maxLines) _lines.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xF2141312),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55141312),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'BRIDGY AGENT',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in _lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10.5,
                    height: 1.35,
                    color: Color(0xFFE9E3D4),
                  ),
                ),
              ),
            if (_lines.isEmpty)
              const Text(
                'idle',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10.5,
                  color: Color(0xFF8A8578),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
