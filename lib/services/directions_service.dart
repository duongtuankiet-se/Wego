import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../core/env.dart';
import '../core/utils/geohash_util.dart';

class DirectionsRoute {
  /// Decoded polyline points to feed into a [LineLayer] / `addLine`.
  final List<LatLng> points;

  /// Total route distance in meters (from the first leg).
  final int distanceMeters;
  final String distanceText;

  /// Total duration in seconds.
  final int durationSeconds;
  final String durationText;

  /// Tight bounds around the route — use with
  /// `MaplibreMapController.animateCamera(CameraUpdate.newLatLngBounds(...))`.
  final LatLngBounds bounds;

  /// Turn-by-turn maneuvers along the first leg. Empty if the API
  /// didn't return any (ZERO_RESULTS or 1-point routes).
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

/// One maneuver in a leg (e.g. "Rẽ phải vào Trần Phú"). [start]/[end]
/// are the segment endpoints — used to decide when to advance the
/// instruction card as the driver crosses them.
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

/// Thin wrapper around the **TrackAsia Directions v2** REST API.
///
/// Response shape mirrors Google Directions (routes[].legs[].steps[],
/// `overview_polyline.points` encoded), so the existing parser logic +
/// Phosphor maneuver-icon mapping reuse without changes.
///
/// **Quirk:** `start_location` / `end_location` fields on each step
/// arrive with **lat and lng swapped** (lat field holds longitude
/// and vice versa). `bounds.northeast/southwest` and Reverse Geocoding
/// are NOT affected. Verified against multiple test routes 2026-05-27.
/// We unswap them in [_parseStepLatLng] below.
class DirectionsService {
  DirectionsService._();

  static const _path = '/route/v2/directions/json';

  /// Returns the first route, or `null` on any error / quota issue.
  static Future<DirectionsRoute?> getRoute({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    if (!Env.hasTrackasiaKey) {
      developer.log('Missing TRACKASIA_API_KEY', name: 'directions');
      return null;
    }

    // Skip the call for sub-50m hops — TrackAsia (and Google) returns
    // ZERO_RESULTS for "destination is on the same building", so save
    // the round-trip + let the caller use its interpolated fallback.
    final straightKm = GeohashUtil.distanceKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (straightKm < 0.05) {
      developer.log(
        'Skipping API call: straight-line=${straightKm.toStringAsFixed(3)}km',
        name: 'directions',
      );
      return null;
    }

    final uri = Uri.https(Env.trackasiaApiHost, _path, <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode,
      'new_admin': 'true',
      'language': 'vi',
      'key': Env.trackasiaApiKey,
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        final preview = res.body.length > 240
            ? '${res.body.substring(0, 240)}…'
            : res.body;
        developer.log('HTTP ${res.statusCode}: $preview', name: 'directions');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      if (status != 'OK') {
        developer.log(
          'API status=$status error=${json['error_message']} '
          'origin=$origin dest=$destination',
          name: 'directions',
        );
        return null;
      }
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        developer.log('No routes returned', name: 'directions');
        return null;
      }
      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List;
      if (legs.isEmpty) return null;
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

      // ── steps with lat/lng unswap fix ─────────────────────────────
      // TrackAsia v2 bug: step.start_location / end_location report
      // {lat: <lng>, lng: <lat>}. Unswap so consumers don't see Đà
      // Nẵng plotted in the Atlantic.
      final stepsJson = (leg['steps'] as List?) ?? const [];
      final steps = stepsJson
          .map((s) {
            final m = s as Map<String, dynamic>;
            final distObj = m['distance'];
            final durObj = m['duration'];
            return DirectionsStep(
              instruction: _stripHtml(m['html_instructions'] as String? ?? ''),
              distanceMeters: _intFromValue(distObj),
              distanceText: _textFromValue(distObj),
              durationSeconds: _intFromValue(durObj),
              maneuver: m['maneuver'] as String?,
              start: _parseStepLatLng(m['start_location']),
              end: _parseStepLatLng(m['end_location']),
            );
          })
          .toList(growable: false);

      return DirectionsRoute(
        points: decoded,
        distanceMeters: _intFromValue(leg['distance']),
        distanceText: _textFromValue(leg['distance']),
        durationSeconds: _intFromValue(leg['duration']),
        durationText: _textFromValue(leg['duration']),
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

  /// Read `start_location` / `end_location` and unswap. Detection is
  /// purely from the value range — Vietnam lat is roughly 8–24 and
  /// lng 102–110, so anything > 90 in the "lat" field is the
  /// swapped longitude.
  static LatLng _parseStepLatLng(Object? raw) {
    if (raw is! Map) return const LatLng(0, 0);
    final a = (raw['lat'] as num?)?.toDouble() ?? 0;
    final b = (raw['lng'] as num?)?.toDouble() ?? 0;
    // If "lat" exceeds 90 it physically can't be a latitude → swapped.
    if (a.abs() > 90) {
      return LatLng(b, a);
    }
    return LatLng(a, b);
  }

  /// TrackAsia distance/duration can arrive as either a structured
  /// `{text, value}` Map (Google-style) or a stringified PowerShell
  /// PSCustomObject ("@{text=0.3km; value=342}") when intermediate
  /// JSON gets re-serialized somewhere. Handle both.
  static int _intFromValue(Object? raw) {
    if (raw is Map) return (raw['value'] as num? ?? 0).toInt();
    return 0;
  }

  static String _textFromValue(Object? raw) {
    if (raw is Map) return raw['text'] as String? ?? '';
    return '';
  }

  /// Strip Google/TrackAsia HTML markup ("<b>Trần Phú</b>") down to
  /// readable text. Both APIs only use a handful of tags.
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
