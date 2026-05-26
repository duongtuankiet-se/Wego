import 'package:flutter/material.dart';

/// Border-radius tokens. Phase 5 Xanh SM scale: generous 20-28px corners.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20; // buttons + inputs
  static const double xl = 24; // cards (signature)
  static const double xxl = 28; // hero banners + search pill
  static const double xxxl = 32; // sheet top
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static const BorderRadius card = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius button = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius input = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius search = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius heroCard = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xxxl),
  );
  static const BorderRadius tabBarTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
