import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../icons.dart';
import '../services/backend.dart';
import '../theme.dart';

/// Sign-in gate shown before the wallet shell when Supabase is configured.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  bool _busy = false;
  String? _error;

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
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
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

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final launched = await BridgyBackend.signInWithGoogle();
      if (!launched && mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not open the Google sign-in page.';
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _badge(),
                const Spacer(),
                _mark(),
                const SizedBox(height: 24),
                Text(
                  'Bridgy',
                  textAlign: TextAlign.center,
                  style: displayStyle(size: 46, spacing: -1.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your money, on your terms.',
                  textAlign: TextAlign.center,
                  style: uiStyle(size: 14, color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 32),
                const _Point(
                  icon: Icons8.shieldCheck,
                  text: 'Every agent payment stops at your policy limit.',
                ),
                const SizedBox(height: 14),
                const _Point(
                  icon: Icons8.fingerprint,
                  text: 'Session keys stay on the backend, never on the phone.',
                ),
                const SizedBox(height: 14),
                const _Point(
                  icon: Icons8.bolt,
                  text: 'UPI checkout and app tasks in one place.',
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: uiStyle(
                      size: 12,
                      color: AppColors.negative,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _googleButton(),
                const SizedBox(height: 14),
                Text(
                  'Bridgy never sees your Google password. Sign-in is handled by Supabase.',
                  textAlign: TextAlign.center,
                  style: uiStyle(size: 11, color: AppColors.muted, height: 1.5),
                ),
                if (!BridgyBackend.enabled) ...[
                  const SizedBox(height: 10),
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
        width: 88,
        height: 88,
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
            style: displayStyle(size: 40, color: AppColors.dark, spacing: -2),
          ),
        ),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        key: const Key('google-sign-in'),
        onPressed: _busy ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dark,
          disabledBackgroundColor: AppColors.dark.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Text(
              _busy ? 'Waiting for Google…' : 'Continue with Google',
              style: uiStyle(
                size: 14,
                weight: FontWeight.w700,
                color: Colors.white,
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
