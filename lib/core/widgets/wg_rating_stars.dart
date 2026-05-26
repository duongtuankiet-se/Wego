import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';

/// Tappable 1-5 star rating selector with a small bounce on tap.
class WgRatingStars extends StatelessWidget {
  const WgRatingStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 44,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final n = i + 1;
        final selected = n <= value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _StarTap(
            selected: selected,
            size: size,
            onTap: () {
              HapticFeedback.mediumImpact();
              onChanged(n);
            },
          ),
        );
      }),
    );
  }
}

class _StarTap extends StatefulWidget {
  const _StarTap({
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  State<_StarTap> createState() => _StarTapState();
}

class _StarTapState extends State<_StarTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.8,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.8,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_bounce);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _handleTap() {
    _bounce.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Icon(
            widget.selected
                ? PhosphorIconsFill.star
                : PhosphorIconsRegular.star,
            key: ValueKey(widget.selected),
            size: widget.size,
            color: widget.selected ? AppColors.warning : AppColors.ink300,
          ),
        ),
      ),
    );
  }
}
