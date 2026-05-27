import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/theme/app_colors.dart';

enum NotificationType {
  scheduledReminder,
  driverAssigned,
  tripCompleted,
  promo,
  system,
  payment,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// When non-null, tapping the item navigates to this `context.push` route.
  final String? actionRoute;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
  });

  IconData get icon => switch (type) {
    NotificationType.scheduledReminder => PhosphorIconsFill.clock,
    NotificationType.driverAssigned => PhosphorIconsFill.carProfile,
    NotificationType.tripCompleted => PhosphorIconsFill.checkCircle,
    NotificationType.promo => PhosphorIconsFill.gift,
    NotificationType.system => PhosphorIconsFill.bell,
    NotificationType.payment => PhosphorIconsFill.wallet,
  };

  Color get iconColor => switch (type) {
    NotificationType.scheduledReminder => AppColors.warning,
    NotificationType.driverAssigned => AppColors.primary500,
    NotificationType.tripCompleted => AppColors.success,
    NotificationType.promo => AppColors.sharedAccent,
    NotificationType.system => AppColors.ink500,
    NotificationType.payment => const Color(0xFF8B5CF6),
  };

  /// Human-readable Vietnamese relative time: "Vừa xong", "5 phút trước",
  /// "3 giờ trước", "2 ngày trước", or "dd/MM" for anything older.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}';
  }

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    actionRoute: actionRoute,
  );
}
