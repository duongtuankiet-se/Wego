import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/utils/geohash_util.dart';
import '../models/route.dart';
import '../models/scheduled_trip.dart';
import '../services/directions_service.dart';
import '../services/scheduled_trip_service.dart';
import 'auth_provider.dart';
import 'mongo_provider.dart';
import 'routes_provider.dart';

part 'scheduled_trips_provider.freezed.dart';
part 'scheduled_trips_provider.g.dart';

@Riverpod(keepAlive: true)
ScheduledTripService scheduledTripService(Ref ref) =>
    ScheduledTripService(ref.watch(mongoServiceProvider));

@riverpod
Future<List<ScheduledTrip>> upcomingScheduledTrips(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const [];
  return ref.watch(scheduledTripServiceProvider).getUpcomingTrips(user.id);
}

@riverpod
Future<List<ScheduledTrip>> pastScheduledTrips(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const [];
  return ref.watch(scheduledTripServiceProvider).getPastTrips(user.id);
}

@riverpod
Future<ScheduledTrip?> scheduledTripDetail(Ref ref, String tripId) =>
    ref.watch(scheduledTripServiceProvider).getById(tripId);

/// Phase 5R: live-polling variant of [scheduledTripDetailProvider]. Used
/// by the customer waiting screen so the status banner reflects
/// pending → offered → driverAssigned without manual refresh. Polls
/// every 5s — same cadence as the pool tracker so customers never see
/// a stale snapshot longer than that.
@riverpod
Stream<ScheduledTrip?> scheduledTripWatcher(Ref ref, String tripId) async* {
  final svc = ref.watch(scheduledTripServiceProvider);
  yield await svc.getById(tripId);
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 5))) {
    yield await svc.getById(tripId);
  }
}

@riverpod
Future<List<ScheduledTrip>> driverUpcomingTrips(Ref ref) =>
    ref.watch(scheduledTripServiceProvider).getUpcomingTripsForDriver();

// ─────────────────────────────────────────────────────────────────────
// Form state for Schedule Ride Screen
// ─────────────────────────────────────────────────────────────────────

@freezed
class ScheduleRideFormState with _$ScheduleRideFormState {
  const factory ScheduleRideFormState({
    @Default(ScheduleMode.freePoint) ScheduleMode mode,
    RoutePreset? selectedRoute,
    RoutePreset? suggestedRoute,
    ScheduledTripLocation? pickup,
    ScheduledTripLocation? dropoff,
    @Default(<ScheduledTripLocation>[]) List<ScheduledTripLocation> waypoints,
    DateTime? scheduledAt,
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
    String? promoMessage,
    @Default(false) bool promoIsValid,
    @Default(0) double estimatedDistanceKm,
    @Default(0) int estimatedDurationMin,
    @Default(0) int baseFare,
    @Default(0) int discount,
    @Default(0) int estimatedFare,
    @Default(false) bool isCalculating,
  }) = _ScheduleRideFormState;
}

@riverpod
class ScheduleRideForm extends _$ScheduleRideForm {
  /// Monotonic token used to discard stale fare-recalc results when the
  /// user changes pickup/dropoff faster than the Directions API replies.
  int _recalcToken = 0;

  /// Phase 5M: 800ms debounce on the Directions API call so rapid
  /// pickup→dropoff edits collapse into a single network round-trip.
  /// Defense in depth alongside [_recalcToken] — the token guards
  /// against late responses, the timer guards against ever firing them.
  Timer? _recalcDebouncer;

  @override
  ScheduleRideFormState build() {
    ref.onDispose(() => _recalcDebouncer?.cancel());
    return const ScheduleRideFormState();
  }

  // Phase 5Q dual-mode setters ──────────────────────────────────────

  /// Switch between freePoint (per-km, no pool) and fixedRoute (flat
  /// fare from a [RoutePreset], pool engine enabled). Resets pickup/
  /// dropoff/fare to avoid carrying stale data from the other mode.
  void setMode(ScheduleMode mode) {
    if (state.mode == mode) return;
    _recalcDebouncer?.cancel();
    state = state.copyWith(
      mode: mode,
      selectedRoute: null,
      suggestedRoute: null,
      pickup: null,
      dropoff: null,
      baseFare: 0,
      estimatedFare: 0,
      discount: 0,
      estimatedDistanceKm: 0,
      estimatedDurationMin: 0,
      isCalculating: false,
    );
  }

