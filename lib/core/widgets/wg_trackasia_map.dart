import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../env.dart';

/// Thin wrapper around [MapLibreMap] that wires the TrackAsia v2 vector
/// style + sensible defaults so each screen doesn't repeat the same
/// boilerplate. Markers, polylines, and other annotations are still
/// added imperatively via the [MapLibreMapController] handed back through
/// [onMapCreated].
class WgTrackAsiaMap extends StatelessWidget {
  const WgTrackAsiaMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14,
    this.minZoom = 5,
    this.maxZoom = 18,
    this.onMapCreated,
    this.onStyleLoadedCallback,
    this.onMapClick,
    this.onCameraIdle,
    this.onCameraTrackingDismissed,
    this.trackCameraPosition = false,
    this.myLocationEnabled = false,
    this.myLocationTrackingMode = MyLocationTrackingMode.none,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.tiltGesturesEnabled = false,
    this.zoomGesturesEnabled = true,
    this.compassEnabled = false,
    this.attributionButtonPosition = AttributionButtonPosition.bottomLeft,
    this.dragEnabled = true,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final MapCreatedCallback? onMapCreated;
  final OnStyleLoadedCallback? onStyleLoadedCallback;
  final OnMapClickCallback? onMapClick;
  final OnCameraIdleCallback? onCameraIdle;
  final OnCameraTrackingDismissedCallback? onCameraTrackingDismissed;
  final bool trackCameraPosition;
  final bool myLocationEnabled;
  final MyLocationTrackingMode myLocationTrackingMode;
  final bool rotateGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool zoomGesturesEnabled;
  final bool compassEnabled;
  final AttributionButtonPosition attributionButtonPosition;
  final bool dragEnabled;

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: Env.trackasiaStyleUrlWithKey,
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: initialZoom,
      ),
      minMaxZoomPreference: MinMaxZoomPreference(minZoom, maxZoom),
      onMapCreated: onMapCreated,
      onStyleLoadedCallback: onStyleLoadedCallback,
      onMapClick: onMapClick,
      onCameraIdle: onCameraIdle,
      onCameraTrackingDismissed: onCameraTrackingDismissed,
      trackCameraPosition: trackCameraPosition,
      myLocationEnabled: myLocationEnabled,
      myLocationTrackingMode: myLocationTrackingMode,
      rotateGesturesEnabled: rotateGesturesEnabled,
      scrollGesturesEnabled: scrollGesturesEnabled,
      tiltGesturesEnabled: tiltGesturesEnabled,
      zoomGesturesEnabled: zoomGesturesEnabled,
      compassEnabled: compassEnabled,
      attributionButtonPosition: attributionButtonPosition,
      dragEnabled: dragEnabled,
    );
  }
}
