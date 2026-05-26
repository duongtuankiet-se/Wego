import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PhosphorIcon extends StatelessWidget {
  const PhosphorIcon(
    this.icon, {
    super.key,
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    this.shadows,
    this.semanticLabel,
    this.textDirection,
    this.duotoneSecondaryOpacity = 0.20,
    this.duotoneSecondaryColor,
  });

  /// Accepts a plain [IconData] (used by Regular/Fill/Thin/Light/Bold
  /// variants) OR a [PhosphorDuotoneIconData] (duotone variant).
  final Object icon;
  final double? size;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final Color? color;
  final List<Shadow>? shadows;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final double duotoneSecondaryOpacity;
  final Color? duotoneSecondaryColor;

  @override
  Widget build(BuildContext context) {
    final ic = icon;
    if (ic is PhosphorDuotoneIconData) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: duotoneSecondaryOpacity,
            child: Icon(
              ic.secondary,
              size: size,
              fill: fill,
              weight: weight,
              grade: grade,
              opticalSize: opticalSize,
              color: duotoneSecondaryColor ?? color,
              shadows: shadows,
              semanticLabel: semanticLabel,
              textDirection: textDirection,
            ),
          ),
          Icon(
            ic.primary,
            size: size,
            fill: fill,
            weight: weight,
            grade: grade,
            opticalSize: opticalSize,
            color: color,
            shadows: shadows,
            semanticLabel: semanticLabel,
            textDirection: textDirection,
          ),
        ],
      );
    }
    if (ic is IconData) {
      return Icon(
        ic,
        size: size,
        fill: fill,
        weight: weight,
        grade: grade,
        opticalSize: opticalSize,
        color: color,
        shadows: shadows,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
      );
    }
    throw ArgumentError(
      'PhosphorIcon expected IconData or PhosphorDuotoneIconData, got '
      '${ic.runtimeType}',
    );
  }
}
