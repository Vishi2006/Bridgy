/// Pre-calibrated tap sequences ("fast mode" from the PRD).
///
/// Coordinates are fractions of the screen so one macro works on any
/// resolution; verify the fractions once on the demo phone with
/// Developer Options -> Pointer location, then adjust here.
library;

class MacroStep {
  const MacroStep.shell(this.command, {this.waitMs = 1000}) : raw = false;
  const MacroStep.raw(this.command, {this.waitMs = 1000}) : raw = true;

  final String command;
  final int waitMs;
  final bool raw;
}

class Macro {
  Macro._(this.packageName, this.label);

  final String packageName;
  final String label;

  static const _apps = <String, List<String>>{
    'rapido': ['com.rapido.passenger', 'Rapido'],
    'blinkit': ['com.grofers.customerapp', 'Blinkit'],
    'zepto': ['com.zeptoconsumerapp', 'Zepto'],
    'chrome': ['com.android.chrome', 'Chrome'],
  };

  /// Picks a macro from the user goal. Defaults to Chrome search.
  static Macro forGoal(String goal) {
    final lower = goal.toLowerCase();
    for (final entry in _apps.entries) {
      if (lower.contains(entry.key)) {
        return Macro._(entry.value[0], entry.value[1]);
      }
    }
    return Macro._('com.android.chrome', 'Chrome');
  }

  List<MacroStep> steps(String goal) {
    final query = _query(goal);
    return switch (packageName) {
      'com.rapido.passenger' => [
        _launch,
        _tap(0.50, 0.13, waitMs: 1400),
        MacroStep.shell('input text "$query"', waitMs: 1400),
        MacroStep.shell('input keyevent 66', waitMs: 2000),
        _tap(0.50, 0.34, waitMs: 1600),
        _tap(0.50, 0.90, waitMs: 1200),
      ],
      'com.grofers.customerapp' => [
        _launch,
        _tap(0.52, 0.10, waitMs: 1400),
        MacroStep.shell('input text "$query"', waitMs: 1600),
        MacroStep.shell('input keyevent 66', waitMs: 2000),
        _tap(0.30, 0.45, waitMs: 1400),
      ],
      'com.zeptoconsumerapp' => [
        _launch,
        _tap(0.50, 0.12, waitMs: 1400),
        MacroStep.shell('input text "$query"', waitMs: 1600),
        MacroStep.shell('input keyevent 66', waitMs: 2000),
        _tap(0.30, 0.45, waitMs: 1400),
      ],
      _ => [
        _launch,
        _tap(0.50, 0.18, waitMs: 1600),
        MacroStep.shell('input text "$query"', waitMs: 1200),
        MacroStep.shell('input keyevent 66', waitMs: 2400),
      ],
    };
  }

  MacroStep get _launch => MacroStep.raw(
    'monkey -p $packageName -c android.intent.category.LAUNCHER 1',
    waitMs: 2400,
  );

  static String _query(String goal) {
    final markers = RegExp(
      r'\b(?:to|for|order|book)\b\s+',
      caseSensitive: false,
    ).allMatches(goal);
    final start = markers.isEmpty ? 0 : markers.last.end;
    final tail = goal.substring(start);
    final subject = tail
        .split(RegExp(r'\s+on\s+|\s+from\s+', caseSensitive: false))
        .first;
    final cleaned = subject
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '%s');
    return cleaned.isEmpty ? 'search' : cleaned;
  }

  static MacroStep _tap(double fx, double fy, {int waitMs = 1000}) =>
      MacroStep.shell(
        'input tap ${(1080 * fx).round()} ${(2400 * fy).round()}',
        waitMs: waitMs,
      );
}
