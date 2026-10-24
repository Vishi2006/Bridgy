import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// Inline lucide-style paths copied from the reference renders.
abstract final class Icons8 {
  static const help =
      '<circle cx="12" cy="12" r="9"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3m.08 4h.01"/>';
  static const helpAlt =
      '<path d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>';
  static const gift =
      '<path d="M12 8v13m0-13V4.5a2.5 2.5 0 1 1 5 0V8m-5 0H3a2 2 0 0 0-2 2v2a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2v-2a2 2 0 0 0-2-2h-9zm0 0h9a2.5 2.5 0 1 0-5 0V8"/>';
  static const chevronDown = '<path d="M19 9l-7 7-7-7"/>';
  static const arrowUpRight = '<path d="M7 17L17 7M17 7H9M17 7V15"/>';
  static const arrowDownLeft = '<path d="M17 7L7 17M7 17H15M7 17V9"/>';
  static const dollar =
      '<path d="M12 6v12m-3-9h6a2.5 2.5 0 0 1 0 5H9a2.5 2.5 0 0 0 0 5h6"/>';
  static const plus = '<path d="M12 4v16m8-8H4"/>';
  static const dribbble =
      '<circle cx="12" cy="12" r="9"/><path d="M3.6 9h16.8M3.6 15h16.8M11.5 3a17 17 0 0 0 0 18M12.5 3a17 17 0 0 1 0 18"/>';
  static const navHome =
      '<path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>';
  static const navActivity =
      '<circle cx="12" cy="12" r="9"/><path d="M8 12l2.5 2.5L16 9"/>';
  static const navCards =
      '<rect x="3" y="5" width="18" height="14" rx="2"/><line x1="3" x2="21" y1="10" y2="10"/>';
  static const navFinances =
      '<circle cx="12" cy="12" r="9"/><path d="M12 7v10M9 9.5a2.5 2.5 0 0 1 5 0c0 1.5-2 2-2 3.5"/>';
  static const navProfile =
      '<path d="M16 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="10" cy="7" r="4"/>';
  static const back = '<path d="M10 19l-7-7m0 0l7-7m-7 7h18"/>';
  static const close =
      '<line x1="18" x2="6" y1="6" y2="18"/><line x1="6" x2="18" y1="6" y2="18"/>';
  static const check = '<polyline points="20 6 9 17 4 12"/>';
  static const backspace =
      '<path fill-rule="evenodd" clip-rule="evenodd" d="M2.5 12a2 2 0 0 1 .586-1.414l5-5A2 2 0 0 1 9.5 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-10a2 2 0 0 1-1.414-.586l-5-5A2 2 0 0 1 2.5 12Zm11.707-2.707a1 1 0 0 0-1.414 1.414L14.086 12l-1.293 1.293a1 1 0 1 0 1.414 1.414L15.5 13.414l1.293 1.293a1 1 0 0 0 1.414-1.414L16.914 12l1.293-1.293a1 1 0 0 0-1.414-1.414L15.5 10.586l-1.293-1.293Z"/>';
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.paths, {
    super.key,
    this.size = 20,
    this.color = AppColors.ink,
    this.strokeWidth = 2,
    this.filled = false,
  });

  final String paths;
  final double size;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final svg =
        '<svg viewBox="0 0 24 24" fill="${filled ? 'currentColor' : 'none'}" '
        'stroke="currentColor" stroke-width="$strokeWidth" '
        'stroke-linecap="round" stroke-linejoin="round" '
        'xmlns="http://www.w3.org/2000/svg">$paths</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
