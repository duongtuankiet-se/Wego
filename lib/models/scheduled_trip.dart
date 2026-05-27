import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'scheduled_trip.freezed.dart';

enum LuggageType { none, small, large }

enum RecurrenceType { once, daily, weekly }

enum SchedulePaymentMethod { cash, vnpay, momo }

enum ScheduledTripStatus {
  pending,
  matched,
  driverAssigned,
  started,
  completed,
  cancelled,
  expired,
}

/// Status name as stored in Mongo — uses snake_case for the multi-word
/// variant to stay aligned with the rest of the schema.
extension ScheduledTripStatusMongo on ScheduledTripStatus {
  String get mongoName => switch (this) {
    ScheduledTripStatus.driverAssigned => 'driver_assigned',
    _ => name,
  };

  static ScheduledTripStatus fromMongo(String? raw) => switch (raw) {
    'driver_assigned' => ScheduledTripStatus.driverAssigned,
    'matched' => ScheduledTripStatus.matched,
    'started' => ScheduledTripStatus.started,
    'completed' => ScheduledTripStatus.completed,
    'cancelled' => ScheduledTripStatus.cancelled,
    'expired' => ScheduledTripStatus.expired,
    _ => ScheduledTripStatus.pending,
  };
}

@freezed
class ScheduledTripLocation with _$ScheduledTripLocation {
  const factory ScheduledTripLocation({
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) = _ScheduledTripLocation;

  factory ScheduledTripLocation.fromMongo(Map<String, dynamic> j) =>
      ScheduledTripLocation(
        name: j['name'] as String,
        address: j['address'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

@freezed
class ScheduledTrip with _$ScheduledTrip {
  const ScheduledTrip._();

  const factory ScheduledTrip({
    required String id,
    required String passengerId,
    required String tripCode,
    required ScheduledTripLocation pickup,
    required ScheduledTripLocation dropoff,
    @Default(<ScheduledTripLocation>[]) List<ScheduledTripLocation> waypoints,
    required DateTime scheduledAt,
    @Default(15) int flexibleWindowMin,
    @Default(1) int passengerCount,
    @Default(LuggageType.none) LuggageType luggage,
    String? note,
    @Default('shared') String rideType,
    @Default(true) bool allowPooling,
    @Default(RecurrenceType.once) RecurrenceType recurrence,
    DateTime? recurrenceEndDate,
    @Default(SchedulePaymentMethod.cash) SchedulePaymentMethod paymentMethod,
    String? promoCode,
    required double estimatedDistanceKm,
    required int estimatedDurationMin,
    required int baseFare,
    @Default(0) int discount,
    required int estimatedFare,
    @Default(ScheduledTripStatus.pending) ScheduledTripStatus status,
    String? driverId,
    String? poolId,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancelReason,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ScheduledTrip;

  /// "X phút nữa" / "Y giờ Z phút nữa" / "N ngày H giờ nữa".
  String get countdownText {
    final diff = scheduledAt.difference(DateTime.now());
    if (diff.isNegative) return 'Đã quá giờ';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút nữa';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return m == 0 ? '$h giờ nữa' : '$h giờ $m phút nữa';
    }
    final d = diff.inDays;
    final h = diff.inHours % 24;
    return h == 0 ? '$d ngày nữa' : '$d ngày $h giờ nữa';
  }

  /// "Thứ Hai, 28/05 • 08:00".
  String get scheduledAtVN {
    const weekdays = ['Hai', 'Ba', 'Tư', 'Năm', 'Sáu', 'Bảy', 'CN'];
    final wd = weekdays[scheduledAt.weekday - 1];
    final dd = scheduledAt.day.toString().padLeft(2, '0');
    final mm = scheduledAt.month.toString().padLeft(2, '0');
    final hh = scheduledAt.hour.toString().padLeft(2, '0');
    final min = scheduledAt.minute.toString().padLeft(2, '0');
    final prefix = wd == 'CN' ? 'CN' : 'Thứ $wd';
    return '$prefix, $dd/$mm • $hh:$min';
  }

  String get statusLabel => switch (status) {
    ScheduledTripStatus.pending => 'Đang tìm tài xế',
    ScheduledTripStatus.matched => 'Đã ghép tuyến',
    ScheduledTripStatus.driverAssigned => 'Tài xế đã nhận',
    ScheduledTripStatus.started => 'Đang chạy',
    ScheduledTripStatus.completed => 'Hoàn thành',
    ScheduledTripStatus.cancelled => 'Đã huỷ',
    ScheduledTripStatus.expired => 'Quá giờ',
  };

  static ScheduledTrip fromMongo(Map<String, dynamic> doc) => ScheduledTrip(
    id: (doc['_id'] as ObjectId).oid,
    passengerId: (doc['passenger_id'] as ObjectId).oid,
    tripCode: doc['trip_code'] as String,
    pickup: ScheduledTripLocation.fromMongo(
      (doc['pickup'] as Map).cast<String, dynamic>(),
    ),
    dropoff: ScheduledTripLocation.fromMongo(
      (doc['dropoff'] as Map).cast<String, dynamic>(),
    ),
    waypoints: ((doc['waypoints'] as List?) ?? const [])
        .map(
          (w) => ScheduledTripLocation.fromMongo(
            (w as Map).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false),
    scheduledAt: (doc['scheduled_at'] as DateTime).toLocal(),
    flexibleWindowMin: (doc['flexible_window_min'] as num?)?.toInt() ?? 15,
    passengerCount: (doc['passenger_count'] as num?)?.toInt() ?? 1,
    luggage: LuggageType.values.byName((doc['luggage'] as String?) ?? 'none'),
    note: doc['note'] as String?,
    rideType: (doc['ride_type'] as String?) ?? 'shared',
    allowPooling: (doc['allow_pooling'] as bool?) ?? true,
    recurrence: RecurrenceType.values.byName(
      (doc['recurrence'] as String?) ?? 'once',
    ),
    recurrenceEndDate: (doc['recurrence_end_date'] as DateTime?)?.toLocal(),
    paymentMethod: SchedulePaymentMethod.values.byName(
      (doc['payment_method'] as String?) ?? 'cash',
    ),
    promoCode: doc['promo_code'] as String?,
    estimatedDistanceKm: (doc['estimated_distance_km'] as num).toDouble(),
    estimatedDurationMin: (doc['estimated_duration_min'] as num).toInt(),
    baseFare: (doc['base_fare'] as num).toInt(),
    discount: (doc['discount'] as num?)?.toInt() ?? 0,
    estimatedFare: (doc['estimated_fare'] as num).toInt(),
    status: ScheduledTripStatusMongo.fromMongo(doc['status'] as String?),
    driverId: (doc['driver_id'] as ObjectId?)?.oid,
    poolId: (doc['pool_id'] as ObjectId?)?.oid,
    cancelledAt: (doc['cancelled_at'] as DateTime?)?.toLocal(),
    cancelledBy: doc['cancelled_by'] as String?,
    cancelReason: doc['cancel_reason'] as String?,
    createdAt: (doc['created_at'] as DateTime).toLocal(),
    updatedAt: (doc['updated_at'] as DateTime).toLocal(),
  );
}
