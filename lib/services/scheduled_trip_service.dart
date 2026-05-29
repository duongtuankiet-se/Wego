import 'dart:developer' as developer;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where, modify;

import '../core/db/mongo_service.dart';
import '../data/mock_promos.dart';
import '../models/route.dart';
import '../models/scheduled_trip.dart';
import 'trip_pool_service.dart';

/// Result of [ScheduledTripService.validatePromo].
class PromoValidation {
  final bool isValid;
  final String message;
  final int discount;

  const PromoValidation({
    required this.isValid,
    required this.message,
    required this.discount,
  });
}

class ScheduledTripService {
  ScheduledTripService(this._mongo);
  final MongoService _mongo;

  // ── Fare constants (match RideOptionsScreen for consistency) ──────
  static const int _kOpenFare = 8000;
  static const int _kPerKm = 12000;
  static const double _kShareDiscount = 0.62;
  static const double _kGroupDiscountPercent = 0.15; // 15% off when 3+ pax

  // ─────────────────────────────────────────────────────────────────
  // Trip code
  // ─────────────────────────────────────────────────────────────────

  /// `WG-YYYYMMDD-NNN`. Counts existing codes for the same date and
  /// increments — Phase 5I lives in one process at a time, so a Mongo
  /// transaction would be overkill.
  Future<String> generateTripCode(DateTime scheduledAt) async {
    final dateStr =
        '${scheduledAt.year}'
        '${scheduledAt.month.toString().padLeft(2, '0')}'
        '${scheduledAt.day.toString().padLeft(2, '0')}';

    final col = await _mongo.scheduledTrips();
    final count = await col.count(
      where.raw(<String, dynamic>{
        'trip_code': {r'$regex': '^WG-$dateStr-'},
      }),
    );
    final seq = (count + 1).toString().padLeft(3, '0');
    return 'WG-$dateStr-$seq';
  }

  // ─────────────────────────────────────────────────────────────────
  // Create
  // ─────────────────────────────────────────────────────────────────

  Future<ScheduledTrip> createScheduledTrip({
    required String passengerId,
    required ScheduledTripLocation pickup,
    required ScheduledTripLocation dropoff,
    List<ScheduledTripLocation> waypoints = const [],
    required DateTime scheduledAt,
    int flexibleWindowMin = 15,
    int passengerCount = 1,
    LuggageType luggage = LuggageType.none,
    String? note,
    String rideType = 'shared',
    bool allowPooling = true,
    RecurrenceType recurrence = RecurrenceType.once,
    DateTime? recurrenceEndDate,
    SchedulePaymentMethod paymentMethod = SchedulePaymentMethod.cash,
    String? promoCode,
    required double estimatedDistanceKm,
    required int estimatedDurationMin,
    // Phase 5Q dual-mode params:
    ScheduleMode mode = ScheduleMode.freePoint,
    RoutePreset? route,
  }) async {
    final col = await _mongo.scheduledTrips();
    final tripCode = await generateTripCode(scheduledAt);

    // Phase 5Q: flat fare for fixed-route bookings, per-km for free
    // point. Group discount (≥3 pax) + promo applied on top of either.
    final int baseFare;
    if (mode == ScheduleMode.fixedRoute && route != null) {
      baseFare = rideType == 'shared'
          ? route.baseFareCarpool * passengerCount
          : route.baseFarePrivate;
    } else {
      baseFare = calcBaseFare(
        distanceKm: estimatedDistanceKm,
        rideType: rideType,
      );
    }
    final discount = _calcDiscount(
      baseFare: baseFare,
      passengerCount: passengerCount,
      promoCode: promoCode,
    );
    final estimatedFare = baseFare - discount;

    final now = DateTime.now().toUtc();
    final tripId = ObjectId();

    final doc = <String, dynamic>{
      '_id': tripId,
      'passenger_id': ObjectId.fromHexString(passengerId),
      'trip_code': tripCode,
      'pickup': _locationToMongo(pickup),
      'dropoff': _locationToMongo(dropoff),
      'waypoints': waypoints.map(_locationToMongo).toList(),
      'scheduled_at': scheduledAt.toUtc(),
      'flexible_window_min': flexibleWindowMin,
      'passenger_count': passengerCount,
      'luggage': luggage.name,
      'note': note,
      'ride_type': rideType,
      'allow_pooling': allowPooling,
      'recurrence': recurrence.name,
      'recurrence_end_date': recurrenceEndDate?.toUtc(),
      'payment_method': paymentMethod.name,
      'promo_code': promoCode,
      'estimated_distance_km': estimatedDistanceKm,
      'estimated_duration_min': estimatedDurationMin,
      'base_fare': baseFare,
      'discount': discount,
      'estimated_fare': estimatedFare,
      'status': ScheduledTripStatus.pending.mongoName,
      'driver_id': null,
      'mode': mode == ScheduleMode.fixedRoute ? 'fixed_route' : 'free_point',
      'route_id': route == null ? null : ObjectId.fromHexString(route.id),
      // Phase 5R offer-engine bookkeeping. Pool trips set these too but
      // the search job ignores them (pool flow runs the assignment).
      'offered_to_drivers': <ObjectId>[],
      'rejected_by_drivers': <ObjectId>[],
      'offer_attempts': 0,
      // Hotfix: was hardcoded `now + 10 min`, which immediately
      // expired trips scheduled hours/days out the moment the
      // search-job tick caught them — flipping them to noDriverFound
      // even though the customer's pickup hadn't even started its
      // search window. Bound to scheduledAt, floored at "now + 30 min"
      // so short-lead bookings still get a real search window.
      'search_timeout_at': _searchTimeoutFor(scheduledAt.toUtc(), now),
      'cancelled_at': null,
      'cancelled_by': null,
      'cancel_reason': null,
      'created_at': now,
      'updated_at': now,
    };

    await col.insertOne(doc);
    developer.log('[sched] created $tripCode (mode=${mode.name})', name: 'sched');

    var trip = ScheduledTrip.fromMongo(doc);

    // Phase 5Q: pool engine is gated to fixed-route bookings only —
    // matching solo passengers across arbitrary points is too noisy
    // to be useful. Free-point trips always go out as solo bookings.
    final canPool =
        allowPooling && mode == ScheduleMode.fixedRoute && route != null;
    if (canPool) {
      try {
        final pool = await TripPoolService(_mongo).findOrCreatePool(trip);
        developer.log('[sched] pool ${pool.poolCode}', name: 'sched');
        final updated = await col.findOne(where.eq('_id', tripId));
        if (updated != null) trip = ScheduledTrip.fromMongo(updated);
      } catch (e, st) {
        developer.log(
          '[sched] pool assignment failed for $tripCode: $e',
          name: 'sched',
          error: e,
          stackTrace: st,
        );
      }
    }
    return trip;
  }

