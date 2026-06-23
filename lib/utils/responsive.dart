import 'package:flutter/material.dart';

/// Lightweight responsive helpers — use in build() methods only.
class AppResponsive {
  AppResponsive._();

  static Size _size(BuildContext context) => MediaQuery.sizeOf(context);

  /// True for narrow devices (< 360 dp width, e.g. small Androids)
  static bool isSmall(BuildContext context) => _size(context).width < 360;

  /// True for tablet-class devices (>= 600 dp width)
  static bool isTablet(BuildContext context) => _size(context).width >= 600;

  /// Horizontal page padding — tighter on small phones
  static double hPad(BuildContext context) =>
      isSmall(context) ? 12.0 : 16.0;

  /// Card width for horizontal-scroll carousels as a fraction of screen width,
  /// clamped to [minPx..maxPx].
  static double cardW(
    BuildContext context, {
    double fraction = 0.40,
    double minPx    = 130,
    double maxPx    = 220,
  }) =>
      (_size(context).width * fraction).clamp(minPx, maxPx);

  /// Height that scales with screen width so cards feel proportional.
  static double cardH(
    BuildContext context, {
    double base     = 180,
    double refWidth = 375,
  }) =>
      base * (_size(context).width / refWidth).clamp(0.80, 1.20);

  /// Bottom padding to add below fixed-height bars (accounts for system
  /// navigation bar on Android gesture-nav / button-nav devices).
  static double navBottom(BuildContext context) =>
      MediaQuery.of(context).padding.bottom;

  /// Icon size for bottom navigation bars — shrinks on very small screens.
  static double navIconSz(BuildContext context) =>
      isSmall(context) ? 20.0 : 22.0;

  /// Generic icon size scaled from a [base] value.
  static double iconSz(BuildContext context, {double base = 24}) =>
      isSmall(context) ? (base - 2).clamp(12.0, base) : base;

  /// Font size scaled down on small screens by [delta] points.
  static double fontSize(BuildContext context, double base, {double delta = 1.5}) =>
      isSmall(context) ? (base - delta).clamp(8.0, base) : base;
}
