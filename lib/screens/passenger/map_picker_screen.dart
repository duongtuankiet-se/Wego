import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_trackasia_map.dart';
import '../../models/place.dart';
import '../../providers/location_provider.dart';
import '../../services/places_service.dart';

/// What kind of location the user is picking. Only affects copy on the
/// screen — the returned [Place] is identical either way; the caller
/// decides whether to route it into `selectedDestinationProvider` or
/// `customPickupProvider`.
enum MapPickerMode { dropoff, pickup }

/// Full-screen map picker. The center pin is a fixed overlay widget
/// (NOT a map Marker), so panning moves the map under a stationary pin.
/// When the camera idles, we debounce 500ms then reverse-geocode the
/// pin's lat/lng to populate the bottom address card.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key, this.mode = MapPickerMode.dropoff});

  final MapPickerMode mode;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen>
    with TickerProviderStateMixin {
  MapLibreMapController? _mapController;
  late LatLng _centerPosition;
  String? _currentAddress;
  bool _isGeocoding = false;
  bool _hasError = false;
  Timer? _debounceTimer;
  bool _moving = false;

  late final AnimationController _pinAnimController;
  late final Animation<double> _pinBounce;

  @override
  void initState() {
    super.initState();
    _pinAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pinBounce = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _pinAnimController, curve: Curves.easeOutCubic),
    );

    final currentLoc = ref.read(currentLocationProvider).valueOrNull;
    _centerPosition = currentLoc ?? kDanangFallback;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reverseGeocode(_centerPosition);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pinAnimController.dispose();
    // MapLibreMapController is owned by MapLibreMap widget.
    super.dispose();
  }

  /// Sample camera position on every frame while the user is dragging,
  /// then debounce reverse-geocode on idle. MapLibre doesn't expose a
  /// `onCameraMoveStarted` like GoogleMap; we infer it from successive
  /// frames where the controller's camera target moved between idles.
  Future<void> _pollCenter() async {
    if (!_moving) return;
    final ctrl = _mapController;
    if (ctrl == null) return;
    final pos = ctrl.cameraPosition?.target;
    if (pos != null) _centerPosition = pos;
    Future<void>.delayed(const Duration(milliseconds: 80), _pollCenter);
  }

  void _onCameraIdle() {
    _moving = false;
    final ctrl = _mapController;
    if (ctrl != null) {
      final pos = ctrl.cameraPosition?.target;
      if (pos != null) _centerPosition = pos;
    }
    _pinAnimController.reverse();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _reverseGeocode(_centerPosition);
    });
  }

  void _onCameraTrackingDismissed() {
    // Fires when the user grabs the map — kick off the pin lift + the
    // light haptic that signals "dragging started".
    if (!_moving) {
      HapticFeedback.selectionClick();
      _moving = true;
      _pinAnimController.forward();
      _pollCenter();
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    setState(() {
      _isGeocoding = true;
      _hasError = false;
    });

    final address = await PlacesService.reverseGeocode(
      lat: position.latitude,
      lng: position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _isGeocoding = false;
      if (address == null) {
        _hasError = true;
        _currentAddress =
            'Vị trí: ${position.latitude.toStringAsFixed(4)}, '
            '${position.longitude.toStringAsFixed(4)}';
      } else {
        _currentAddress = address;
      }
    });
  }

  Future<void> _onRecenter() async {
    HapticFeedback.lightImpact();
    final currentLoc = ref.read(currentLocationProvider).valueOrNull;
    if (currentLoc == null || _mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(currentLoc, 16),
    );
  }

  void _onConfirm() {
    if (_currentAddress == null || _isGeocoding) return;

    HapticFeedback.mediumImpact();

    final picked = Place(
      id: 'picked_${DateTime.now().millisecondsSinceEpoch}',
      name: _extractShortName(_currentAddress!),
      address: _currentAddress!,
      lat: _centerPosition.latitude,
      lng: _centerPosition.longitude,
      icon: 'mapPin',
    );

    context.pop(picked);
  }

  String _extractShortName(String fullAddress) {
    final parts = fullAddress.split(',');
    return parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WgTrackAsiaMap(
            initialCenter: _centerPosition,
            initialZoom: 16,
            onMapCreated: (c) => _mapController = c,
            onCameraIdle: _onCameraIdle,
            onCameraTrackingDismissed: _onCameraTrackingDismissed,
            trackCameraPosition: true,
            myLocationEnabled: true,
          ),

          // Fixed center pin overlay
          Center(
            child: AnimatedBuilder(
              animation: _pinBounce,
              builder: (context, _) {
                return Transform.translate(
                  // -22 keeps the pin tip on the map's exact center.
                  offset: Offset(0, _pinBounce.value - 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary500.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          PhosphorIconsFill.mapPin,
                          color: AppColors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 12,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.ink900.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _TopHeader(mode: widget.mode),
          ),

          Positioned(
            right: 16,
            bottom: 220,
            child: _RecenterFab(onTap: _onRecenter),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomAddressCard(
              mode: widget.mode,
              isGeocoding: _isGeocoding,
              hasError: _hasError,
              address: _currentAddress,
              onConfirm: _onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.mode});
  final MapPickerMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.ink50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.arrowLeft,
                  size: 20,
                  color: AppColors.ink900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mode == MapPickerMode.pickup ? 'Chọn điểm đón' : 'Chọn điểm đến',
              style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecenterFab extends StatelessWidget {
  const _RecenterFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.sm,
      ),
      child: ClipOval(
        child: Material(
          color: AppColors.white,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                PhosphorIconsFill.crosshair,
                color: AppColors.primary500,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomAddressCard extends StatelessWidget {
  const _BottomAddressCard({
    required this.mode,
    required this.isGeocoding,
    required this.hasError,
    required this.address,
    required this.onConfirm,
  });

  final MapPickerMode mode;
  final bool isGeocoding;
  final bool hasError;
  final String? address;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  PhosphorIconsFill.mapPin,
                  color: AppColors.primary500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mode == MapPickerMode.pickup
                          ? 'Điểm đón đã chọn'
                          : 'Điểm đến đã chọn',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: isGeocoding
                          ? const _LoadingAddress(key: ValueKey('loading'))
                          : Text(
                              address ?? 'Di chuyển bản đồ để chọn điểm',
                              key: ValueKey(address),
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: hasError
                                    ? AppColors.ink700
                                    : AppColors.ink900,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WgButton.primary(
            label: mode == MapPickerMode.pickup
                ? 'Xác nhận điểm đón'
                : 'Xác nhận điểm đến',
            onPressed: isGeocoding ? null : onConfirm,
            isFullWidth: true,
            size: WgButtonSize.lg,
            trailingIcon: PhosphorIconsRegular.arrowRight,
          ),
        ],
      ),
    );
  }
}

class _LoadingAddress extends StatelessWidget {
  const _LoadingAddress({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary500),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Đang xác định địa chỉ...',
          style: AppTypography.body.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}