  Map<String, dynamic> _locationToMongo(ScheduledTripLocation l) => {
    'name': l.name,
    'address': l.address,
    'lat': l.lat,
    'lng': l.lng,
  };

  // ─────────────────────────────────────────────────────────────────
  // Fare math (mirrors RideOptionsScreen constants)
  // ─────────────────────────────────────────────────────────────────

  /// Public so the form provider can preview a fare without a DB write.
  int calcBaseFare({required double distanceKm, required String rideType}) {
    final multiplier = rideType == 'shared' ? _kShareDiscount : 1.0;
    final raw = (distanceKm * _kPerKm + _kOpenFare) * multiplier;
    return (raw / 1000).round() * 1000;
  }

  int _calcDiscount({
    required int baseFare,
    required int passengerCount,
    String? promoCode,
  }) {
    var total = 0;
    if (passengerCount >= 3) {
      total += (baseFare * _kGroupDiscountPercent).round();
    }
    if (promoCode != null && promoCode.isNotEmpty) {
      final p = _findPromo(promoCode);
      if (p != null && baseFare >= p.minOrderVnd) {
        total += _promoAmount(p, baseFare);
      }
    }
    final maxDiscount = baseFare - 10000;
    return total.clamp(0, maxDiscount < 0 ? 0 : maxDiscount);
  }

  /// Public discount preview used by the form provider.
  int previewDiscount({
    required int baseFare,
    required int passengerCount,
    String? promoCode,
  }) => _calcDiscount(
    baseFare: baseFare,
    passengerCount: passengerCount,
    promoCode: promoCode,
  );

  PromoVoucher? _findPromo(String code) {
    final upper = code.toUpperCase();
    for (final p in generateMockPromos()) {
      if (p.code == upper) return p;
    }
    return null;
  }

  int _promoAmount(PromoVoucher p, int baseFare) {
    if (p.discountVnd != null) return p.discountVnd!;
    if (p.discountPercent > 0) {
      var amt = (baseFare * p.discountPercent / 100).round();
      if (p.maxDiscountVnd != null && amt > p.maxDiscountVnd!) {
        amt = p.maxDiscountVnd!;
      }
      return amt;
    }
    return 0;
  }

