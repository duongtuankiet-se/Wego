import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

/// Curved fallback polyline for when Google Directions returns null
/// (quota exhausted, no network, ZERO_RESULTS for very short trips).
///
/// Builds a quadratic Bezier between origin and destination with a small
/// perpendicular offset on the control point so the line bends
/// naturally instead of running dead-straight. 15 segments is enough to
/// look like a road at city zoom without inflating the marker count.
class PolylineFallback {
  PolylineFallback._();

  /// Generate `segments + 1` LatLngs along a curved path.
  static List<LatLng> interpolate({
    required LatLng origin,
    required LatLng destination,
    int segments = 15,
  }) {
    if (segments < 1) segments = 1;

    final dx = destination.longitude - origin.longitude;
    final dy = destination.latitude - origin.latitude;
    final length = math.sqrt(dx * dx + dy * dy);

    // Control point sits ~8% of the line's length off the midpoint,
    // perpendicular to the origin→destination vector. Zero-length input
    // collapses to the origin to avoid NaN.
    final midLat = (origin.latitude + destination.latitude) / 2;
    final midLng = (origin.longitude + destination.longitude) / 2;
    final offset = length * 0.08;
    final controlLat = length == 0 ? midLat : midLat + (dx / length) * offset;
    final controlLng = length == 0 ? midLng : midLng - (dy / length) * offset;
    final control = LatLng(controlLat, controlLng);

    final points = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final inv = 1 - t;
      final lat =
          inv * inv * origin.latitude +
          2 * inv * t * control.latitude +
          t * t * destination.latitude;
      final lng =
          inv * inv * origin.longitude +
          2 * inv * t * control.longitude +
          t * t * destination.longitude;
      points.add(LatLng(lat, lng));
    }
    return points;
  }
}
