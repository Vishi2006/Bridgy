import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional Supabase connection.
///
/// Configure with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
/// Without it the app runs fully local: policy lives in memory and the terminal
/// log stays on device, so a demo never depends on network or credentials.
class BridgyBackend {
  BridgyBackend._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get enabled => _url.isNotEmpty && _anonKey.isNotEmpty;

  static SupabaseClient? get client =>
      enabled ? Supabase.instance.client : null;

  static Future<void> init() async {
    if (!enabled) return;
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
  }

  static String get modeLabel => enabled ? 'supabase' : 'local only';
}
