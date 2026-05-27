import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/utils/geohash_util.dart';
import '../models/scheduled_trip.dart';
import '../services/directions_service.dart';
import '../services/scheduled_trip_service.dart';
import 'auth_provider.dart';
import 'mongo_provider.dart';

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

@riverpod
Future<List<ScheduledTrip>> driverUpcomingTrips(Ref ref) =>
    ref.watch(scheduledTripServiceProvider).getUpcomingTripsForDriver();

// ─────────────────────────────────────────────────────────────────────
// Form state for Schedule Ride Screen
// ─────────────────────────────────────────────────────────────────────

@freezed
class ScheduleRideFormState with _$ScheduleRideFormState {
  const factory ScheduleRideFormState({
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

  @override
  ScheduleRideFormState build() => const ScheduleRideFormState();

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
    _recalcLocally();
  }

  void setLuggage(LuggageType l) {
    state = state.copyWith(luggage: l);
  }

  void setRideType(String type) {
    state = state.copyWith(rideType: type, allowPooling: type == 'shared');
    _recalcLocally();
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

  /// Full recalc: hits the Directions API to refresh distance/duration
  /// then folds the result into the fare. Debounced by [_recalcToken]
  /// so stale responses can't overwrite a newer one.
  Future<void> _scheduleRecalc() async {
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
  }
}