  void setSelectedRoute(RoutePreset? route) {
    state = state.copyWith(
      selectedRoute: route,
      pickup: null,
      dropoff: null,
    );
    _recalcFareFromRoute();
  }

  /// Customer tapped "Đổi" on the upsell banner: flip to fixedRoute
  /// + select the suggested route in one shot.
  void acceptUpsellRoute() {
    final s = state.suggestedRoute;
    if (s == null) return;
    setMode(ScheduleMode.fixedRoute);
    setSelectedRoute(s);
  }

  void setPickup(ScheduledTripLocation? loc) {
    state = state.copyWith(pickup: loc);
    _scheduleRecalc();
  }

  void setDropoff(ScheduledTripLocation? loc) {
    state = state.copyWith(dropoff: loc);
    _scheduleRecalc();
  }

  void setScheduledAt(DateTime dt) {
    state = state.copyWith(scheduledAt: dt);
  }

  void setPassengerCount(int count) {
    state = state.copyWith(passengerCount: count.clamp(1, 4));
    // Phase 5Q: pax change re-derives flat fare immediately when
    // we're on a fixed route; free-point just refreshes the locally
    // computed discount layer.
    if (state.mode == ScheduleMode.fixedRoute) {
      _recalcFareFromRoute();
    } else {
      _recalcLocally();
    }
  }

  void setLuggage(LuggageType l) {
    state = state.copyWith(luggage: l);
  }

  void setRideType(String type) {
    state = state.copyWith(rideType: type, allowPooling: type == 'shared');
    if (state.mode == ScheduleMode.fixedRoute) {
      _recalcFareFromRoute();
    } else {
      _recalcLocally();
    }
  }

  void setAllowPooling(bool v) {
    state = state.copyWith(allowPooling: v);
  }

  void setFlexibleWindow(int min) {
    state = state.copyWith(flexibleWindowMin: min);
  }

  void setRecurrence(RecurrenceType r) {
    state = state.copyWith(recurrence: r);
  }

  void setPaymentMethod(SchedulePaymentMethod m) {
    state = state.copyWith(paymentMethod: m);
  }

  /// Result of a "Áp dụng" promo check. [discount] is the VND amount
  /// the promo would shave off the current base fare (already accounting
  /// for caps + percent/fixed split).
  void setPromoResult({
    required String? code,
    required bool isValid,
    required String? message,
    required int discount,
  }) {
    state = state.copyWith(
      promoCode: isValid ? code : null,
      promoIsValid: isValid,
      promoMessage: message,
    );
    _recalcLocally();
  }

  void clearPromo() {
    state = state.copyWith(
      promoCode: null,
      promoIsValid: false,
      promoMessage: null,
    );
    _recalcLocally();
  }

  void reset() {
    _recalcDebouncer?.cancel();
    state = const ScheduleRideFormState();
  }

  // ── Recalc helpers ────────────────────────────────────────────────

  /// Recompute the discount + estimated fare using current state but
  /// without hitting the Directions API. Cheap — call after promo /
  /// passenger count / ride-type changes.
  void _recalcLocally() {
    final s = state;
    if (s.baseFare == 0) return;
    final svc = ref.read(scheduledTripServiceProvider);
    final base = svc.calcBaseFare(
      distanceKm: s.estimatedDistanceKm,
      rideType: s.rideType,
    );
    final disc = svc.previewDiscount(
      baseFare: base,
      passengerCount: s.passengerCount,
      promoCode: s.promoIsValid ? s.promoCode : null,
    );
    state = s.copyWith(
      baseFare: base,
      discount: disc,
      estimatedFare: base - disc,
    );
  }

  /// Phase 5Q routing: fixed-route flat-fare recompute is instant
  /// (no network), free-point still goes through the 800ms debounce
  /// before hitting Directions.
  void _scheduleRecalc() {
    _recalcDebouncer?.cancel();
    if (state.mode == ScheduleMode.fixedRoute) {
      _recalcFareFromRoute();
      return;
    }
    if (state.pickup == null || state.dropoff == null) return;
    _recalcDebouncer = Timer(
      const Duration(milliseconds: 800),
      _doRecalcFare,
    );
  }

