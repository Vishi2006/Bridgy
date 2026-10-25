import 'dart:async';

import 'package:flutter/services.dart';

/// Receives the goal passed by Gemini (AppFunction) or a text share.
///
/// Native keeps the cold-start goal until Dart asks for it, and streams every
/// warm-start intent so a second command is not dropped.
class GoalIntake {
  static const _channel = MethodChannel('com.bridgy.app/goals');
  static const _events = EventChannel('com.bridgy.app/goals/stream');

  /// Goal that launched the app, consumed once.
  static Future<String?> takeLaunchGoal() async {
    try {
      final goal = await _channel.invokeMethod<String>('takeLaunchGoal');
      final trimmed = goal?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Goals delivered while the app is already running.
  static Stream<String> goals() {
    return _events
        .receiveBroadcastStream()
        .where((event) => event is String && event.trim().isNotEmpty)
        .map((event) => (event as String).trim());
  }
}