  /// Validate a promo code against a base fare. Used by the form when
  /// the user taps "Áp dụng".
  PromoValidation validatePromo({required String code, required int baseFare}) {
    final promo = _findPromo(code);
    if (promo == null) {
      return const PromoValidation(
        isValid: false,
        message: 'Mã không tồn tại',
        discount: 0,
      );
    }
    if (baseFare < promo.minOrderVnd) {
      final minK = (promo.minOrderVnd / 1000).round();
      return PromoValidation(
        isValid: false,
        message: 'Đơn tối thiểu ${minK}k để dùng mã',
        discount: 0,
      );
    }
    final amt = _promoAmount(promo, baseFare);
    if (amt == 0) {
      return PromoValidation(
        isValid: false,
        message: '"${promo.title}" không áp dụng cho chuyến này',
        discount: 0,
      );
    }
    return PromoValidation(
      isValid: true,
      message: 'Đã áp dụng "${promo.title}"',
      discount: amt,
    );
  }

  /// Hotfix helper: search ends 5 min before the scheduled pickup so
  /// the customer isn't left in limbo at departure, but never sooner
  /// than 30 min from now so a "book in 35 min" trip still gets a
  /// real search runway.
  static DateTime _searchTimeoutFor(DateTime scheduledAtUtc, DateTime now) {
    final preferred = scheduledAtUtc.subtract(const Duration(minutes: 5));
    final floor = now.add(const Duration(minutes: 30));
    return preferred.isBefore(floor) ? floor : preferred;
  }

  // ─────────────────────────────────────────────────────────────────
  // Queries
  // ─────────────────────────────────────────────────────────────────

  Future<List<ScheduledTrip>> getUpcomingTrips(String passengerId) async {
    final col = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();

    final cursor = col.find(
      where
          .raw(<String, dynamic>{
            'passenger_id': ObjectId.fromHexString(passengerId),
            'scheduled_at': {r'$gte': now},
            'status': {
              r'$nin': ['cancelled', 'expired', 'completed'],
            },
          })
          .sortBy('scheduled_at'),
    );
    return [await for (final doc in cursor) ScheduledTrip.fromMongo(doc)];
  }

  Future<List<ScheduledTrip>> getPastTrips(
    String passengerId, {
    int limit = 20,
  }) async {
    final col = await _mongo.scheduledTrips();
    final cursor = col.find(
      where
          .raw(<String, dynamic>{
            'passenger_id': ObjectId.fromHexString(passengerId),
            'status': {
              r'$in': ['completed', 'cancelled', 'expired'],
            },
          })
          .sortBy('scheduled_at', descending: true)
          .limit(limit),
    );
    return [await for (final doc in cursor) ScheduledTrip.fromMongo(doc)];
  }

