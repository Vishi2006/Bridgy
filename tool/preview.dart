import 'package:flutter/material.dart';

import 'package:bridgy/screens/agent_chat_screen.dart';
import 'package:bridgy/screens/app_shell.dart';
import 'package:bridgy/screens/send_money_screen.dart';
import 'package:bridgy/unipay.dart';

/// `flutter run -t tool/preview.dart` and `?screen=send|agent`.
void main() {
  final screen = Uri.base.queryParameters['screen'];
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: unipayTheme(),
      home: switch (screen) {
        'send' => SendMoneyScreen(onSent: () {}),
        'agent' => const Scaffold(body: AgentChatScreen()),
        _ => const AppShell(),
      },
    ),
  );
}
