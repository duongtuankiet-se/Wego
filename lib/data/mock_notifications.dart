import '../models/notification_item.dart';

/// Mock notifications shown on first launch of the notifications screen.
/// Timestamps are computed lazily so the "Vừa xong / X phút trước" labels
/// stay fresh between app sessions during the demo.
List<NotificationItem> generateMockNotifications() {
  final now = DateTime.now();
  return [
    NotificationItem(
      id: 'noti_001',
      type: NotificationType.scheduledReminder,
      title: 'Chuyến đi sắp khởi hành',
      body: 'Chuyến WG-20260528-001 sẽ khởi hành lúc 08:00 sáng mai. '
          'Tài xế sẽ đến trong 1 giờ tới.',
      createdAt: now.subtract(const Duration(minutes: 5)),
    ),
    NotificationItem(
      id: 'noti_002',
      type: NotificationType.promo,
      title: 'Ưu đãi mới: CARPOOL30',
      body: 'Giảm 30% cho chuyến xe ghép, tối đa 30.000đ. '
          'Áp dụng đến hết 31/05/2026.',
      createdAt: now.subtract(const Duration(hours: 2)),
      actionRoute: '/passenger/promo',
    ),
    NotificationItem(
      id: 'noti_003',
      type: NotificationType.driverAssigned,
      title: 'Đã có tài xế nhận chuyến',
      body: 'Anh Trần Quang Minh (43A-128.66) sẽ đón bạn lúc 08:00. '
          'Đánh giá 4.9 sao.',
      createdAt: now.subtract(const Duration(hours: 4)),
      isRead: true,
    ),
    NotificationItem(
      id: 'noti_004',
      type: NotificationType.tripCompleted,
      title: 'Chuyến đi hoàn tất',
      body: 'Cảm ơn bạn đã sử dụng WeGo. Hãy đánh giá tài xế để '
          'cải thiện chất lượng dịch vụ.',
      createdAt: now.subtract(const Duration(days: 1)),
      isRead: true,
      actionRoute: '/passenger/activity',
    ),
    NotificationItem(
      id: 'noti_005',
      type: NotificationType.system,
      title: 'Cập nhật chính sách',
      body: 'WeGo đã cập nhật chính sách bảo mật mới. '
          'Vui lòng xem chi tiết.',
      createdAt: now.subtract(const Duration(days: 2)),
      isRead: true,
    ),
    NotificationItem(
      id: 'noti_006',
      type: NotificationType.payment,
      title: 'Thanh toán thành công',
      body: 'Chuyến WG-20260526-003 đã thanh toán 45.000đ qua MoMo.',
      createdAt: now.subtract(const Duration(days: 3)),
      isRead: true,
    ),
    NotificationItem(
      id: 'noti_007',
      type: NotificationType.promo,
      title: 'Tích điểm thành viên',
      body: 'Bạn đã tích được 250 điểm WeGo. Đổi quà ngay tại tab Ưu đãi.',
      createdAt: now.subtract(const Duration(days: 5)),
      isRead: true,
      actionRoute: '/passenger/promo',
    ),
  ];
}
