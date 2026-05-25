import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated user-location pin: 3 expanding rings + a solid dot.
/// Drop inside a [MarkerLayer] of flutter_map at the user position.
class WgMapPin extends StatefulWidget {
  const WgMapPin({
    super.key,
    this.color = AppColors.primary500,
    this.size = 60,
  });

  final Color color;
  final double size;

  @override
  State<WgMapPin> createState() => _WgMapPinState();
}

class _WgMapPinState extends State<WgMapPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++) _ring(i),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int index) {
    final t = (_controller.value + index * 0.33) % 1.0;
    final scale = 0.5 + t * 1.0; // 0.5 → 1.5
    final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.35;
    final ringSize = widget.size * scale;
    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: opacity),
      ),
    );
  }
}
