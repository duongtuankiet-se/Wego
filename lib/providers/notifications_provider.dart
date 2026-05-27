import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/mock_notifications.dart';
import '../models/notification_item.dart';

part 'notifications_provider.g.dart';

@Riverpod(keepAlive: true)
class Notifications extends _$Notifications {
  @override
  List<NotificationItem> build() => generateMockNotifications();

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllAsRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
  }

  void clearAll() {
    state = const [];
  }
}

/// Derived: number of unread items. Exposed as a separate provider so
/// the bell badge can `ref.watch` it cheaply without rebuilding the
/// whole list.
@riverpod
int unreadNotificationCount(Ref ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
}
