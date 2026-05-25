import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/trip.dart';

part 'current_trip_provider.freezed.dart';
part 'current_trip_provider.g.dart';

/// Snapshot of the driver assigned to the active trip. Mock data —
/// not persisted to MongoDB beyond the driver doc itself.
@freezed
class ActiveDriver with _$ActiveDriver {
  const factory ActiveDriver({
    required String id,
    required String name,
    required String phone,
    required String vehicleModel,
    required String vehicleColor,
    required String vehiclePlate,
    required double rating,
    required int totalTrips,
    required double currentLat,
    required double currentLng,
  }) = _ActiveDriver;
}

@freezed
class ActiveTrip with _$ActiveTrip {
  const factory ActiveTrip({
    required String tripId,
    required Trip trip,
    required ActiveDriver driver,
  }) = _ActiveTrip;
}

/// Currently in-progress trip (matching → completed). Set by TripService
/// when a booking is confirmed. Cleared when user returns home.
@Riverpod(keepAlive: true)
class CurrentTrip extends _$CurrentTrip {
  @override
  ActiveTrip? build() => null;

  void set(ActiveTrip t) => state = t;
  void clear() => state = null;
  void updateStatus(TripStatus status) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(trip: s.trip.copyWith(status: status));
  }
}
