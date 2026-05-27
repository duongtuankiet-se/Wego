import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/env.dart';
import '../core/theme/app_colors.dart';

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final List<String> types;
  final int? distanceMeters;

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.types = const [],
    this.distanceMeters,
  });

  /// Best-guess Phosphor icon for the place's primary category.
  IconData get displayIcon {
    if (types.contains('airport')) return PhosphorIconsFill.airplane;
    if (types.contains('bus_station')) return PhosphorIconsFill.bus;
    if (types.contains('train_station') || types.contains('subway_station')) {
      return PhosphorIconsFill.train;
    }
    if (types.contains('transit_station')) return PhosphorIconsFill.bus;
    if (types.contains('restaurant') ||
        types.contains('food') ||
        types.contains('meal_takeaway') ||
        types.contains('meal_delivery')) {
      return PhosphorIconsFill.forkKnife;
    }
    if (types.contains('cafe')) return PhosphorIconsFill.coffee;
    if (types.contains('lodging') || types.contains('hotel')) {
      return PhosphorIconsFill.bed;
    }
    if (types.contains('shopping_mall')) return PhosphorIconsFill.shoppingBag;
    if (types.contains('store') ||
        types.contains('supermarket') ||
        types.contains('department_store')) {
      return PhosphorIconsFill.storefront;
    }
    if (types.contains('hospital')) return PhosphorIconsFill.firstAidKit;
    if (types.contains('pharmacy') || types.contains('drugstore')) {
      return PhosphorIconsFill.pill;
    }
    if (types.contains('school') ||
        types.contains('university') ||
        types.contains('primary_school') ||
        types.contains('secondary_school')) {
      return PhosphorIconsFill.graduationCap;
    }
    if (types.contains('bank') || types.contains('atm')) {
      return PhosphorIconsFill.bank;
    }
    if (types.contains('gas_station')) return PhosphorIconsFill.gasPump;
    if (types.contains('tourist_attraction')) return PhosphorIconsFill.camera;
    if (types.contains('park')) return PhosphorIconsFill.tree;
    if (types.contains('gym')) return PhosphorIconsFill.barbell;
    if (types.contains('place_of_worship')) {
      return PhosphorIconsFill.buildings;
    }
    return PhosphorIconsFill.mapPin;
  }

  Color get displayIconColor {
    if (types.contains('airport') ||
        types.contains('bus_station') ||
        types.contains('train_station') ||
        types.contains('transit_station')) {
      return AppColors.sharedAccent;
    }
    if (types.contains('restaurant') ||
        types.contains('food') ||
        types.contains('meal_takeaway') ||
        types.contains('cafe')) {
      return AppColors.warning;
    }
    if (types.contains('hospital') || types.contains('pharmacy')) {
      return AppColors.danger;
    }
    if (types.contains('school') ||
        types.contains('university') ||
        types.contains('hotel') ||
        types.contains('lodging')) {
      return const Color(0xFF8B5CF6);
    }
    if (types.contains('shopping_mall') ||
        types.contains('store') ||
        types.contains('supermarket')) {
      return AppColors.warning;
    }
    if (types.contains('gas_station')) return AppColors.ink700;
    if (types.contains('tourist_attraction') || types.contains('park')) {
      return const Color(0xFF0EA5E9);
    }
    return AppColors.primary500;
  }
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

/// **TrackAsia v2** wrapper for autocomplete / details / reverse-geocoding.
///
/// Endpoints (all Google-compatible response shape):
///   - `/api/v2/place/autocomplete/json`  → `predictions[]`
///   - `/api/v2/place/details/json?place_id=...`  → `result.geometry.location`
///   - `/api/v2/geocode/json?latlng=lat,lng`  → `results[0].formatted_address`
///
/// `new_admin=true` requests the 1/7/2025 administrative boundary
/// reform for every call.
class PlacesService {
  PlacesService._();

  static const _autocompletePath = '/api/v2/place/autocomplete/json';
  static const _detailsPath = '/api/v2/place/details/json';
  static const _geocodePath = '/api/v2/geocode/json';

  static Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return const [];
    if (!Env.hasTrackasiaKey) return const [];

    final uri =
        Uri.https(Env.trackasiaApiHost, _autocompletePath, <String, String>{
          'input': input,
          'language': 'vi',
          'location': '${Env.danangLat},${Env.danangLng}',
          'radius': '30000',
          'new_admin': 'true',
          'key': Env.trackasiaApiKey,
        });
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
        final types =
            (m['types'] as List?)?.whereType<String>().toList() ??
            const <String>[];
        final distanceMeters = (m['distance_meters'] as num?)?.toInt();
        return PlaceSuggestion(
          placeId: m['place_id'] as String,
          mainText:
              (structured['main_text'] as String?) ??
              (m['description'] as String? ?? ''),
          secondaryText:
              (structured['secondary_text'] as String?) ??
              (m['description'] as String? ?? ''),
          types: types,
          distanceMeters: distanceMeters,
        );
      }).toList();
    } catch (e) {
      developer.log('autocomplete error: $e', name: 'places');
      return const [];
    }
  }

  /// Place Details — required after autocomplete because TrackAsia
  /// predictions don't include geometry (unlike what the v1 plan
  /// originally claimed).
  static Future<PlaceDetails?> getDetails(String placeId) async {
    if (!Env.hasTrackasiaKey) return null;
    final uri = Uri.https(Env.trackasiaApiHost, _detailsPath, <String, String>{
      'place_id': placeId,
      'language': 'vi',
      'key': Env.trackasiaApiKey,
    });
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
        placeId: result['place_id'] as String? ?? placeId,
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

  /// Reverse-geocode a coordinate into the best Vietnamese formatted
  /// address. Returns `null` on failure; callers should fall back to
  /// showing the raw lat/lng.
  static Future<String?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    if (!Env.hasTrackasiaKey) return null;
    final uri = Uri.https(Env.trackasiaApiHost, _geocodePath, <String, String>{
      'latlng': '$lat,$lng',
      'language': 'vi',
      'new_admin': 'true',
      'size': '1',
      'key': Env.trackasiaApiKey,
    });
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
