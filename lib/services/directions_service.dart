import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../core/env.dart';

class DirectionsRoute {
  /// Decoded polyline points to feed into a [Polyline].
  final List<LatLng> points;

  /// Total route distance in meters (from Google's first leg).
  final int distanceMeters;
  final String distanceText;

  /// Total duration in seconds.
  final int durationSeconds;
  final String durationText;

  /// Tight bounds around the route — use with CameraUpdate.newLatLngBounds.
  final LatLngBounds bounds;

  const DirectionsRoute({
    required this.points,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.bounds,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMin => (durationSeconds / 60).round();
}

/// Thin wrapper around the Google Directions REST API. The repo only
/// uses the driving profile + Vietnamese language. Result is parsed into
/// a [DirectionsRoute] suitable for direct GoogleMap consumption.
class DirectionsService {
  DirectionsService._();

  static const _endpoint =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Returns the first route, or null on any error / quota issue.
  static Future<DirectionsRoute?> getRoute({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    if (!Env.hasGoogleMapsKey) {
      developer.log('Missing GOOGLE_MAPS_API_KEY', name: 'directions');
      return null;
    }
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': mode,
        'language': 'vi',
        'region': 'vn',
        'key': Env.googleMapsApiKey,
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        developer.log(
          'HTTP ${res.statusCode}: ${res.body}',
          name: 'directions',
        );
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      if (status != 'OK') {
        developer.log(
          'API status=$status: ${json['error_message']}',
          name: 'directions',
        );
        return null;
      }
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List;
      final leg = legs.first as Map<String, dynamic>;
      final overview = route['overview_polyline'] as Map<String, dynamic>;
      final encoded = overview['points'] as String;

      final decoded = PolylinePoints()
          .decodePolyline(encoded)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      final boundsJson = route['bounds'] as Map<String, dynamic>;
      final ne = boundsJson['northeast'] as Map<String, dynamic>;
      final sw = boundsJson['southwest'] as Map<String, dynamic>;

      return DirectionsRoute(
        points: decoded,
        distanceMeters: (leg['distance']['value'] as num).toInt(),
        distanceText: leg['distance']['text'] as String,
        durationSeconds: (leg['duration']['value'] as num).toInt(),
        durationText: leg['duration']['text'] as String,
        bounds: LatLngBounds(
          southwest: LatLng(
            (sw['lat'] as num).toDouble(),
            (sw['lng'] as num).toDouble(),
          ),
          northeast: LatLng(
            (ne['lat'] as num).toDouble(),
            (ne['lng'] as num).toDouble(),
          ),
        ),
      );
    } catch (e) {
      developer.log('Directions error: $e', name: 'directions');
      return null;
    }
  }
}
