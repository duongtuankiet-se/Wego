import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/wg_trackasia_map.dart';

/// Static (non-interactive) TrackAsia map preview that draws a polyline
/// between pickup and dropoff and frames both. Used by Ride Options +
/// Trip Summary. Defaults to a straight line; callers can pass a
/// pre-computed Directions route via [routePoints].
class RoutePreviewMap extends StatefulWidget {
  const RoutePreviewMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.routePoints,
    this.height = 200,
    this.borderRadius,
  });

  final LatLng pickup;
  final LatLng dropoff;
  final List<LatLng>? routePoints;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<RoutePreviewMap> createState() => _RoutePreviewMapState();
}

class _RoutePreviewMapState extends State<RoutePreviewMap> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  /// Padding the static fit applies so markers don't sit on the edge.
  double _padFor(double h) => h < 130 ? 30 : 50;

  @override
  void didUpdateWidget(RoutePreviewMap old) {
    super.didUpdateWidget(old);
    final pointsChanged = old.routePoints != widget.routePoints;
    final endpointsChanged =
        old.pickup != widget.pickup || old.dropoff != widget.dropoff;
    if (_styleLoaded && (pointsChanged || endpointsChanged)) {
      _syncAnnotations();
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    await _syncAnnotations();
    _fitBounds();
  }

  Future<void> _syncAnnotations() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    // Wipe + re-add. Simpler than diffing; the preview re-renders
    // infrequently (when Directions arrives or the destination changes).
    await ctrl.clearLines();
    await ctrl.clearCircles();

    final poly = widget.routePoints ?? [widget.pickup, widget.dropoff];
    await ctrl.addLine(
      LineOptions(
        geometry: poly,
        lineColor:
            '#${AppColors.primary500.toARGB32().toRadixString(16).substring(2)}',
        lineWidth: 5.0,
        lineOpacity: 1.0,
        lineJoin: 'round',
      ),
    );

    await ctrl.addCircle(
      CircleOptions(
        geometry: widget.pickup,
        circleRadius: 7,
        circleColor: '#10B981', // success green
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );
    await ctrl.addCircle(
      CircleOptions(
        geometry: widget.dropoff,
        circleRadius: 7,
        circleColor: '#EF4444', // danger red
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );
  }

  void _fitBounds() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final bounds = _boundsOf([widget.pickup, widget.dropoff]);
    final pad = _padFor(widget.height);
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: pad,
          right: pad,
          top: pad,
          bottom: pad,
        ),
      );
    });
  }

  LatLngBounds _boundsOf(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    final centerLat = (widget.pickup.latitude + widget.dropoff.latitude) / 2;
    final centerLng = (widget.pickup.longitude + widget.dropoff.longitude) / 2;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: widget.height,
        child: WgTrackAsiaMap(
          initialCenter: LatLng(centerLat, centerLng),
          initialZoom: 13,
          onMapCreated: (c) => _controller = c,
          onStyleLoadedCallback: _onStyleLoaded,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: false,
          dragEnabled: false,
          // Note: ignore_unused_variable for line — kept for future
          // updates that diff annotations instead of clearing.
        ),
      ),
    );
  }
}
