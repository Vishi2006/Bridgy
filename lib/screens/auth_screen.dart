import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthState;

import '../icons.dart';
import '../services/backend.dart';
import '../theme.dart';

/// Sign-in gate shown before the wallet shell when Supabase is configured.
///
/// Google is one option; email + password and a magic link work without a
/// Google OAuth client. Every failure is shown with Supabase's exact message.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = BridgyBackend.authChanges.listen((state) {
      if (!mounted) return;
      if (state.session != null) {
        setState(() {
          _busy = false;
          _error = null;
          _notice = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _email.dispose();
    _password.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User closed the browser without finishing: let them retry.
    if (state == AppLifecycleState.resumed &&
        _busy &&
        !BridgyBackend.isSignedIn) {
      setState(() => _busy = false);
    }
  }

  String? _emailError() {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordError() {
    if (_password.text.isEmpty) return 'Enter your password.';
    if (_password.text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String _message(Object error) =>
      error is AuthException ? error.message : error.toString();

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final emailError = _emailError();
    final passwordError = _passwordError();
    if (emailError != null || passwordError != null) {
      setState(() => _error = emailError ?? passwordError);
      return;
    }
    await _run(
      () => BridgyBackend.signInWithEmail(_email.text.trim(), _password.text),
    );
  }

  Future<void> _signUp() async {
    final emailError = _emailError();
    final passwordError = _passwordError();
    if (emailError != null || passwordError != null) {
      setState(() => _error = emailError ?? passwordError);
      return;
    }
    final email = _email.text.trim();
    await _run(() async {
      final response = await BridgyBackend.signUpWithEmail(
        email,
        _password.text,
      );
      if (response.session == null && mounted) {
        setState(() {
          _notice = 'Account created. Check $email for the confirmation link.';
        });
      }
    });
  }

  Future<void> _magicLink() async {
    final emailError = _emailError();
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    final email = _email.text.trim();
    await _run(() async {
      await BridgyBackend.sendMagicLink(email);
      if (mounted) {
        setState(() => _notice = 'Sign-in link sent to $email.');
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    await _run(() async {
      final launched = await BridgyBackend.signInWithGoogle();
      if (!launched) {
        throw const BackendNotConfigured();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _badge(),
                const SizedBox(height: 28),
                _mark(),
                const SizedBox(height: 20),
                Text(
                  'Bridgy',
                  textAlign: TextAlign.center,
                  style: displayStyle(size: 42, spacing: -1.6),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your money, on your terms.',
                  textAlign: TextAlign.center,
                  style: uiStyle(size: 14, color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 26),
                _field(
                  key: const Key('auth-email'),
                  controller: _email,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('auth-password'),
                  controller: _password,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorBox(_error!),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  _noticeBox(_notice!),
                ],
                const SizedBox(height: 16),
                _primaryButton(
                  key: const Key('auth-sign-in'),
                  label: 'Sign in with email',
                  onTap: _busy ? null : _signIn,
                ),
                const SizedBox(height: 8),
                _secondaryButton(
                  key: const Key('auth-sign-up'),
                  label: 'Create account',
                  onTap: _busy ? null : _signUp,
                ),
                TextButton(
                  key: const Key('auth-magic-link'),
                  onPressed: _busy ? null : _magicLink,
                  child: Text(
                    'Email me a sign-in link',
                    style: uiStyle(size: 12, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 6),
                _divider(),
                const SizedBox(height: 14),
                _googleButton(),
                const SizedBox(height: 18),
                const _Point(
                  icon: Icons8.shieldCheck,
                  text: 'Every agent payment stops at your policy limit.',
                ),
                const SizedBox(height: 10),
                const _Point(
                  icon: Icons8.fingerprint,
                  text: 'Session keys stay on the backend, never on the phone.',
                ),
                if (!BridgyBackend.enabled) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Local mode: no cloud account attached.',
                    textAlign: TextAlign.center,
                    style: uiStyle(size: 11, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Iterable<String>? autofillHints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: uiStyle(size: 11, color: AppColors.muted)),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          enabled: !_busy,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          style: uiStyle(size: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: uiStyle(size: 13, color: AppColors.muted),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBox(String message) {
    return Container(
      key: const Key('auth-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(Icons8.alert, size: 15, color: AppColors.negative),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: uiStyle(size: 12, color: AppColors.negative, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeBox(String message) {
    return Container(
      key: const Key('auth-notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(Icons8.check, size: 15, color: Color(0xFF15803D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: uiStyle(
                size: 12,
                color: const Color(0xFF15803D),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required Key key,
    required String label,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        key: key,
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: uiStyle(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _secondaryButton({
    required Key key,
    required String label,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        key: key,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(label, style: uiStyle(size: 13, weight: FontWeight.w600)),
      ),
    );
  }

  Widget _divider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: uiStyle(size: 11, color: AppColors.muted)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _badge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'Secure sign-in',
              style: uiStyle(
                size: 10,
                weight: FontWeight.w700,
                color: AppColors.muted,
                spacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mark() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9D6A8), AppColors.gold, AppColors.goldDeep],
          ),
          border: Border.all(color: AppColors.goldSoft, width: 4),
          boxShadow: AppShadows.pill,
        ),
        child: Center(
          child: Text(
            'B',
            style: displayStyle(size: 32, color: AppColors.dark, spacing: -2),
          ),
        ),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        key: const Key('google-sign-in'),
        onPressed: _busy ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.card,
          disabledBackgroundColor: AppColors.card,
          foregroundColor: AppColors.ink,
          elevation: 0,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4285F4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: uiStyle(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.goldSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: AppIcon(icon, size: 15, color: AppColors.goldText),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: uiStyle(size: 12, color: AppColors.ink, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}
