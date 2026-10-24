import 'package:flutter/material.dart';

import 'package:bridgy/screens/home_screen.dart';
import 'package:bridgy/screens/select_card_screen.dart';
import 'package:bridgy/screens/send_money_screen.dart';
import 'package:bridgy/theme.dart';

/// Design preview entrypoint: `flutter run -t tool/preview.dart`
/// URL query `?screen=cards` or `?screen=send` selects a screen on web.
void main() {
  final screen = Uri.base.queryParameters['screen'];
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: pesseTheme(),
      home: switch (screen) {
        'cards' => const SelectCardScreen(),
        'send' => const SendMoneyScreen(),
        _ => const HomeScreen(),
      },
    ),
  );
}
