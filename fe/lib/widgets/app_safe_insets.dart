import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'fab_notched_bottom_bar.dart';

class AppSafeInsets {
  static const double defaultSheetGap = 24;
  static const double defaultFloatingGap = 20;
  static const double defaultBottomNavScrollGap = 88;
  static const double defaultFloatingActionScrollGap = 100;

  const AppSafeInsets._();

  static double systemBottom(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  static double keyboardBottom(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom;
  }

  static double keyboardOrSystemBottom(BuildContext context) {
    return math.max(keyboardBottom(context), systemBottom(context));
  }

  static double floatingBottom(
    BuildContext context, {
    double base = defaultFloatingGap,
  }) {
    return base + systemBottom(context);
  }

  static double sheetBottomPadding(
    BuildContext context, {
    double base = defaultSheetGap,
  }) {
    return base + keyboardOrSystemBottom(context);
  }

  static double bottomNavScrollPadding(
    BuildContext context, {
    double gap = defaultBottomNavScrollGap,
    double barHeight = FabNotchedBottomBar.defaultHeight,
  }) {
    return FabNotchedBottomBar.effectiveHeight(
          context,
          height: barHeight,
        ) +
        gap;
  }

  static double floatingActionScrollPadding(
    BuildContext context, {
    double gap = defaultFloatingActionScrollGap,
  }) {
    return gap + systemBottom(context);
  }

  static EdgeInsets bottomNavListPadding(
    BuildContext context, {
    double left = 16,
    double top = 16,
    double right = 16,
    double gap = defaultBottomNavScrollGap,
  }) {
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottomNavScrollPadding(context, gap: gap),
    );
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double left = 16,
    double top = 16,
    double right = 16,
    double bottom = 16,
  }) {
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom + systemBottom(context),
    );
  }
}
