import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'trip_pool.freezed.dart';

enum TripPoolStatus {
  collecting,
  confirmed,
  assigned,
  started,
  completed,
  cancelledNoPool,
  cancelledNoDriver,
}

/// Snake-case mapping used in Mongo so the database is human-readable.
extension TripPoolStatusMongo on TripPoolStatus {
  String get mongoName => switch (this) {
    TripPoolStatus.cancelledNoPool => 'cancelled_no_pool',
    TripPoolStatus.cancelledNoDriver => 'cancelled_no_driver',
    _ => name,
  };

  static TripPoolStatus fromMongo(String? raw) => switch (raw) {
    'confirmed' => TripPoolStatus.confirmed,
    'assigned' => TripPoolStatus.assigned,
    'started' => TripPoolStatus.started,
    'completed' => TripPoolStatus.completed,
    'cancelled_no_pool' => TripPoolStatus.cancelledNoPool,
    'cancelled_no_driver' => TripPoolStatus.cancelledNoDriver,
    _ => TripPoolStatus.collecting,
  };
}

extension TripPoolStatusX on TripPoolStatus {
  String get label => switch (this) {
    TripPoolStatus.collecting => 'Đang gom khách',
    TripPoolStatus.confirmed => 'Đã đủ khách, đợi tài xế',
    TripPoolStatus.assigned => 'Tài xế đã nhận',
    TripPoolStatus.started => 'Đang trên đường',
    TripPoolStatus.completed => 'Hoàn tất',
    TripPoolStatus.cancelledNoPool => 'Đã hủy — không đủ khách',
    TripPoolStatus.cancelledNoDriver => 'Đã hủy — không có tài xế',
  };

  bool get isCancelled =>
      this == TripPoolStatus.cancelledNoPool ||
      this == TripPoolStatus.cancelledNoDriver;

  bool get isActive =>
      this == TripPoolStatus.collecting ||
      this == TripPoolStatus.confirmed ||
      this == TripPoolStatus.assigned ||
      this == TripPoolStatus.started;
}

@freezed
class TripPool with _$TripPool {
  const TripPool._();

  const factory TripPool({
    required String id,
    required String poolCode,
    required String pickupCity,
    required String pickupDistrict,
    required String dropoffCity,
    required String dropoffDistrict,
    required double dropoffLatMean,
    required double dropoffLngMean,
    required DateTime scheduledAt,
    @Default(30) int timeWindowMin,
    required DateTime earliestAt,
    required DateTime latestAt,
    required int vehicleSeats,
    required int minThreshold,
    required int currentPassengers,
    @Default(<String>[]) List<String> scheduledTripIds,
    @Default(TripPoolStatus.collecting) TripPoolStatus status,
    String? driverId,
    String? driverVehicleId,
    required DateTime cancelDeadline,
    required int estimatedTotalFare,
    required int estimatedFarePerPax,
    DateTime? cancelledAt,
    String? cancelledReason,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TripPool;

  bool get isThresholdMet => currentPassengers >= minThreshold;
  bool get hasAvailableSeats => currentPassengers < vehicleSeats;
  int get availableSeats => vehicleSeats - currentPassengers;

  /// Progress 0-1 toward [minThreshold] (capped at 1.0 once met).
  double get progressToThreshold =>
      isThresholdMet ? 1.0 : currentPassengers / minThreshold;

  String get progressLabel => '$currentPassengers/$minThreshold khách';

  String get routeLabel => '$pickupCity → $dropoffDistrict, $dropoffCity';

  String get scheduledAtVN {
    final dd = scheduledAt.day.toString().padLeft(2, '0');
    final mm = scheduledAt.month.toString().padLeft(2, '0');
    final hh = scheduledAt.hour.toString().padLeft(2, '0');
    final mn = scheduledAt.minute.toString().padLeft(2, '0');
    return '$dd/$mm • $hh:$mn (±$timeWindowMin phút)';
  }

  static TripPool fromMongo(Map<String, dynamic> doc) => TripPool(
    id: (doc['_id'] as ObjectId).oid,
    poolCode: doc['pool_code'] as String,
    pickupCity: doc['pickup_city'] as String,
    pickupDistrict: doc['pickup_district'] as String,
    dropoffCity: doc['dropoff_city'] as String,
    dropoffDistrict: doc['dropoff_district'] as String,
    dropoffLatMean: (doc['dropoff_lat_mean'] as num).toDouble(),
    dropoffLngMean: (doc['dropoff_lng_mean'] as num).toDouble(),
    scheduledAt: (doc['scheduled_at'] as DateTime).toLocal(),
    timeWindowMin: (doc['time_window_min'] as num?)?.toInt() ?? 30,
    earliestAt: (doc['earliest_at'] as DateTime).toLocal(),
    latestAt: (doc['latest_at'] as DateTime).toLocal(),
    vehicleSeats: (doc['vehicle_seats'] as num).toInt(),
    minThreshold: (doc['min_threshold'] as num).toInt(),
    currentPassengers: (doc['current_passengers'] as num?)?.toInt() ?? 0,
    scheduledTripIds: ((doc['scheduled_trip_ids'] as List?) ?? const [])
        .map((id) => (id as ObjectId).oid)
        .toList(growable: false),
    status: TripPoolStatusMongo.fromMongo(doc['status'] as String?),
    driverId: (doc['driver_id'] as ObjectId?)?.oid,
    driverVehicleId: (doc['driver_vehicle_id'] as ObjectId?)?.oid,
    cancelDeadline: (doc['cancel_deadline'] as DateTime).toLocal(),
    estimatedTotalFare: (doc['estimated_total_fare'] as num).toInt(),
    estimatedFarePerPax: (doc['estimated_fare_per_pax'] as num).toInt(),
    cancelledAt: (doc['cancelled_at'] as DateTime?)?.toLocal(),
    cancelledReason: doc['cancelled_reason'] as String?,
    createdAt: (doc['created_at'] as DateTime).toLocal(),
    updatedAt: (doc['updated_at'] as DateTime).toLocal(),
  );
}
