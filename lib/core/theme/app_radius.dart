import 'package:flutter/material.dart';

/// Border-radius tokens. iOS 26-style — generous corners across the board.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 18; // buttons
  static const double xl = 24; // cards
  static const double xxl = 28;
  static const double sheet = 32; // bottom sheet top
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static const BorderRadius card = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius button = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius input = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
