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

  /// Turn-by-turn maneuvers along the first leg. Empty if the API didn't
  /// return any (rare but possible for ZERO_RESULTS or 1-point routes).
  final List<DirectionsStep> steps;

  const DirectionsRoute({
    required this.points,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.bounds,
    required this.steps,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMin => (durationSeconds / 60).round();
}

/// One maneuver in a leg (e.g. "Rẽ phải vào Trần Phú"). Coordinates are
/// for the segment endpoint — used to decide when to advance the
/// instruction card as the driver crosses it.
class DirectionsStep {
  final String instruction;
  final int distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String? maneuver;
  final LatLng start;
  final LatLng end;

  const DirectionsStep({
    required this.instruction,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.maneuver,
    required this.start,
    required this.end,
  });
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

      final stepsJson = (leg['steps'] as List?) ?? const [];
      final steps = stepsJson
          .map((s) {
            final m = s as Map<String, dynamic>;
            final start = m['start_location'] as Map<String, dynamic>;
            final end = m['end_location'] as Map<String, dynamic>;
            return DirectionsStep(
              instruction: _stripHtml(m['html_instructions'] as String? ?? ''),
              distanceMeters: (m['distance']?['value'] as num?)?.toInt() ?? 0,
              distanceText: m['distance']?['text'] as String? ?? '',
              durationSeconds: (m['duration']?['value'] as num?)?.toInt() ?? 0,
              maneuver: m['maneuver'] as String?,
              start: LatLng(
                (start['lat'] as num).toDouble(),
                (start['lng'] as num).toDouble(),
              ),
              end: LatLng(
                (end['lat'] as num).toDouble(),
                (end['lng'] as num).toDouble(),
              ),
            );
          })
          .toList(growable: false);

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
        steps: steps,
      );
    } catch (e) {
      developer.log('Directions error: $e', name: 'directions');
      return null;
    }
  }

  /// Strip Google's HTML markup ("<b>Trần Phú</b>") down to readable text
  /// ("Trần Phú"). Crude but enough for the turn instructions Google
  /// returns — they only use a handful of tags.
  static String _stripHtml(String html) {
    final withBreaks = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' · ')
        .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), ' · ')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '');
    return withBreaks
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
