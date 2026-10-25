import 'package:flutter/material.dart';

/// Unipay design tokens lifted from the reference HTML.
abstract final class U {
  static const dark = Color(0xFF121214);
  static const darkSurface = Color(0xFF1C1C1E);
  static const cardDark = Color(0xFF1F1F24);
  static const yellow = Color(0xFFFEC81A);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF1E66FF);
  static const bg = Color(0xFFFBFBFD);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF171717);
  static const grey = Color(0xFF9CA3AF);
  static const line = Color(0xFFE5E7EB);
  static const pink = Color(0xFFF9A8B8);
  static const red = Color(0xFFD61E38);
  static const appDark = Color(0xFF0E0E11);
  static const digitMuted = Color(0xFF2A2B32);
  static const accentYellow = Color(0xFFF5C344);
}

abstract final class UF {
  static const sans = 'PlusJakartaSans';
}

TextStyle uText({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = U.ink,
  double? height,
  double spacing = 0,
}) => TextStyle(
  fontFamily: UF.sans,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: spacing,
);

abstract final class UArt {
  static const card = '''
<svg viewBox="0 0 350 216" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
<path d="M60 -20 C100 20 80 50 130 50 C180 50 200 -10 240 -10 L120 -50 Z" fill="#2563eb"/>
<path d="M80 0 C110 30 140 20 160 5 C190 -15 210 20 250 0 C280 -15 320 -20 360 20 L360 -40 L70 -40 Z" fill="#ffffff"/>
<path d="M120 15 C145 35 170 30 190 20 C215 8 230 25 260 12 L260 -5 Z" fill="#ffffff"/>
</svg>''';

  static const ukraine = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path d="M12 2L9 8H15L12 2Z" fill="#ff4d4d"/>
<path d="M12 22L9 16H15L12 22Z" fill="#ff4d4d"/>
<path d="M2 12L8 9V15L2 12Z" fill="#eab308"/>
<path d="M22 12L16 9V15L22 12Z" fill="#eab308"/>
<circle cx="12" cy="12" r="3" fill="#ffda44"/>
</svg>''';

  static const dribbble = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path clip-rule="evenodd" fill-rule="evenodd" fill="#ea4c89" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10c5.51 0 10-4.48 10-10A10 10 0 0 0 12 2Zm7.93 9.02c-.37-.08-2.31-.46-4.66.21-.19-.44-.39-.88-.6-1.31 3.01-1.37 4.22-3.14 4.34-3.32a8.03 8.03 0 0 1 .92 4.42Zm-2.34-5.69c-.21.25-1.5 1.83-4.32 3.09-1.31-2.4-2.78-4.43-2.97-4.7a8.04 8.04 0 0 1 7.29 1.61ZM9.9 5.37c.2.27 1.63 2.27 2.92 4.63-2.73 1.05-5.69 1.06-6.19 1.06h-.14a7.99 7.99 0 0 1 3.41-5.69ZM4 12c0-.15.01-.3.03-.45.45.01 3.75.05 6.83-1.12.23.47.45.95.66 1.43-3.66 1.15-7.07 4.42-7.3 4.65A7.95 7.95 0 0 1 4 12Zm3.49 5.86c.33-.31 3.29-3.08 6.94-4.13 1.02 2.65 1.45 5.16 1.54 5.76a7.98 7.98 0 0 1-8.48-1.63Zm10.15.22c-.11-.53-.51-2.85-1.47-5.38 2.19-.71 4.14-.38 4.51-.31a8.02 8.02 0 0 1-3.04 5.69Z"/>
</svg>''';

  static const mailchimp = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path fill="#000" d="M12 2a5 5 0 0 0-4.8 3.6A4.5 4.5 0 0 0 3 10a4.5 4.5 0 0 0 2.2 3.9A6.5 6.5 0 0 0 12 21a6.5 6.5 0 0 0 6.8-7.1A4.5 4.5 0 0 0 21 10a4.5 4.5 0 0 0-4.2-4.4A5 5 0 0 0 12 2Zm-2.8 7.2a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4Zm5.6 0a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4Zm-5.3 4.9c.7.9 1.7 1.4 2.5 1.4s1.8-.5 2.5-1.4c.2-.3.6-.3.9-.1.3.2.3.6.1.9-1 1.2-2.2 1.8-3.5 1.8s-2.5-.6-3.5-1.8a.7.7 0 0 1 .1-.9c.3-.2.7-.2.9.1Z"/>
</svg>''';

  static const home =
      '<path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>';
  static const bell =
      '<path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/>';
  static const plus = '<path d="M12 6v12m6-6H6"/>';
  static const agent =
      '<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/><path d="M12 8v.01M12 11v2"/>';
  static const arrowUpRight = '<path d="M7 17L17 7M17 7H9M17 7V15"/>';
  static const arrowDownLeft = '<path d="M17 7L7 17M7 17H15M7 17V9"/>';
}

ThemeData unipayTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: UF.sans,
    scaffoldBackgroundColor: U.appDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: U.lightBlue,
      primary: U.lightBlue,
      secondary: U.yellow,
      surface: U.cardDark,
      brightness: Brightness.dark,
    ),
  );
  return base.copyWith(
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      fontFamily: UF.sans,
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}
