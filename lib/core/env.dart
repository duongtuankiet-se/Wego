import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised env getters. All reads go through dotenv so missing values
/// surface in one place at boot.
class Env {
  Env._();

  static String get mongoUri => dotenv.maybeGet('MONGODB_URI') ?? '';
  static String get mongoDb => dotenv.maybeGet('MONGODB_DB') ?? 'wego';
  static String get appEnv => dotenv.maybeGet('APP_ENV') ?? 'dev';

  /// Google Maps key for Directions API + Places API (HTTP calls from Dart).
  /// The native Maps SDK on Android reads the same value from
  /// android/local.properties via manifestPlaceholders.
  static String get googleMapsApiKey =>
      dotenv.maybeGet('GOOGLE_MAPS_API_KEY') ?? '';

  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;
}
