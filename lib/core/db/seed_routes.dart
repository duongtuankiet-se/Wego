import 'dart:developer' as developer;

import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

import 'mongo_service.dart';

/// Phase 5Q: idempotent seed of the 7 default Miền Trung corridors.
/// Runs once on app launch via [seedIfEmpty] — bails out the moment it
/// sees any document in the collection, so re-launches don't duplicate.
class RouteSeed {
  RouteSeed._();

  static const List<Map<String, Object>> _seed = [
    {
      'route_code': 'DN-HA',
      'name': 'Đà Nẵng → Hội An',
      'pickup_city': 'Đà Nẵng',
      'pickup_provinces': ['Đà Nẵng'],
      'dropoff_city': 'Hội An',
      'distance_km': 30,
      'base_fare_carpool': 50000,
      'base_fare_private': 200000,
      'duration_min': 45,
      'is_popular': true,
      'display_order': 1,
    },
    {
      'route_code': 'DN-QN',
      'name': 'Đà Nẵng → Tam Kỳ',
      'pickup_city': 'Đà Nẵng',
      'pickup_provinces': ['Đà Nẵng'],
      'dropoff_city': 'Tam Kỳ',
      'distance_km': 70,
      'base_fare_carpool': 100000,
      'base_fare_private': 400000,
      'duration_min': 90,
      'is_popular': true,
      'display_order': 2,
    },
    {
      'route_code': 'DN-HUE',
      'name': 'Đà Nẵng → Huế',
      'pickup_city': 'Đà Nẵng',
      'pickup_provinces': ['Đà Nẵng'],
      'dropoff_city': 'Huế',
      'distance_km': 100,
      'base_fare_carpool': 150000,
      'base_fare_private': 600000,
      'duration_min': 120,
      'is_popular': true,
      'display_order': 3,
    },
    {
      'route_code': 'QN-DN',
      'name': 'Tam Kỳ → Đà Nẵng',
      'pickup_city': 'Tam Kỳ',
      'pickup_provinces': ['Quảng Nam'],
      'dropoff_city': 'Đà Nẵng',
      'distance_km': 70,
      'base_fare_carpool': 100000,
      'base_fare_private': 400000,
      'duration_min': 90,
      'is_popular': true,
      'display_order': 4,
    },
    {
      'route_code': 'QN-HUE',
      'name': 'Tam Kỳ → Huế',
      'pickup_city': 'Tam Kỳ',
      'pickup_provinces': ['Quảng Nam'],
      'dropoff_city': 'Huế',
      'distance_km': 170,
      'base_fare_carpool': 250000,
      'base_fare_private': 1000000,
      'duration_min': 200,
      'is_popular': false,
      'display_order': 5,
    },
    {
      'route_code': 'HUE-DN',
      'name': 'Huế → Đà Nẵng',
      'pickup_city': 'Huế',
      'pickup_provinces': ['Thừa Thiên Huế'],
      'dropoff_city': 'Đà Nẵng',
      'distance_km': 100,
      'base_fare_carpool': 150000,
      'base_fare_private': 600000,
      'duration_min': 120,
      'is_popular': true,
      'display_order': 6,
    },
    {
      'route_code': 'HUE-HA',
      'name': 'Huế → Hội An',
      'pickup_city': 'Huế',
      'pickup_provinces': ['Thừa Thiên Huế'],
      'dropoff_city': 'Hội An',
      'distance_km': 130,
      'base_fare_carpool': 200000,
      'base_fare_private': 800000,
      'duration_min': 150,
      'is_popular': false,
      'display_order': 7,
    },
  ];

  /// Insert the preset rows only if the collection is empty. Safe to
  /// call on every app launch.
  static Future<int> seedIfEmpty(MongoService mongo) async {
    try {
      final col = await mongo.routes();
      final existing = await col.count();
      if (existing > 0) {
        developer.log(
          '[seed] routes already populated ($existing rows)',
          name: 'seed',
        );
        return 0;
      }
      final now = DateTime.now().toUtc();
      final docs = _seed.map((r) {
        return <String, dynamic>{
          ...r,
          '_id': ObjectId(),
          'region': 'central',
          'commission_percent': 15,
          'is_active': true,
          'available_from': now,
          'total_trips': 0,
          'total_passengers': 0,
          'avg_rating': 0.0,
          'created_at': now,
          'updated_at': now,
        };
      }).toList(growable: false);
      await col.insertMany(docs);
      developer.log('[seed] inserted ${docs.length} routes', name: 'seed');
      return docs.length;
    } catch (e, st) {
      developer.log(
        '[seed] route seed failed: $e',
        name: 'seed',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }
}
