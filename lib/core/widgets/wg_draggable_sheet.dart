import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standard sheet chrome used on every "map + content" screen:
///   * rounded-top container with soft shadow casting up,
///   * 40×4 grabber pill,
///   * snap behaviour with the three positions the screen passes in.
///
/// The [builder] receives a `ScrollController` that **must** be wired
/// into the sheet's scrollable child — otherwise drag-to-snap stops
/// working when the user scrolls inside the sheet.
class WgDraggableSheet extends StatelessWidget {
  const WgDraggableSheet({
    super.key,
    required this.builder,
    this.initialSize = 0.55,
    this.minSize = 0.30,
    this.maxSize = 0.85,
    this.snapSizes = const [0.30, 0.55, 0.85],
    this.showGrabber = true,
  });

  final Widget Function(ScrollController scrollController) builder;
  final double initialSize;
  final double minSize;
  final double maxSize;
  final List<double> snapSizes;
  final bool showGrabber;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: snapSizes,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink900.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (showGrabber)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ink300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Expanded(child: builder(scrollController)),
            ],
          ),
        );
      },
    );
  }
}
