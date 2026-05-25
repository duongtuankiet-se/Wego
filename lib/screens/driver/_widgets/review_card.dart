import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/wg_avatar.dart';
import '../../../core/widgets/wg_chip.dart';
import '../../../data/mock_reviews.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});
  final DriverReview review;

  String _formatDate(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WgAvatar(name: review.reviewerName, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < review.stars
                          ? AppColors.warning
                          : AppColors.ink300,
                      size: 16,
                    ),
                  ),
                ),
                if (review.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: review.tags.map((t) => WgChip(label: t)).toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '"${review.comment}"',
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink700,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${review.reviewerName} · ${_formatDate(review.createdAt)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
