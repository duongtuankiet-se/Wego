import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Official Google "G" logo in 4 brand colors, drawn entirely via
/// `CustomPainter` so we don't need to ship a PNG asset. The shape is a
/// stroked ring (4 colored arcs) with a horizontal blue bar tucked into
/// the right-side opening — a recognizable rendition of the canonical
/// Google identity guideline (https://about.google/brand-resource-center/).
///
/// Use it as a drop-in icon (default 22×22 fits inside the standard
/// 56-tall auth button).
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC04);
  static const _green = Color(0xFF34A853);

  // Small angular gap on the right side of the ring where the horizontal
  // blue bar emerges. Tuned so the arc seams sit just behind the bar's
  // top and bottom edges, giving the classic "G notch" silhouette.
  static const double _barGap = 0.42; // ~24°

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Stroke width relative to size keeps the logo crisp at any scale.
    final strokeWidth = w * 0.21;
    // Ring radius = (size - strokeWidth)/2 so the ring sits flush inside
    // the bounding box.
    final radius = (w - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Flutter arc angles: 0rad = 3 o'clock, +π/2 = 6, +π = 9, -π/2 = 12.
    const halfPi = math.pi / 2;

    // Red: top-left quadrant (9 o'clock → 12 o'clock)
    canvas.drawArc(rect, -math.pi, halfPi, false, stroke..color = _red);

    // Blue: top-right quadrant, stopping short of 3 o'clock for the bar.
    canvas.drawArc(
      rect,
      -halfPi,
      halfPi - _barGap / 2,
      false,
      stroke..color = _blue,
    );

    // Green: bottom-right quadrant, starting just past the bar.
    canvas.drawArc(
      rect,
      _barGap / 2,
      halfPi - _barGap / 2,
      false,
      stroke..color = _green,
    );

    // Yellow: bottom-left quadrant (6 → 9 o'clock)
    canvas.drawArc(rect, halfPi, halfPi, false, stroke..color = _yellow);

    // Horizontal blue bar: emerges from the center going right, height
    // matches the stroke so it visually continues from the blue arc.
    // Left edge sits at the horizontal midpoint of the ring; right edge
    // reaches the outer rim of the ring (radius + half stroke).
    final barFill = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    final barLeft = center.dx + strokeWidth * 0.05;
    final barRight = center.dx + radius + strokeWidth * 0.5;
    final barRect = Rect.fromLTRB(
      barLeft,
      center.dy - strokeWidth / 2,
      barRight,
      center.dy + strokeWidth / 2,
    );
    canvas.drawRect(barRect, barFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
