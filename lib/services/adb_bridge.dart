import 'package:flutter/services.dart';

/// Failure raised by the native ADB bridge.
class AdbException implements Exception {
  AdbException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper over `com.bridgy.app/adb`.
///
/// The native side runs every command through Termux and prepends `adb shell`
/// unless [run] is called with `raw: true` (used for `adb connect ...`).
class AdbBridge {
  static const MethodChannel _channel = MethodChannel('com.bridgy.app/adb');

  Future<bool> isTermuxInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isTermuxInstalled') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> run(String command, {bool raw = false}) async {
    final normalized = raw
        ? command.trim()
        : command
              .trim()
              .replaceFirst(RegExp(r'^adb\s+shell\s+'), '');
    try {
      await _channel.invokeMethod<void>('runCommand', {
        'command': normalized,
        'raw': raw,
      });
    } on MissingPluginException {
      throw AdbException('ADB bridge unavailable on this platform');
    } on PlatformException catch (e) {
      throw AdbException(e.message ?? e.code);
    }
  }

  /// Reads `/sdcard/window_dump.xml`. Returns null when the file is missing.
  Future<String?> readScreenDump() async {
    try {
      return await _channel.invokeMethod<String>('readScreenDump');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Physical screen size, e.g. `1080x2400`.
  Future<String> screenSize() async {
    try {
      return await _channel.invokeMethod<String>('screenSize') ?? '1080x2400';
    } on MissingPluginException {
      return '1080x2400';
    } on PlatformException {
      return '1080x2400';
    }
  }

  /// Voice/share text that launched the app, if any.
  Future<String?> takeLaunchText() async {
    try {
      return await _channel.invokeMethod<String>('launchText');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
