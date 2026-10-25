import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'overlay/bridgy_hud.dart';
import 'screens/app_shell.dart';
import 'screens/upi_checkout_screen.dart';
import 'services/backend.dart';
import 'services/goal_intake.dart';
import 'state/wallet_store.dart';
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
    _listenForUpiLinks();
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

/// UPI requests open the policy checkout for the merchant's amount.
void _listenForUpiLinks() {
  final links = AppLinks();

  void open(Uri uri) {
    if (uri.scheme.toLowerCase() != 'upi') return;
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
  }

  links
      .getInitialLink()
      .then((uri) {
        if (uri != null) open(uri);
      })
      .catchError((Object _) => null);
  links.uriLinkStream.listen(open, onError: (Object _) {});
}

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
