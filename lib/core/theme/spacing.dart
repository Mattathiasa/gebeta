import 'package:flutter/material.dart';

abstract final class GebetaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets page = EdgeInsets.all(lg);
}

abstract final class GebetaRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double pillRadius = 999;

  /// Pits are carved circles — nothing on this board is rectangular.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(pillRadius));
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(lg));
}
