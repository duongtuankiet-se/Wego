import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../core/env.dart';

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

/// Thin wrapper over Places API "autocomplete" + "details" endpoints.
/// All requests bias toward Vietnam (`components=country:vn`, `language=vi`).
class PlacesService {
  PlacesService._();

  static const _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const _geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  static Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return const [];
    if (!Env.hasGoogleMapsKey) return const [];
    final uri = Uri.parse(_autocompleteUrl).replace(
      queryParameters: <String, String>{
        'input': input,
        'language': 'vi',
        'components': 'country:vn',
        'key': Env.googleMapsApiKey,
      },
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        developer.log('autocomplete HTTP ${res.statusCode}', name: 'places');
        return const [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        developer.log(
          'autocomplete status=$status ${body['error_message']}',
          name: 'places',
        );
        return const [];
      }
      final preds = (body['predictions'] as List?) ?? const [];
      return preds.map((p) {
        final m = p as Map<String, dynamic>;
        final structured =
            (m['structured_formatting'] as Map<String, dynamic>?) ?? {};
        return PlaceSuggestion(
          placeId: m['place_id'] as String,
          mainText:
              (structured['main_text'] as String?) ??
              (m['description'] as String? ?? ''),
          secondaryText:
              (structured['secondary_text'] as String?) ??
              (m['description'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      developer.log('autocomplete error: $e', name: 'places');
      return const [];
    }
  }

  static Future<PlaceDetails?> getDetails(String placeId) async {
    if (!Env.hasGoogleMapsKey) return null;
    final uri = Uri.parse(_detailsUrl).replace(
      queryParameters: <String, String>{
        'place_id': placeId,
        'language': 'vi',
        'fields': 'place_id,name,formatted_address,geometry/location',
        'key': Env.googleMapsApiKey,
      },
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') {
        developer.log(
          'details status=${body['status']} ${body['error_message']}',
          name: 'places',
        );
        return null;
      }
      final result = body['result'] as Map<String, dynamic>;
      final geo = result['geometry'] as Map<String, dynamic>;
      final loc = geo['location'] as Map<String, dynamic>;
      return PlaceDetails(
        placeId: result['place_id'] as String,
        name:
            (result['name'] as String?) ??
            (result['formatted_address'] as String? ?? ''),
        address: (result['formatted_address'] as String?) ?? '',
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
      );
    } catch (e) {
      developer.log('details error: $e', name: 'places');
      return null;
    }
  }

  /// Reverse-geocode a coordinate into the best-guess Vietnamese formatted
  /// address (e.g. "280 Trần Phú, Hải Châu, Đà Nẵng"). Returns `null` on
  /// network failure or non-OK status; callers should fall back to showing
  /// the raw lat/lng.
  static Future<String?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    if (!Env.hasGoogleMapsKey) return null;
    final uri = Uri.parse(_geocodeUrl).replace(
      queryParameters: <String, String>{
        'latlng': '$lat,$lng',
        'language': 'vi',
        'result_type': 'street_address|premise|route|neighborhood',
        'key': Env.googleMapsApiKey,
      },
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status != 'OK') {
        if (status != 'ZERO_RESULTS') {
          developer.log(
            'reverseGeocode status=$status ${body['error_message']}',
            name: 'places',
          );
        }
        return null;
      }
      final results = (body['results'] as List?) ?? const [];
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      return first['formatted_address'] as String?;
    } catch (e) {
      developer.log('reverseGeocode error: $e', name: 'places');
      return null;
    }
  }
}
