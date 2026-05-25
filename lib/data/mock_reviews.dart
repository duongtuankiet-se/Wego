class DriverReview {
  final String id;
  final String reviewerName;
  final int stars;
  final List<String> tags;
  final String comment;
  final DateTime createdAt;

  const DriverReview({
    required this.id,
    required this.reviewerName,
    required this.stars,
    required this.tags,
    required this.comment,
    required this.createdAt,
  });
}

/// Static reviews shown when the live `ratings` collection is empty.
/// Live ratings (if any) are prepended on the Performance screen.
List<DriverReview> generateMockReviews() {
  final now = DateTime.now();
  return [
    DriverReview(
      id: 'r1',
      reviewerName: 'Nguyễn V.A',
      stars: 5,
      tags: ['Lái an toàn', 'Xe sạch'],
      comment: 'Tài xế rất thân thiện, đi đúng đường, biết nhiều lối tắt!',
      createdAt: now.subtract(const Duration(days: 3)),
    ),
    DriverReview(
      id: 'r2',
      reviewerName: 'Lê Thị B',
      stars: 5,
      tags: ['Đúng giờ', 'Thân thiện'],
      comment: 'Đi nhanh, đến đúng giờ. Sẽ đặt lại lần sau.',
      createdAt: now.subtract(const Duration(days: 4)),
    ),
    DriverReview(
      id: 'r3',
      reviewerName: 'Trần Quốc C',
      stars: 4,
      tags: ['Xe sạch'],
      comment: 'Anh tài xế lịch sự, xe sạch sẽ thơm tho.',
      createdAt: now.subtract(const Duration(days: 7)),
    ),
  ];
}
