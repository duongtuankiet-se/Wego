import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised env getters. All reads go through dotenv so missing values
/// surface in one place at boot.
class Env {
  Env._();

  static String get mongoUri => dotenv.maybeGet('MONGODB_URI') ?? '';
  static String get mongoDb => dotenv.maybeGet('MONGODB_DB') ?? 'wego';
  static String get appEnv => dotenv.maybeGet('APP_ENV') ?? 'dev';

  /// Phase 5G: Google Maps removed (billing REQUEST_DENIED). Key still
  /// readable so a future rollback only needs to flip pubspec back +
  /// re-enable the .env line.
  static String get googleMapsApiKey =>
      dotenv.maybeGet('GOOGLE_MAPS_API_KEY') ?? '';
  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;

  // ── TrackAsia (Phase 5G) ─────────────────────────────────────────
  // 1M req/day free, no credit card. Vietnam-localized data + new
  // admin boundaries (1/7/2025 reform).

  static String get trackasiaApiKey =>
      dotenv.maybeGet('TRACKASIA_API_KEY') ?? '';
  static bool get hasTrackasiaKey => trackasiaApiKey.isNotEmpty;

  /// Default vector style (MapLibre style spec v8). The MapLibreMap
  /// widget needs the URL with the API key appended.
  static String get trackasiaStyleUrl =>
      dotenv.maybeGet('TRACKASIA_STYLE_URL') ??
      'https://maps.track-asia.com/styles/v2/streets.json';

  /// Style URL ready to hand to MapLibreMap (key appended).
  static String get trackasiaStyleUrlWithKey {
    final base = trackasiaStyleUrl;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}key=$trackasiaApiKey';
  }

  /// REST API host for autocomplete / directions / geocoding.
  static const String trackasiaApiHost = 'maps.track-asia.com';

  /// Đà Nẵng center — bias for autocomplete + initial map camera.
  static const double danangLat = 16.0544;
  static const double danangLng = 108.2022;
}
