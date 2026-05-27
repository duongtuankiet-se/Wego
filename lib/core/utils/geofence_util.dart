import 'package:maplibre_gl/maplibre_gl.dart';

import 'geohash_util.dart';

/// Tiny helpers around "is the car close enough to its destination to
/// auto-advance the trip phase?" Avoids each screen reinventing the
/// same Haversine check + threshold.
class GeofenceUtil {
  GeofenceUtil._();

  /// Default trigger radius — Google Maps reports ±10–15m positioning
  /// jitter even with GPS, so 50m gives a comfortable margin without
  /// firing the arrival event a block too early.
  static const double defaultThresholdMeters = 50;

  /// Straight-line distance between two points, in metres.
  static double distanceMeters(LatLng a, LatLng b) {
    return GeohashUtil.distanceKm(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        ) *
        1000;
  }

  /// `true` if [point] is within [threshold] metres of [target].
  static bool isWithin(
    LatLng point,
    LatLng target, {
    double threshold = defaultThresholdMeters,
  }) {
    return distanceMeters(point, target) < threshold;
  }
}
