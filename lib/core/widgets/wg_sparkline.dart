import 'package:flutter/material.dart';

/// Tiny line chart for the earnings hero. Normalizes [values] to fit
/// [height] and draws a soft fill below the line for emphasis.
class WgSparkline extends StatelessWidget {
  const WgSparkline({
    super.key,
    required this.values,
    this.color = Colors.white,
    this.fillOpacity = 0.2,
    this.strokeWidth = 2.5,
    this.height = 60,
  });

  final List<double> values;
  final Color color;
  final double fillOpacity;
  final double strokeWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (_, t, _) {
          return CustomPaint(
            painter: _SparkPainter(
              values: values,
              color: color,
              fillOpacity: fillOpacity,
              strokeWidth: strokeWidth,
              progress: t,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.fillOpacity,
    required this.strokeWidth,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double fillOpacity;
  final double strokeWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);
    final stepX = size.width / (values.length - 1);

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final norm = (values[i] - minV) / range;
      final y =
          size.height - (norm * (size.height - strokeWidth)) - strokeWidth / 2;
      pts.add(Offset(stepX * i, y));
    }

    final cutoff = (pts.length * progress).clamp(0, pts.length).toDouble();
    final visiblePts = <Offset>[];
    for (var i = 0; i < pts.length; i++) {
      if (i + 1 <= cutoff) {
        visiblePts.add(pts[i]);
      } else if (i.toDouble() < cutoff) {
        final frac = cutoff - i;
        final last = pts[i];
        final next = pts[i + 1];
        visiblePts.add(Offset.lerp(last, next, frac)!);
      }
    }
    if (visiblePts.length < 2) return;

    final linePath = Path()..moveTo(visiblePts.first.dx, visiblePts.first.dy);
    for (var i = 1; i < visiblePts.length; i++) {
      linePath.lineTo(visiblePts[i].dx, visiblePts[i].dy);
    }

    if (fillOpacity > 0) {
      final fillPath = Path.from(linePath)
        ..lineTo(visiblePts.last.dx, size.height)
        ..lineTo(visiblePts.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()..color = color.withValues(alpha: fillOpacity),
      );
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.progress != progress || old.values != values;
}
