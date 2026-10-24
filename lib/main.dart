import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'overlay/bridgy_hud.dart';
import 'screens/home_screen.dart';
import 'screens/upi_checkout_screen.dart';
import 'services/backend.dart';
import 'theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await BridgyBackend.init();
  _listenForUpiLinks();
  runApp(const MyApp());
}

/// Focused screen for `upi://pay` requests. The Android intent filter routes
/// Blinkit, Rapido and Zepto checkouts here.
void _listenForUpiLinks() {
  final links = AppLinks();

  void open(Uri uri) {
    if (uri.scheme.toLowerCase() != 'upi') return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => UpiCheckoutScreen(link: uri.toString()),
      ),
    );
  }

  links.getInitialLink().then((uri) {
    if (uri != null) open(uri);
  }).catchError((Object _) => null);
  links.uriLinkStream.listen(open, onError: (Object _) {});
}

/// Floating HUD entry point, resolved by name from the overlay service.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BridgyHud(),
    ),
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
        title: 'Pesse',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: pesseTheme(),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
