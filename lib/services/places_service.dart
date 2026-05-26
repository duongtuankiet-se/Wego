import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/env.dart';
import '../core/theme/app_colors.dart';

/// Đà Nẵng city center — used as the location bias for autocomplete so
/// nearby POIs surface first. 30km radius covers everything from the
/// airport to Hội An and Bà Nà.
const _kDanangBiasLat = 16.0544;
const _kDanangBiasLng = 108.2022;
const _kDanangBiasRadiusMeters = 30000;

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

  /// Tint colour matched to [displayIcon] — drives both the icon and
  /// the surrounding tinted tile.
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
    // Legacy Places Autocomplete supports a circular location bias via
    // `location` + `radius` (returns `distance_meters` per result) and
    // a `types[]` array on every prediction we can map to a Phosphor
    // icon. Skipping `types=` filter on the request keeps both
    // establishments (sân bay, nhà hàng) and addresses in the result
    // list.
    final uri = Uri.parse(_autocompleteUrl).replace(
      queryParameters: <String, String>{
        'input': input,
        'language': 'vi',
        'components': 'country:vn',
        'location': '$_kDanangBiasLat,$_kDanangBiasLng',
        'radius': '$_kDanangBiasRadiusMeters',
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
