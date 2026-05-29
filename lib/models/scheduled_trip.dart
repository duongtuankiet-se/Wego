import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'scheduled_trip.freezed.dart';

enum LuggageType { none, small, large }

enum RecurrenceType { once, daily, weekly }

enum SchedulePaymentMethod { cash, vnpay, momo }

/// Phase 5Q: which booking surface produced this trip.
///   * `freePoint` — user typed/picked their own pickup + dropoff and
///     the fare came from the Directions API per-km logic. Pool engine
///     is bypassed (matching solo passengers across arbitrary points
///     is too unreliable).
///   * `fixedRoute` — user chose one of the preset corridors, fare is
///     flat per the [RoutePreset] price table. This is the mode the
///     carpool pool engine runs on.
enum ScheduleMode { freePoint, fixedRoute }

enum ScheduledTripStatus {
  pending,
  // Phase 5R: a specific driver currently holds a 15s offer for this
  // trip. Status flips back to `pending` if they reject/timeout, or
  // forward to `driverAssigned` on accept.
  offered,
  matched,
  driverAssigned,
  started,
  completed,
  cancelled,
  expired,
  // Phase 5R: search_timeout_at elapsed with no driver accepting any
  // offer. Trip is effectively cancelled but kept distinct so analytics
  // can tell "no supply" from "user cancelled".
  noDriverFound,
}

/// Status name as stored in Mongo — uses snake_case for the multi-word
/// variant to stay aligned with the rest of the schema.
extension ScheduledTripStatusMongo on ScheduledTripStatus {
  String get mongoName => switch (this) {
    ScheduledTripStatus.driverAssigned => 'driver_assigned',
    ScheduledTripStatus.noDriverFound => 'no_driver_found',
    _ => name,
  };

  static ScheduledTripStatus fromMongo(String? raw) => switch (raw) {
    'driver_assigned' => ScheduledTripStatus.driverAssigned,
    'offered' => ScheduledTripStatus.offered,
    'matched' => ScheduledTripStatus.matched,
    'started' => ScheduledTripStatus.started,
    'completed' => ScheduledTripStatus.completed,
    'cancelled' => ScheduledTripStatus.cancelled,
    'expired' => ScheduledTripStatus.expired,
    'no_driver_found' => ScheduledTripStatus.noDriverFound,
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
    String? routeId,
    @Default(ScheduleMode.freePoint) ScheduleMode mode,
    // ── Phase 5R offer-engine bookkeeping ───────────────────────────
    @Default(<String>[]) List<String> offeredToDrivers,
    @Default(<String>[]) List<String> rejectedByDrivers,
    @Default(0) int offerAttempts,
    DateTime? searchTimeoutAt,
    // Phase 5R hotfix: per-offer marker on the trip itself so
    // acceptOffer can guard "this offer is for ME and still alive"
    // in a single atomic where-clause. Cleared on accept / reject /
    // expire / search-cancel.
    String? currentOfferedDriverId,
    DateTime? currentOfferExpiresAt,
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
    ScheduledTripStatus.offered => 'Có tài xế đang xem',
    ScheduledTripStatus.matched => 'Đã ghép tuyến',
    ScheduledTripStatus.driverAssigned => 'Tài xế đã nhận',
    ScheduledTripStatus.started => 'Đang chạy',
    ScheduledTripStatus.completed => 'Hoàn thành',
    ScheduledTripStatus.cancelled => 'Đã huỷ',
    ScheduledTripStatus.expired => 'Quá giờ',
    ScheduledTripStatus.noDriverFound => 'Không tìm được tài xế',
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
    routeId: (doc['route_id'] as ObjectId?)?.oid,
    mode: (doc['mode'] as String?) == 'fixed_route'
        ? ScheduleMode.fixedRoute
        : ScheduleMode.freePoint,
    offeredToDrivers: ((doc['offered_to_drivers'] as List?) ?? const [])
        .map((id) => (id as ObjectId).oid)
        .toList(growable: false),
    rejectedByDrivers: ((doc['rejected_by_drivers'] as List?) ?? const [])
        .map((id) => (id as ObjectId).oid)
        .toList(growable: false),
    offerAttempts: (doc['offer_attempts'] as num?)?.toInt() ?? 0,
    searchTimeoutAt: (doc['search_timeout_at'] as DateTime?)?.toLocal(),
    currentOfferedDriverId:
        (doc['current_offered_driver_id'] as ObjectId?)?.oid,
    currentOfferExpiresAt:
        (doc['current_offer_expires_at'] as DateTime?)?.toLocal(),
    cancelledAt: (doc['cancelled_at'] as DateTime?)?.toLocal(),
    cancelledBy: doc['cancelled_by'] as String?,
    cancelReason: doc['cancel_reason'] as String?,
    createdAt: (doc['created_at'] as DateTime).toLocal(),
    updatedAt: (doc['updated_at'] as DateTime).toLocal(),
  );
}
