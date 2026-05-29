import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'route.freezed.dart';

/// Phase 5Q fixed-route model — one preset inter-city corridor (e.g.
/// "Đà Nẵng → Hội An"). Used by the "Chọn tuyến có sẵn" Schedule mode
/// for flat-fare pricing and (per Phase 5Q) is the only mode that
/// feeds the carpool pool engine.
@freezed
class RoutePreset with _$RoutePreset {
  const RoutePreset._();

  const factory RoutePreset({
    required String id,
    required String routeCode,
    required String name,
    @Default('central') String region,
    required String pickupCity,
    @Default(<String>[]) List<String> pickupProvinces,
    required String dropoffCity,
    required int distanceKm,
    required int baseFareCarpool,
    required int baseFarePrivate,
    required int durationMin,
    @Default(15) int commissionPercent,
    @Default(true) bool isActive,
    @Default(false) bool isPopular,
    @Default(0) int displayOrder,
    DateTime? availableFrom,
    @Default(0) int totalTrips,
    @Default(0) int totalPassengers,
    @Default(0.0) double avgRating,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _RoutePreset;

  String get displayLabel => '$pickupCity → $dropoffCity';

  /// "100k/người" — render alongside the route name in pickers.
  String get fareLabel => '${(baseFareCarpool / 1000).round()}k/người';

  String get fareLabelPrivate =>
      '${(baseFarePrivate / 1000).round()}k/xe';

  String get distanceLabel => '$distanceKm km · $durationMin phút';

  static RoutePreset fromMongo(Map<String, dynamic> doc) => RoutePreset(
    id: (doc['_id'] as ObjectId).oid,
    routeCode: doc['route_code'] as String,
    name: doc['name'] as String,
    region: (doc['region'] as String?) ?? 'central',
    pickupCity: doc['pickup_city'] as String,
    pickupProvinces: ((doc['pickup_provinces'] as List?) ?? const [])
        .cast<String>(),
    dropoffCity: doc['dropoff_city'] as String,
    distanceKm: (doc['distance_km'] as num).toInt(),
    baseFareCarpool: (doc['base_fare_carpool'] as num).toInt(),
    baseFarePrivate: (doc['base_fare_private'] as num).toInt(),
    durationMin: (doc['duration_min'] as num).toInt(),
    commissionPercent: (doc['commission_percent'] as num?)?.toInt() ?? 15,
    isActive: (doc['is_active'] as bool?) ?? true,
    isPopular: (doc['is_popular'] as bool?) ?? false,
    displayOrder: (doc['display_order'] as num?)?.toInt() ?? 0,
    availableFrom: (doc['available_from'] as DateTime?)?.toLocal(),
    totalTrips: (doc['total_trips'] as num?)?.toInt() ?? 0,
    totalPassengers: (doc['total_passengers'] as num?)?.toInt() ?? 0,
    avgRating: ((doc['avg_rating'] as num?) ?? 0).toDouble(),
    createdAt: (doc['created_at'] as DateTime).toLocal(),
    updatedAt: (doc['updated_at'] as DateTime).toLocal(),
  );
}
