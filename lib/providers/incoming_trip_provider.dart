import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/mock_places.dart';
import '../models/place.dart';
import '../models/trip.dart';
import 'driver_provider.dart';
import 'driver_status_provider.dart';
import 'mongo_provider.dart';

part 'incoming_trip_provider.freezed.dart';
part 'incoming_trip_provider.g.dart';

@freezed
class IncomingTripOffer with _$IncomingTripOffer {
  const factory IncomingTripOffer({
    /// Real trip ObjectId hex when sourced from Mongo polling, or a
    /// synthetic 'offer_…' id when mocked from generateOffer().
    required String offerId,
    String? tripId, // populated only for real Mongo offers
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
    @Default(<String>[]) List<String> sharedWith,
  }) = _IncomingTripOffer;
}

const _mockPassengers = [
  ('Nguyễn Văn A', 4.87, 53),
  ('Trần Thị B', 4.92, 128),
  ('Lê Minh C', 4.75, 22),
  ('Phạm Quỳnh D', 4.95, 211),
];

/// Synthetic offer for the dev-only matching test screen and for the
/// Phase 2 mock fallback when no live dispatch is available.
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

/// Polls Mongo every 4 seconds for trips assigned to the current driver
/// that have not started yet. Yields the first matching offer once, then
/// terminates so the UI can show the accept/decline modal.
@riverpod
Stream<IncomingTripOffer?> incomingTripPoll(Ref ref) async* {
  final driver = await ref.watch(currentDriverProvider.future);
  final status = ref.watch(currentDriverStatusProvider).valueOrNull;
  if (driver == null || status?.name != 'online') {
    yield null;
    return;
  }

  final mongo = ref.read(mongoServiceProvider);
  final trips = await mongo.trips();
  final users = await mongo.users();

  // First yield: null until we actually find an offer.
  yield null;

  while (true) {
    await Future.delayed(const Duration(seconds: 4));
    try {
      final pending = await trips.findOne(
        where
            .eq('driver_id', ObjectId.fromHexString(driver.id))
            .eq('status', 'accepted')
            .eq('started_at', null),
      );
      if (pending == null) continue;

      final passengerDoc = await users.findOne(
        where.eq('_id', pending['passenger_id'] as ObjectId),
      );
      final passengerName = (passengerDoc?['name'] as String?) ?? 'Hành khách';

      final pickup = Place(
        id: 'pk_${(pending['_id'] as ObjectId).oid}',
        name: pending['pickup_address'] as String? ?? 'Điểm đón',
        address: pending['pickup_address'] as String? ?? '',
        lat: (pending['pickup_lat'] as num).toDouble(),
        lng: (pending['pickup_lng'] as num).toDouble(),
      );
      final dropoff = Place(
        id: 'dr_${(pending['_id'] as ObjectId).oid}',
        name: pending['dropoff_address'] as String? ?? 'Điểm trả',
        address: pending['dropoff_address'] as String? ?? '',
        lat: (pending['dropoff_lat'] as num).toDouble(),
        lng: (pending['dropoff_lng'] as num).toDouble(),
      );

      final fromDriver =
          (driver.currentLat != null && driver.currentLng != null)
          ? _haversine(
              driver.currentLat!,
              driver.currentLng!,
              pickup.lat,
              pickup.lng,
            )
          : 0.0;

      final shared = ((pending['shared_with'] as List?) ?? const [])
          .map((e) => e is ObjectId ? e.oid : e.toString())
          .toList();

      yield IncomingTripOffer(
        offerId: 'live_${(pending['_id'] as ObjectId).oid}',
        tripId: (pending['_id'] as ObjectId).oid,
        passengerName: passengerName,
        passengerRating: 4.85,
        passengerTripCount: 0,
        pickup: pickup,
        dropoff: dropoff,
        distanceFromDriverKm: fromDriver,
        tripDistanceKm: (pending['distance_km'] as num?)?.toDouble() ?? 0,
        tripDurationMin: (pending['duration_min'] as num?)?.toInt() ?? 0,
        price: (pending['price'] as num?)?.toInt() ?? 0,
        type: TripType.values.byName((pending['type'] as String?) ?? 'private'),
        sharedWith: shared,
      );
      return; // pause polling; modal handles next action
    } catch (e) {
      developer.log('[poll] $e', name: 'incomingTripPoll');
      // Keep polling on transient errors.
    }
  }
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
