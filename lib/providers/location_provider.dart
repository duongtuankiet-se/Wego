import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_provider.g.dart';

/// Fallback: Đà Nẵng city center.
const LatLng kDanangFallback = LatLng(16.0544, 108.2022);

@Riverpod(keepAlive: true)
class CurrentLocation extends _$CurrentLocation {
  @override
  Future<LatLng> build() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return kDanangFallback;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return kDanangFallback;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return kDanangFallback;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await build());
  }
}