  /// Compute flat fare from the [RoutePreset] price table. Honors the
  /// shared/private split and stacks the existing ≥3-pax + promo
  /// discounts on top.
  void _recalcFareFromRoute() {
    final s = state;
    final route = s.selectedRoute;
    if (route == null) return;
    final isPrivate = s.rideType == 'private';
    final baseFare = isPrivate
        ? route.baseFarePrivate
        : route.baseFareCarpool * s.passengerCount;

    final svc = ref.read(scheduledTripServiceProvider);
    final discount = svc.previewDiscount(
      baseFare: baseFare,
      passengerCount: s.passengerCount,
      promoCode: s.promoIsValid ? s.promoCode : null,
    );

    state = s.copyWith(
      baseFare: baseFare,
      discount: discount,
      estimatedFare: baseFare - discount,
      estimatedDistanceKm: route.distanceKm.toDouble(),
      estimatedDurationMin: route.durationMin,
      isCalculating: false,
    );
  }

  /// Full recalc: hits the Directions API to refresh distance/duration
  /// then folds the result into the fare. Stale responses are dropped
  /// via [_recalcToken] in case a newer call already superseded us
  /// (network jitter / multiple debouncer firings).
  Future<void> _doRecalcFare() async {
    final s = state;
    if (s.pickup == null || s.dropoff == null) return;

    final token = ++_recalcToken;
    state = state.copyWith(isCalculating: true);

    final route = await DirectionsService.getRoute(
      origin: LatLng(s.pickup!.lat, s.pickup!.lng),
      destination: LatLng(s.dropoff!.lat, s.dropoff!.lng),
    );

    if (token != _recalcToken) return; // a newer call superseded us

    final distanceKm =
        route?.distanceKm ??
        GeohashUtil.distanceKm(
          s.pickup!.lat,
          s.pickup!.lng,
          s.dropoff!.lat,
          s.dropoff!.lng,
        );
    // Fallback: 25 km/h average inside-city
    final durationMin =
        route?.durationMin ?? (distanceKm / 25 * 60).round().clamp(1, 240);

    final svc = ref.read(scheduledTripServiceProvider);
    final baseFare = svc.calcBaseFare(
      distanceKm: distanceKm,
      rideType: state.rideType,
    );
    final discount = svc.previewDiscount(
      baseFare: baseFare,
      passengerCount: state.passengerCount,
      promoCode: state.promoIsValid ? state.promoCode : null,
    );

    state = state.copyWith(
      estimatedDistanceKm: distanceKm,
      estimatedDurationMin: durationMin,
      baseFare: baseFare,
      discount: discount,
      estimatedFare: baseFare - discount,
      isCalculating: false,
    );

    // Phase 5Q: after free-point fare lands, look for a matching
    // preset route so the UI can pop a flat-fare upsell banner.
    unawaited(_checkRouteUpsell());
  }

  /// Phase 5Q: free-point booking might align with one of the preset
  /// corridors (e.g. user typed Đà Nẵng → Hội An by hand). When it
  /// does, surface a "Có tuyến cố định" banner so they can switch
  /// over to the flat fare.
  Future<void> _checkRouteUpsell() async {
    final s = state;
    if (s.mode != ScheduleMode.freePoint) return;
    if (s.pickup == null || s.dropoff == null) {
      if (s.suggestedRoute != null) {
        state = s.copyWith(suggestedRoute: null);
      }
      return;
    }
    final pickupCity = _extractCity(s.pickup!.address);
    final dropoffCity = _extractCity(s.dropoff!.address);
    if (pickupCity == null ||
        dropoffCity == null ||
        pickupCity == dropoffCity) {
      if (s.suggestedRoute != null) {
        state = s.copyWith(suggestedRoute: null);
      }
      return;
    }
    try {
      final route = await ref
          .read(routeServiceProvider)
          .findByEndpoints(pickupCity: pickupCity, dropoffCity: dropoffCity);
      state = state.copyWith(suggestedRoute: route);
    } catch (_) {
      // Upsell is best-effort; never let it break booking.
    }
  }

  String? _extractCity(String address) {
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.last;
  }
}
