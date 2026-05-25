import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/trip.dart';

part 'selected_ride_type_provider.g.dart';

/// Ride variant chosen on RideOptionsScreen. Defaults to shared (cheapest).
@Riverpod(keepAlive: true)
class SelectedRideType extends _$SelectedRideType {
  @override
  TripType build() => TripType.shared;

  void set(TripType type) => state = type;
}
