import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// Static (non-interactive) Google Map preview that fits pickup + dropoff
/// in view and draws a polyline between them. Used by RideOptions and
/// TripSummary. Defaults to a straight-line polyline; callers can pass a
/// pre-computed Directions route via [routePoints] for the real curve.
class RoutePreviewMap extends StatelessWidget {
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

  /// Padding the static fit applies so markers don't sit on the edge.
  double _padFor(double h) => h < 130 ? 30 : 50;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final poly = routePoints ?? <LatLng>[pickup, dropoff];
    final sw = LatLng(
      pickup.latitude < dropoff.latitude
          ? pickup.latitude
          : dropoff.latitude,
      pickup.longitude < dropoff.longitude
          ? pickup.longitude
          : dropoff.longitude,
    );
    final ne = LatLng(
      pickup.latitude > dropoff.latitude
          ? pickup.latitude
          : dropoff.latitude,
      pickup.longitude > dropoff.longitude
          ? pickup.longitude
          : dropoff.longitude,
    );
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (pickup.latitude + dropoff.latitude) / 2,
              (pickup.longitude + dropoff.longitude) / 2,
            ),
            zoom: 13,
          ),
          onMapCreated: (controller) {
            // Defer fitting bounds until the platform view is ready,
            // otherwise the call is silently dropped.
            Future.delayed(const Duration(milliseconds: 300), () {
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, _padFor(height)),
              );
            });
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          tiltGesturesEnabled: false,
          liteModeEnabled: false,
          markers: <Marker>{
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickup,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
            Marker(
              markerId: const MarkerId('dropoff'),
              position: dropoff,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          },
          polylines: <Polyline>{
            Polyline(
              polylineId: const PolylineId('route'),
              points: poly,
              color: AppColors.primary500,
              width: 5,
            ),
          },
        ),
      ),
    );
  }
}
