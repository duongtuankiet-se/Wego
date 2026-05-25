import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Static (non-interactive) FlutterMap that fits pickup + dropoff in view
/// and renders a straight polyline between them. Used by RideOptions and
/// TripSummary.
class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.height = 200,
    this.borderRadius,
    this.showAttribution = true,
  });

  final LatLng pickup;
  final LatLng dropoff;
  final double height;
  final BorderRadius? borderRadius;
  final bool showAttribution;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints([pickup, dropoff]),
              padding: const EdgeInsets.all(40),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'vn.exe.wego',
              maxZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [pickup, dropoff],
                  color: AppColors.primary500,
                  strokeWidth: 4.5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: pickup,
                  width: 22,
                  height: 22,
                  child: const _OriginDot(),
                ),
                Marker(
                  point: dropoff,
                  width: 22,
                  height: 22,
                  child: const _DestinationDot(),
                ),
              ],
            ),
            if (showAttribution)
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    textStyle: AppTypography.micro.copyWith(
                      color: AppColors.ink700,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OriginDot extends StatelessWidget {
  const _OriginDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

class _DestinationDot extends StatelessWidget {
  const _DestinationDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}
