import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/mock_places.dart';
import '../models/place.dart';
import '../models/trip.dart';

part 'incoming_trip_provider.freezed.dart';
part 'incoming_trip_provider.g.dart';

@freezed
class IncomingTripOffer with _$IncomingTripOffer {
  const factory IncomingTripOffer({
    required String offerId,
    required String passengerName,
    required double passengerRating,
    required int passengerTripCount,
    required Place pickup,
    required Place dropoff,
    required double distanceFromDriverKm,
    required double tripDistanceKm,
    required int tripDurationMin,
    required int price,
    required TripType type,
  }) = _IncomingTripOffer;
}

const _mockPassengers = [
  ('Nguyễn Văn A', 4.87, 53),
  ('Trần Thị B', 4.92, 128),
  ('Lê Minh C', 4.75, 22),
  ('Phạm Quỳnh D', 4.95, 211),
];

/// Generates a fake trip offer using two random places from the mock list.
/// Pure function — call directly, no provider wrapping needed.
IncomingTripOffer generateOffer({
  required double driverLat,
  required double driverLng,
}) {
  final rng = math.Random();
  final pickup = kDanangPlaces[rng.nextInt(kDanangPlaces.length)];
  Place dropoff;
  do {
    dropoff = kDanangPlaces[rng.nextInt(kDanangPlaces.length)];
  } while (dropoff.id == pickup.id);
  final pax = _mockPassengers[rng.nextInt(_mockPassengers.length)];

  final tripDistance = _haversine(
    pickup.lat,
    pickup.lng,
    dropoff.lat,
    dropoff.lng,
  );
  final fromDriver = _haversine(driverLat, driverLng, pickup.lat, pickup.lng);
  final duration = (tripDistance / 25 * 60).round().clamp(5, 90);
  final price = (((tripDistance * 12000 + 8000) / 1000).round()) * 1000;
  final type = rng.nextBool() ? TripType.shared : TripType.private;

  return IncomingTripOffer(
    offerId: 'offer_${DateTime.now().millisecondsSinceEpoch}',
    passengerName: pax.$1,
    passengerRating: pax.$2,
    passengerTripCount: pax.$3,
    pickup: pickup,
    dropoff: dropoff,
    distanceFromDriverKm: fromDriver,
    tripDistanceKm: tripDistance,
    tripDurationMin: duration,
    price: price,
    type: type,
  );
}

/// Holds the most recent dispatched offer for the Home → Modal handoff.
@Riverpod(keepAlive: true)
class ActiveOffer extends _$ActiveOffer {
  @override
  IncomingTripOffer? build() => null;

  void set(IncomingTripOffer offer) => state = offer;
  void clear() => state = null;
}

double _haversine(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
