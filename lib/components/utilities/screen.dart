import 'dart:ui';
import 'package:flutter/material.dart';

/// Helper class to get screen dimensions and insets without needing a BuildContext, since the popup is rendered in an OverlayEntry outside the original widget tree.
abstract class Screen {
  static MediaQueryData get mediaQuery => MediaQueryData.fromView(PlatformDispatcher.instance.views.first);

  /// screen width
  static double get width => mediaQuery.size.width;

  /// screen height
  static double get height => mediaQuery.size.height;

  /// top
  static double get statusBar => mediaQuery.padding.top;

  /// bottom
  static double get bottomBar => mediaQuery.padding.bottom;

  /// left
  static double get leftInset => mediaQuery.padding.left;

  /// right
  static double get rightInset => mediaQuery.padding.right;
}
