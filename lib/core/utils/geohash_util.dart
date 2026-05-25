import 'dart:math' as math;
import 'package:dart_geohash/dart_geohash.dart';

typedef LatLngPair = ({double lat, double lng});

class GeohashUtil {
  GeohashUtil._();

  static final _gh = GeoHasher();

  static String encode(double lat, double lng, {int precision = 6}) {
    return _gh.encode(lng, lat, precision: precision);
  }

  static LatLngPair decode(String hash) {
    final coords = _gh.decode(hash); // [lng, lat]
    return (lat: coords[1], lng: coords[0]);
  }

  /// Returns 9 cells: center + 8 neighbors (useful for proximity search).
  static List<String> neighbors(String hash) {
    final n = _gh.neighbors(hash);
    return [hash, ...n.values].where((s) => s.isNotEmpty).toSet().toList();
  }

  /// Haversine distance in kilometers.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Bearing in degrees [0, 360).
  static double bearing(double lat1, double lng1, double lat2, double lng2) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final dLambda = _toRad(lng2 - lng1);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    final theta = math.atan2(y, x);
    return (_toDeg(theta) + 360) % 360;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;
}