  Future<ScheduledTrip?> getById(String tripId) async {
    final col = await _mongo.scheduledTrips();
    final doc = await col.findOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
    );
    return doc == null ? null : ScheduledTrip.fromMongo(doc);
  }

  /// All pending free-point scheduled trips within [limitHours] from
  /// now. Driver home uses this to show "Chuyến sắp tới" the driver can
  /// accept from a list. Phase 5R: pool trips (`pool_id != null`) are
  /// skipped since the pool flow runs their assignment via
  /// [TripPoolService.driverAcceptPool] on `DriverPoolsScreen`.
  ///
  /// Hotfix: also surface trips that the search loop briefly flipped
  /// to `offered` but whose offer holder has lapsed (or is this same
  /// driver). Without this, customer-just-booked trips disappear from
  /// the list the moment the search-job tick fires the first offer.
  Future<List<ScheduledTrip>> getUpcomingTripsForDriver({
    String? driverId,
    int limitHours = 48,
  }) async {
    final col = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();
    final until = now.add(Duration(hours: limitHours));
    final driverObjId =
        driverId == null ? null : ObjectId.fromHexString(driverId);

    final cursor = col.find(
      where
          .raw(<String, dynamic>{
            r'$or': <Map<String, dynamic>>[
              {'status': 'pending'},
              {
                'status': 'offered',
                r'$or': <Map<String, dynamic>>[
                  // Offer lapsed but the search job hasn't swept it
                  // back to pending yet — treat as available.
                  {
                    'current_offer_expires_at': {r'$lte': now},
                  },
                  // Offer is for this driver themselves — they can
                  // pop it via the list as a backup to the popup.
                  if (driverObjId != null)
                    {'current_offered_driver_id': driverObjId},
                ],
              },
            ],
            'pool_id': null,
            'driver_id': null,
            'scheduled_at': {r'$gte': now, r'$lte': until},
          })
          .sortBy('scheduled_at')
          .limit(50),
    );
    return [await for (final doc in cursor) ScheduledTrip.fromMongo(doc)];
  }

  // ─────────────────────────────────────────────────────────────────
  // Mutations
  // ─────────────────────────────────────────────────────────────────

  /// Hotfix: driver-home list accept. Two paths can land here:
  ///   * trip is still `pending` — straight accept;
  ///   * trip flipped to `offered` because the search loop made a
  ///     transient offer, but the holder lapsed OR is this same driver.
  ///
  /// The old "status='pending' only" guard meant the moment search-job
  /// fired its first offer (any driver), the list-accept failed with a
  /// misleading "tài xế khác đã nhận" toast even though nobody had
  /// actually accepted. Atomic where-clause now allows either valid
  /// case; failures get diagnosed with [_diagnoseListAcceptFailure].
  Future<({bool success, String? reason})> acceptScheduledTrip({
    required String tripId,
    required String driverId,
  }) async {
    final col = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();
    final tripObjId = ObjectId.fromHexString(tripId);
    final driverObjId = ObjectId.fromHexString(driverId);

    final res = await col.updateOne(
      where.raw(<String, dynamic>{
        '_id': tripObjId,
        'driver_id': null,
        r'$or': <Map<String, dynamic>>[
          {'status': 'pending'},
          {
            'status': 'offered',
            r'$or': <Map<String, dynamic>>[
              {
                'current_offer_expires_at': {r'$lte': now},
              },
              {'current_offered_driver_id': driverObjId},
            ],
          },
        ],
      }),
      modify
          .set('driver_id', driverObjId)
          .set('status', ScheduledTripStatus.driverAssigned.mongoName)
          .set('current_offered_driver_id', null)
          .set('current_offer_expires_at', null)
          .set('updated_at', now),
    );

    if (res.isSuccess && res.nModified > 0) {
      // Also clear the driver-side offer marker if this driver had a
      // pending popup for the same trip — keeps the two collections
      // consistent after a list-tap shortcut.
      final driversCol = await _mongo.drivers();
      await driversCol.updateOne(
        where.eq('_id', driverObjId),
        modify
            .set('current_offer_trip_id', null)
            .set('current_offer_expires_at', null)
            .set('updated_at', now),
      );
      developer.log('[sched] LIST-ACCEPT $tripId → $driverId', name: 'sched');
      return (success: true, reason: null);
    }

    // Atomic update matched nothing — figure out what actually
    // happened so the driver sees a useful toast.
    final tripDoc = await col.findOne(where.eq('_id', tripObjId));
    if (tripDoc == null) {
      return (success: false, reason: 'Chuyến không còn tồn tại');
    }
    final trip = ScheduledTrip.fromMongo(tripDoc);
    return (
      success: false,
      reason: _diagnoseListAcceptFailure(trip: trip, driverId: driverId, now: now),
    );
  }

  String _diagnoseListAcceptFailure({
    required ScheduledTrip trip,
    required String driverId,
    required DateTime now,
  }) {
    if (trip.driverId == driverId) return 'Chuyến đã thuộc về bạn';
    if (trip.driverId != null) return 'Chuyến đã được tài xế khác nhận';
    switch (trip.status) {
      case ScheduledTripStatus.cancelled:
        return 'Chuyến đã bị huỷ';
      case ScheduledTripStatus.completed:
        return 'Chuyến đã hoàn thành';
      case ScheduledTripStatus.noDriverFound:
      case ScheduledTripStatus.expired:
        return 'Chuyến đã hết hạn tìm tài xế';
      case ScheduledTripStatus.offered:
        // Offered to someone else and that offer is still alive — be
        // explicit so the driver doesn't think someone already
        // accepted.
        return 'Chuyến đang được mời cho tài xế khác, vui lòng thử lại sau';
      case ScheduledTripStatus.driverAssigned:
      case ScheduledTripStatus.matched:
      case ScheduledTripStatus.started:
        return 'Chuyến đã được tài xế khác nhận';
      case ScheduledTripStatus.pending:
        return 'Không thể nhận chuyến này, vui lòng thử lại';
    }
  }

  Future<bool> cancelScheduledTrip({
    required String tripId,
    required String cancelledBy,
    String? reason,
  }) async {
    final col = await _mongo.scheduledTrips();
    final now = DateTime.now().toUtc();
    final res = await col.updateOne(
      where.eq('_id', ObjectId.fromHexString(tripId)),
      modify
          .set('status', ScheduledTripStatus.cancelled.mongoName)
          .set('cancelled_at', now)
          .set('cancelled_by', cancelledBy)
          .set('cancel_reason', reason)
          .set('updated_at', now),
    );
    return res.isSuccess && (res.nModified) > 0;
  }
}
