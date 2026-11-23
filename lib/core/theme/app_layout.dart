import 'package:flutter/widgets.dart';

/// Small shared layout values used by cards and compact control groups.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;

  static const EdgeInsets cardContent = EdgeInsets.all(md);
}

abstract final class AppRadii {
  static const double control = 12;
  static const double card = 16;
  static const double dialog = 24;
}
