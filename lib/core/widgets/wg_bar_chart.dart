import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class WgBarChart extends StatelessWidget {
  const WgBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.highlightIndex,
    this.barColor = AppColors.primary500,
    this.highlightColor = AppColors.primary700,
    this.height = 140,
  });

  final List<int> values;
  final List<String> labels;
  final int? highlightIndex;
  final Color barColor;
  final Color highlightColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final norm = maxV == 0 ? 0.0 : (v / maxV).toDouble();
          final isHi = highlightIndex == i;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    v.toString(),
                    style: AppTypography.micro.copyWith(
                      color: isHi ? highlightColor : AppColors.ink500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: norm),
                    duration: Duration(milliseconds: 600 + i * 80),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, _) {
                      return Container(
                        height: (height - 56) * t,
                        decoration: BoxDecoration(
                          color: isHi ? highlightColor : barColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: AppTypography.micro.copyWith(
                      color: isHi ? highlightColor : AppColors.ink500,
                      fontWeight: isHi ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
