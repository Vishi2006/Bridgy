import 'package:flutter/material.dart';

abstract final class AppColors {
  static const gold = Color(0xFFC9A961);
  static const goldDeep = Color(0xFFA9863D);
  static const goldText = Color(0xFF8A6A2A);
  static const goldSoft = Color(0xFFEFE4CC);
  static const bg = Color(0xFFF6F3EC);
  static const bgAlt = Color(0xFFF4F1EA);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7E1D4);
  static const pill = Color(0xFFEEEAE0);
  static const ink = Color(0xFF171513);
  static const muted = Color(0xFF8A8578);
  static const dark = Color(0xFF141312);
  static const negative = Color(0xFFC2554A);
  static const star = Color(0xFFE0B94F);
  static const navInactive = Color(0xFF6F6A60);
}

abstract final class AppFonts {
  static const display = 'Fraunces';
  static const ui = 'Manrope';
  static const mono = 'JetBrainsMono';
  static const script = 'PlayfairDisplay';
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x0A1F190F), blurRadius: 30, offset: Offset(0, 8)),
  ];
  static const cardSoft = [
    BoxShadow(color: Color(0x0F1F190F), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A1F190F), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const nav = [
    BoxShadow(
      color: Color(0x661F190F),
      blurRadius: 30,
      spreadRadius: -5,
      offset: Offset(0, 10),
    ),
  ];
  static const pill = [
    BoxShadow(color: Color(0x2E1F190F), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

TextStyle uiStyle({
  double size = 13,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink,
  double? height,
  double spacing = 0,
}) => TextStyle(
  fontFamily: AppFonts.ui,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: spacing,
);

TextStyle displayStyle({
  double size = 34,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.ink,
  double spacing = -1,
  double height = 1.1,
}) => TextStyle(
  fontFamily: AppFonts.display,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: spacing,
  height: height,
);

ThemeData pesseTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.ui,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      primary: AppColors.gold,
      surface: AppColors.card,
      brightness: Brightness.light,
    ),
  );
  return base.copyWith(
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      fontFamily: AppFonts.ui,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
