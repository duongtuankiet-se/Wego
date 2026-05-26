import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/place.dart';

part 'custom_pickup_provider.g.dart';

/// Optional pickup point overriding the user's GPS. Set when the user
/// taps "Đi đón khách" on the home and picks a friend's location on the
/// map. Cleared after a trip is booked (or by [clear]).
///
/// When `null`, ride flows default to [currentLocationProvider] for the
/// pickup — the original Phase 1A behaviour.
@Riverpod(keepAlive: true)
class CustomPickup extends _$CustomPickup {
  @override
  Place? build() => null;

  void set(Place place) => state = place;
  void clear() => state = null;
}
