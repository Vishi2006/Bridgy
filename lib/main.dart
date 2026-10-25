import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'overlay/bridgy_hud.dart';
import 'screens/app_shell.dart';
import 'screens/upi_checkout_screen.dart';
import 'services/backend.dart';
import 'services/goal_intake.dart';
import 'state/wallet_store.dart';
import 'theme.dart';
import 'unipay.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<AppShellState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await BridgyBackend.init();
  await WalletStore.instance.load();
  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _listenForDeepLinks();
    _listenForGoals();
  });
}

void _listenForGoals() {
  GoalIntake.takeLaunchGoal().then((goal) {
    if (goal != null) _openGoal(goal);
  });
  GoalIntake.goals().listen(_openGoal, onError: (Object _) {});
}

void _openGoal(String goal) {
  _shellKey.currentState?.openAgent(goal);
}

/// Listens for incoming deep links:
/// - `upi://pay`: UPI payment checkout interception
/// - `bridgy://*` or `com.bridgy.bridgy://*`: Email verification & auth callbacks
void _listenForDeepLinks() {
  final links = AppLinks();

  void open(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    // 1. UPI payment checkout flow
    if (scheme == 'upi') {
      _navigatorKey.currentState?.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 360),
          pageBuilder: (_, _, _) => UpiCheckoutScreen(link: uri.toString()),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        ),
      );
      return;
    }

    // 2. Auth redirect & email verification flow (e.g. bridgy://login-callback)
    if (scheme == 'bridgy' || scheme == 'com.bridgy.bridgy') {
      _handleAuthRedirect(uri);
    }
  }

  links
      .getInitialLink()
      .then((uri) {
        if (uri != null) open(uri);
      })
      .catchError((Object _) => null);
  links.uriLinkStream.listen(open, onError: (Object _) {});
}

/// Handles email verification callback redirect back into the app.
void _handleAuthRedirect(Uri uri) {
  // If Supabase backend is configured, establish session from the confirmation link
  if (BridgyBackend.enabled && BridgyBackend.client != null) {
    try {
      BridgyBackend.client!.auth.getSessionFromUrl(uri);
    } catch (_) {}
  }

  // Show confirmation dialog when redirected back to Bridgy
  final context = _navigatorKey.currentContext;
  if (context != null) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: AppIcon(
                  Icons8.check,
                  size: 24,
                  color: AppColors.goldDeep,
                  strokeWidth: 2.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Email Verified!',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your email has been successfully verified. Welcome back to Bridgy!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Continue to Bridgy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating HUD entry point, resolved by name from the overlay service.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: BridgyHud()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: 1,
      child: MaterialApp(
        title: 'Bridgy',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: unipayTheme(),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: AppShell(key: _shellKey),
      ),
    );
  }
}
