import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/place.dart';

part 'selected_destination_provider.g.dart';

/// Currently selected dropoff destination. Null until user picks one
/// from search or shortcuts. Pickup is always derived from
/// [currentLocationProvider] in Phase 1A.
@Riverpod(keepAlive: true)
class SelectedDestination extends _$SelectedDestination {
  @override
  Place? build() => null;

  void set(Place place) => state = place;
  void clear() => state = null;
}
