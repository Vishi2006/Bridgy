import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection and sign-in state.
///
/// The URL and anon key are public client credentials, so they ship as
/// compile-time defaults. Override them per environment with
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
/// Never ship the service-role key here.
class BridgyBackend {
  BridgyBackend._();

  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zgkxfxehrjnncqgoqdog.supabase.co',
  );
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpna3hmeGVocmpubmNxZ29xZG9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4NTgzODAsImV4cCI6MjEwODQzNDM4MH0.7FQMp8IkwZBLibA7LDmFmZbRa55pO1RlO4DcU8aEBWU',
  );

  /// Must be on the Supabase Auth redirect allow list and declared in the
  /// Android manifest / iOS URL types.
  static const String authRedirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'bridgy://login-callback',
  );

  static bool get enabled => _url.isNotEmpty && _anonKey.isNotEmpty;

  static SupabaseClient? get client {
    if (!enabled) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Session? get session => client?.auth.currentSession;

  static User? get user => client?.auth.currentUser;

  static bool get isSignedIn => session != null;

  static Stream<AuthState> get authChanges =>
      client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  static Future<void> init() async {
    if (!enabled) return;
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
  }

  /// Opens the Supabase Google consent page in the external browser.
  ///
  /// Returns once the browser is launched. The session arrives through the
  /// `bridgy://login-callback` deep link and [authChanges].
  static Future<bool> signInWithGoogle() async {
    final supabase = client;
    if (supabase == null) return false;
    return supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  static Future<void> signOut() async {
    await client?.auth.signOut();
  }

  static String get modeLabel => enabled ? 'supabase' : 'local only';
}
